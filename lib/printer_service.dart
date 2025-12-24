import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

/// =======================
/// Models (Restaurant)
/// =======================
class OrderItem {
  final String name;
  final int qty;
  final double price;

  const OrderItem({required this.name, required this.qty, required this.price});

  double get total => qty * price;
}

class CustomerOrder {
  final String id;
  final String customerName;
  final String tableOrAddress;
  final DateTime createdAt;
  final List<OrderItem> items;

  const CustomerOrder({
    required this.id,
    required this.customerName,
    required this.tableOrAddress,
    required this.createdAt,
    required this.items,
  });

  double get total => items.fold(0, (sum, i) => sum + i.total);
}

/// =======================
/// Printer Service
/// =======================
class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  String? selectedMac;
  String? selectedName;

  // لو طابعتك 80mm غيّرها:
  PaperSize paperSize = PaperSize.mm58;

  int get paperWidthPx => paperSize == PaperSize.mm58 ? 384 : 576;

  Future<bool> ensurePermissions() async {
    final connect = await Permission.bluetoothConnect.request();
    final scan = await Permission.bluetoothScan.request();
    await Permission.locationWhenInUse.request(); // Android <= 11

    final ok = connect.isGranted && scan.isGranted;
    if (!ok && (connect.isPermanentlyDenied || scan.isPermanentlyDenied)) {
      await openAppSettings();
    }
    return ok;
  }

  Future<List<BluetoothInfo>> getPairedDevices() async {
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) throw Exception("Bluetooth is OFF");

    final ok = await ensurePermissions();
    if (!ok) throw Exception("Bluetooth permission denied");

    return await PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> connectSelected() async {
    final mac = selectedMac;
    if (mac == null) return false;
    return await PrintBluetoothThermal.connect(macPrinterAddress: mac);
  }

  Future<bool> isConnected() async {
    return await PrintBluetoothThermal.connectionStatus;
  }

  /// ✅ تحويل نص عربي RTL لصورة (PNG -> Image package)
  Future<img.Image> rtlTextToImage(
    String text, {
    required int widthPx,
    double fontSize = 26,
    double padding = 16,
    String? fontFamily, // لو عندك خط عربي (Tajawal) حطه هنا
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: Colors.black,
          fontFamily: fontFamily,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
    );

    tp.layout(maxWidth: widthPx.toDouble() - (padding * 2));

    final heightPx = (tp.height + padding * 2).ceil().clamp(1, 20000);

    // خلفية بيضاء
    final bg = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble()),
      bg,
    );

    // محاذاة يمين
    final dx = widthPx - padding - tp.width;
    final dy = padding;
    tp.paint(canvas, ui.Offset(dx, dy));

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(widthPx, heightPx);

    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final decoded = img.decodePng(pngBytes);
    if (decoded == null) throw Exception("Failed to decode PNG");
    return decoded;
  }

  /// ✅ يبني إيصال عربي RTL كصورة ثم يحولها لبايتات ESC/POS
  Future<List<int>> buildOrderReceiptArabic(CustomerOrder order) async {
    final profile = await CapabilityProfile.load();
    final gen = Generator(paperSize, profile);

    // نص عربي RTL (اطبع كصورة)
    final lines = <String>[];
    lines.add("مطعم");
    lines.add("طلب رقم: ${order.id}");
    lines.add("____________________________");
    lines.add("الزبون: ${order.customerName}");
    lines.add("المكان: ${order.tableOrAddress}");
    lines.add("الوقت: ${order.createdAt}");
    lines.add("____________________________");
    lines.add("الأصناف:");

    for (final it in order.items) {
      // ترتيب بسيط: (اسم) (×الكمية) (الإجمالي)
      lines.add("${it.name}   ×${it.qty}   ${it.total.toStringAsFixed(2)}");
    }

    lines.add("____________________________");
    lines.add("الإجمالي: ${order.total.toStringAsFixed(2)}");
    lines.add("");
    lines.add("شكرًا لكم 🌿");

    final receiptText = lines.join("\n");

    final receiptImage = await rtlTextToImage(
      receiptText,
      widthPx: paperWidthPx,
      fontSize: 26,
      padding: 18,
      // fontFamily: "Tajawal", // لو اضفت خط
    );

    List<int> bytes = [];
    bytes += gen.imageRaster(receiptImage, align: PosAlign.center);
    bytes += gen.feed(2);
    bytes += gen.cut();
    return bytes;
  }

  Future<bool> printOrderArabic(CustomerOrder order) async {
    final okPerm = await ensurePermissions();
    if (!okPerm) return false;

    final connected = await isConnected();
    if (!connected) {
      final ok = await connectSelected();
      if (!ok) return false;
    }

    final bytes = await buildOrderReceiptArabic(order);
    return await PrintBluetoothThermal.writeBytes(bytes);
  }
}
