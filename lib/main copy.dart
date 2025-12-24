// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

// void main() => runApp(const MyApp());

// /// =======================
// /// Models (Restaurant)
// /// =======================
// class OrderItem {
//   final String name;
//   final int qty;
//   final double price;

//   const OrderItem({required this.name, required this.qty, required this.price});

//   double get total => qty * price;
// }

// class CustomerOrder {
//   final String id;
//   final String customerName;
//   final String tableOrAddress;
//   final DateTime createdAt;
//   final List<OrderItem> items;

//   const CustomerOrder({
//     required this.id,
//     required this.customerName,
//     required this.tableOrAddress,
//     required this.createdAt,
//     required this.items,
//   });

//   double get total => items.fold(0, (sum, i) => sum + i.total);
// }

// /// =======================
// /// Printer Service (Singleton)
// /// =======================
// class PrinterService {
//   PrinterService._();
//   static final PrinterService instance = PrinterService._();

//   String? selectedMac;
//   String? selectedName;

//   Future<bool> ensurePermissions() async {
//     // Android 12+ (Nearby devices)
//     final connect = await Permission.bluetoothConnect.request();
//     final scan = await Permission.bluetoothScan.request();
//     // Android <= 11 (helpful)
//     await Permission.locationWhenInUse.request();

//     final ok = connect.isGranted && scan.isGranted;
//     if (!ok && (connect.isPermanentlyDenied || scan.isPermanentlyDenied)) {
//       await openAppSettings();
//     }
//     return ok;
//   }

//   Future<List<BluetoothInfo>> getPairedDevices() async {
//     final enabled = await PrintBluetoothThermal.bluetoothEnabled;
//     if (!enabled) throw Exception("Bluetooth is OFF");
//     final ok = await ensurePermissions();
//     if (!ok) throw Exception("Bluetooth permission denied");
//     return await PrintBluetoothThermal.pairedBluetooths;
//   }

//   Future<bool> connectSelected() async {
//     final mac = selectedMac;
//     if (mac == null) return false;
//     return await PrintBluetoothThermal.connect(macPrinterAddress: mac);
//   }

//   Future<bool> isConnected() async {
//     return await PrintBluetoothThermal.connectionStatus;
//   }

//   Future<List<int>> buildOrderReceipt(CustomerOrder order) async {
//     final profile = await CapabilityProfile.load();
//     final gen = Generator(PaperSize.mm58, profile); // غيّرها mm80 عند الحاجة

//     List<int> bytes = [];
//     bytes += gen.text(
//       "RESTAURANT",
//       styles: const PosStyles(align: PosAlign.center, bold: true),
//     );
//     bytes += gen.text(
//       "Order #${order.id}",
//       styles: const PosStyles(align: PosAlign.center),
//     );
//     bytes += gen.hr();

//     bytes += gen.text("Customer: ${order.customerName}");
//     bytes += gen.text("Place: ${order.tableOrAddress}");
//     bytes += gen.text("Time: ${order.createdAt}");
//     bytes += gen.hr();

//     for (final it in order.items) {
//       bytes += gen.row([
//         PosColumn(
//           text: "${it.qty}x",
//           width: 2,
//           styles: const PosStyles(bold: true),
//         ),
//         PosColumn(text: it.name, width: 7),
//         PosColumn(
//           text: it.total.toStringAsFixed(2),
//           width: 3,
//           styles: const PosStyles(align: PosAlign.right),
//         ),
//       ]);
//     }

//     bytes += gen.hr();
//     bytes += gen.row([
//       PosColumn(text: "TOTAL", width: 6, styles: const PosStyles(bold: true)),
//       PosColumn(
//         text: order.total.toStringAsFixed(2),
//         width: 6,
//         styles: const PosStyles(align: PosAlign.right, bold: true),
//       ),
//     ]);

//     bytes += gen.feed(2);
//     bytes += gen.cut();
//     return bytes;
//   }

//   Future<bool> printOrder(CustomerOrder order) async {
//     final okPerm = await ensurePermissions();
//     if (!okPerm) return false;

//     final connected = await isConnected();
//     if (!connected) {
//       final ok = await connectSelected();
//       if (!ok) return false;
//     }

//     final bytes = await buildOrderReceipt(order);
//     return await PrintBluetoothThermal.writeBytes(bytes);
//   }
// }

// /// =======================
// /// App & Routes
// /// =======================
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       routes: {
//         '/': (_) => const PrinterConnectPage(),
//         '/orders': (_) => const OrdersHomePage(),
//       },
//       initialRoute: '/',
//     );
//   }
// }

// /// =======================
// /// Screen 1: Connect Printer
// /// =======================
// class PrinterConnectPage extends StatefulWidget {
//   const PrinterConnectPage({super.key});

//   @override
//   State<PrinterConnectPage> createState() => _PrinterConnectPageState();
// }

// class _PrinterConnectPageState extends State<PrinterConnectPage> {
//   final _svc = PrinterService.instance;
//   bool _loading = false;
//   List<BluetoothInfo> _paired = [];

//   Future<void> _load() async {
//     setState(() => _loading = true);
//     try {
//       final list = await _svc.getPairedDevices();
//       setState(() {
//         _paired = list;
//         if (list.isNotEmpty && _svc.selectedMac == null) {
//           _svc.selectedMac = list.first.macAdress;
//           _svc.selectedName = list.first.name;
//         }
//       });

//       if (list.isEmpty)
//         _snack("لا توجد طابعات مقترنة. اعمل Pair من الإعدادات.");
//     } catch (e) {
//       _snack("خطأ: $e");
//     } finally {
//       setState(() => _loading = false);
//     }
//   }

//   Future<void> _connect() async {
//     setState(() => _loading = true);
//     try {
//       final ok = await _svc.connectSelected();
//       _snack(ok ? "تم الاتصال ✅" : "فشل الاتصال ❌");
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
//     _load();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selected = _svc.selectedMac;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("اتصال الطابعة"),
//         actions: [
//           IconButton(
//             onPressed: _loading ? null : _load,
//             icon: const Icon(Icons.refresh),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             DropdownButtonFormField<String>(
//               value: selected,
//               items: _paired
//                   .map(
//                     (d) => DropdownMenuItem(
//                       value: d.macAdress,
//                       child: Text("${d.name}  (${d.macAdress})"),
//                     ),
//                   )
//                   .toList(),
//               onChanged: _loading
//                   ? null
//                   : (v) {
//                       final device = _paired.firstWhere(
//                         (x) => x.macAdress == v,
//                       );
//                       setState(() {
//                         _svc.selectedMac = device.macAdress;
//                         _svc.selectedName = device.name;
//                       });
//                     },
//               decoration: const InputDecoration(
//                 border: OutlineInputBorder(),
//                 labelText: "اختر طابعة (Paired)",
//               ),
//             ),
//             const SizedBox(height: 12),

//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: _loading ? null : _connect,
//                     icon: const Icon(Icons.bluetooth_connected),
//                     label: Text(_loading ? "جاري..." : "Connect"),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: OutlinedButton.icon(
//                     onPressed: _loading
//                         ? null
//                         : () async {
//                             final connected = await _svc.isConnected();
//                             _snack(
//                               connected ? "Connected ✅" : "Not connected ❌",
//                             );
//                           },
//                     icon: const Icon(Icons.info_outline),
//                     label: const Text("Status"),
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 16),
//             SizedBox(
//               width: double.infinity,
//               height: 48,
//               child: ElevatedButton(
//                 onPressed: _loading
//                     ? null
//                     : () async {
//                         // نسمح بالدخول حتى لو مو متصل، بس الأفضل توصل قبل
//                         Navigator.pushReplacementNamed(context, '/orders');
//                       },
//                 child: const Text("الذهاب إلى شاشة الطلبات"),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// =======================
// /// Screen 2: Orders Home
// /// =======================
// class OrdersHomePage extends StatefulWidget {
//   const OrdersHomePage({super.key});

//   @override
//   State<OrdersHomePage> createState() => _OrdersHomePageState();
// }

// class _OrdersHomePageState extends State<OrdersHomePage> {
//   final _svc = PrinterService.instance;
//   bool _printing = false;

//   // بيانات تجريبية (بدّلها لاحقًا ببيانات API)
//   final List<CustomerOrder> _orders = [
//     CustomerOrder(
//       id: "1001",
//       customerName: "Ahmed",
//       tableOrAddress: "Table 3",
//       createdAt: DateTime.now(),
//       items: const [
//         OrderItem(name: "Burger", qty: 2, price: 12.5),
//         OrderItem(name: "Cola", qty: 1, price: 3.0),
//       ],
//     ),
//     CustomerOrder(
//       id: "1002",
//       customerName: "Sara",
//       tableOrAddress: "Delivery - Downtown",
//       createdAt: DateTime.now().subtract(const Duration(minutes: 7)),
//       items: const [
//         OrderItem(name: "Pizza", qty: 1, price: 25.0),
//         OrderItem(name: "Water", qty: 2, price: 2.0),
//       ],
//     ),
//   ];

//   void _snack(String msg) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }

//   Future<void> _printOrder(CustomerOrder order) async {
//     setState(() => _printing = true);
//     try {
//       final connected = await _svc.isConnected();
//       if (!connected) {
//         _snack("الطابعة غير متصلة. ارجع لصفحة الاتصال.");
//         return;
//       }

//       final ok = await _svc.printOrder(order);
//       _snack(ok ? "تمت طباعة الطلب #${order.id} ✅" : "فشل الطباعة ❌");
//     } catch (e) {
//       _snack("خطأ: $e");
//     } finally {
//       setState(() => _printing = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final printerName = _svc.selectedName ?? "غير محددة";

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("طلبات المطعم"),
//         actions: [
//           IconButton(
//             onPressed: () => Navigator.pushReplacementNamed(context, '/'),
//             icon: const Icon(Icons.bluetooth),
//             tooltip: "العودة لصفحة الاتصال",
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.black12),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text("Printer: $printerName"),
//             ),
//             const SizedBox(height: 12),

//             Expanded(
//               child: ListView.separated(
//                 itemCount: _orders.length,
//                 separatorBuilder: (_, __) => const SizedBox(height: 10),
//                 itemBuilder: (context, index) {
//                   final o = _orders[index];
//                   return Card(
//                     child: Padding(
//                       padding: const EdgeInsets.all(12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             "Order #${o.id}",
//                             style: const TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 6),
//                           Text("Customer: ${o.customerName}"),
//                           Text("Place: ${o.tableOrAddress}"),
//                           const SizedBox(height: 8),
//                           ...o.items.map(
//                             (it) => Text(
//                               "${it.qty}x ${it.name}  =  ${it.total.toStringAsFixed(2)}",
//                             ),
//                           ),
//                           const Divider(),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 "TOTAL: ${o.total.toStringAsFixed(2)}",
//                                 style: const TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               ElevatedButton.icon(
//                                 onPressed: _printing
//                                     ? null
//                                     : () => _printOrder(o),
//                                 icon: _printing
//                                     ? const SizedBox(
//                                         width: 16,
//                                         height: 16,
//                                         child: CircularProgressIndicator(
//                                           strokeWidth: 2,
//                                         ),
//                                       )
//                                     : const Icon(Icons.print),
//                                 label: const Text("طباعة"),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
