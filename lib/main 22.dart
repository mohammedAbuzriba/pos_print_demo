// import 'package:flutter/material.dart';
// import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import 'package:permission_handler/permission_handler.dart';

// void main() => runApp(const MyApp());

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: BluetoothPrintPage(),
//     );
//   }
// }

// class BluetoothPrintPage extends StatefulWidget {
//   const BluetoothPrintPage({super.key});
//   @override
//   State<BluetoothPrintPage> createState() => _BluetoothPrintPageState();
// }

// class _BluetoothPrintPageState extends State<BluetoothPrintPage> {
//   final _controller = TextEditingController(
//     text: "TEST PRINT\nTotal: 25 LYD\n",
//   );

//   List<BluetoothInfo> _paired = [];
//   String? _selectedMac;
//   bool _loading = false;

//   Future<bool> _ensureBtPermissions() async {
//     // Android 12+ (Nearby devices)
//     final connect = await Permission.bluetoothConnect.request();
//     final scan = await Permission.bluetoothScan.request();

//     // Android 11- (بعض الأجهزة تحتاج Location عند التعامل مع Bluetooth)
//     final loc = await Permission.locationWhenInUse.request();

//     final ok = connect.isGranted && scan.isGranted;

//     if (!ok) {
//       // لو المستخدم رفض نهائيًا
//       if (connect.isPermanentlyDenied || scan.isPermanentlyDenied) {
//         await openAppSettings();
//       }
//     }

//     // loc ما نعتبره شرط أساسي لأن Android 12+ ما يحتاجه غالباً
//     // لكن طلبناه لتحسين التوافق مع Android <= 11
//     return ok;
//   }

//   Future<void> _loadPaired() async {
//     setState(() => _loading = true);
//     try {
//       final bluetoothOn = await PrintBluetoothThermal.bluetoothEnabled;
//       if (!bluetoothOn) {
//         _snack("شغّل البلوتوث أولاً");
//         return;
//       }

//       final permOk = await _ensureBtPermissions();
//       if (!permOk) {
//         _snack("امنح صلاحية Nearby devices للتطبيق");
//         return;
//       }

//       final list = await PrintBluetoothThermal.pairedBluetooths;
//       setState(() {
//         _paired = list;
//         _selectedMac = list.isNotEmpty ? list.first.macAdress : null;
//       });

//       if (list.isEmpty) {
//         _snack("لا توجد طابعات مقترنة. اعمل Pair من إعدادات البلوتوث.");
//       }
//     } catch (e) {
//       _snack("خطأ: $e");
//     } finally {
//       setState(() => _loading = false);
//     }
//   }

//   Future<bool> _connect() async {
//     final mac = _selectedMac;
//     if (mac == null) {
//       _snack("اختر طابعة أولاً");
//       return false;
//     }
//     final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
//     if (!ok) _snack("فشل الاتصال بالطابعة");
//     return ok;
//   }

//   Future<List<int>> _buildTicket(String text) async {
//     final profile = await CapabilityProfile.load();
//     final gen = Generator(
//       PaperSize.mm58,
//       profile,
//     ); // غيّرها mm80 لو طابعتك 80mm

//     List<int> bytes = [];
//     bytes += gen.text(
//       "Bluetooth Receipt",
//       styles: const PosStyles(align: PosAlign.center, bold: true),
//     );
//     bytes += gen.hr();
//     bytes += gen.text(text);
//     bytes += gen.feed(2);
//     bytes += gen.cut();
//     return bytes;
//   }

//   Future<void> _print() async {
//     final text = _controller.text.trim();
//     if (text.isEmpty) return _snack("اكتب نص قبل الطباعة");

//     setState(() => _loading = true);
//     try {
//       final permOk = await _ensureBtPermissions();
//       if (!permOk) {
//         _snack("امنح صلاحية Nearby devices للتطبيق");
//         return;
//       }

//       final connected = await PrintBluetoothThermal.connectionStatus;
//       if (!connected) {
//         final ok = await _connect();
//         if (!ok) return;
//       }

//       final bytes = await _buildTicket("$text\n");
//       final ok = await PrintBluetoothThermal.writeBytes(bytes);

//       _snack(ok ? "تمت الطباعة ✅" : "فشل إرسال بيانات الطباعة");
//     } catch (e) {
//       _snack("خطأ: $e");
//     } finally {
//       setState(() => _loading = false);
//     }
//   }

//   void _snack(String msg) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }

//   @override
//   void initState() {
//     super.initState();
//     _loadPaired();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Bluetooth POS Print"),
//         actions: [
//           IconButton(
//             onPressed: _loading ? null : _loadPaired,
//             icon: const Icon(Icons.refresh),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             TextField(
//               controller: _controller,
//               maxLines: 6,
//               decoration: const InputDecoration(
//                 border: OutlineInputBorder(),
//                 labelText: "النص المراد طباعته",
//               ),
//             ),
//             const SizedBox(height: 12),

//             Row(
//               children: [
//                 Expanded(
//                   child: DropdownButtonFormField<String>(
//                     value: _selectedMac,
//                     items: _paired
//                         .map(
//                           (d) => DropdownMenuItem(
//                             value: d.macAdress,
//                             child: Text("${d.name}  (${d.macAdress})"),
//                           ),
//                         )
//                         .toList(),
//                     onChanged: _loading
//                         ? null
//                         : (v) => setState(() => _selectedMac = v),
//                     decoration: const InputDecoration(
//                       border: OutlineInputBorder(),
//                       labelText: "اختر الطابعة (Paired)",
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 ElevatedButton(
//                   onPressed: _loading ? null : _connect,
//                   child: const Text("Connect"),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 12),
//             SizedBox(
//               width: double.infinity,
//               height: 48,
//               child: ElevatedButton.icon(
//                 onPressed: _loading ? null : _print,
//                 icon: _loading
//                     ? const SizedBox(
//                         width: 18,
//                         height: 18,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : const Icon(Icons.print),
//                 label: Text(_loading ? "جاري..." : "طباعة"),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
