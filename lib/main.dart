import 'package:flutter/material.dart';
import 'printer_service.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // نخلي التطبيق RTL بالكامل
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      routes: {
        '/': (_) => const PrinterConnectPage(),
        '/orders': (_) => const OrdersHomePage(),
      },
      initialRoute: '/',
    );
  }
}

/// =======================
/// Screen 1: Connect Printer
/// =======================
class PrinterConnectPage extends StatefulWidget {
  const PrinterConnectPage({super.key});

  @override
  State<PrinterConnectPage> createState() => _PrinterConnectPageState();
}

class _PrinterConnectPageState extends State<PrinterConnectPage> {
  final _svc = PrinterService.instance;
  bool _loading = false;
  List<BluetoothInfo> _paired = [];

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _svc.getPairedDevices();
      setState(() {
        _paired = list;
        if (list.isNotEmpty && _svc.selectedMac == null) {
          _svc.selectedMac = list.first.macAdress;
          _svc.selectedName = list.first.name;
        }
      });

      if (list.isEmpty) {
        _snack("لا توجد طابعات مقترنة. اعمل Pair من الإعدادات.");
      }
    } catch (e) {
      _snack("خطأ: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    try {
      final ok = await _svc.connectSelected();
      _snack(ok ? "تم الاتصال ✅" : "فشل الاتصال ❌");
    } catch (e) {
      _snack("خطأ: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _svc.selectedMac;

    return Scaffold(
      appBar: AppBar(
        title: const Text("اتصال الطابعة"),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selected,
              items: _paired
                  .map(
                    (d) => DropdownMenuItem(
                      value: d.macAdress,
                      child: Text("${d.name}  (${d.macAdress})"),
                    ),
                  )
                  .toList(),
              onChanged: _loading
                  ? null
                  : (v) {
                      if (v == null) return;
                      final device = _paired.firstWhere(
                        (x) => x.macAdress == v,
                      );
                      setState(() {
                        _svc.selectedMac = device.macAdress;
                        _svc.selectedName = device.name;
                      });
                    },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "اختر طابعة (Paired)",
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _connect,
                    icon: const Icon(Icons.bluetooth_connected),
                    label: Text(_loading ? "جاري..." : "اتصال"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () async {
                            final connected = await _svc.isConnected();
                            _snack(connected ? "متصل ✅" : "غير متصل ❌");
                          },
                    icon: const Icon(Icons.info_outline),
                    label: const Text("الحالة"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.pushReplacementNamed(context, '/orders'),
                child: const Text("الذهاب إلى شاشة الطلبات"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// Screen 2: Orders Home
/// =======================
class OrdersHomePage extends StatefulWidget {
  const OrdersHomePage({super.key});

  @override
  State<OrdersHomePage> createState() => _OrdersHomePageState();
}

class _OrdersHomePageState extends State<OrdersHomePage> {
  final _svc = PrinterService.instance;
  bool _printing = false;

  // بيانات تجريبية
  final List<CustomerOrder> _orders = [
    CustomerOrder(
      id: "1001",
      customerName: "أحمد",
      tableOrAddress: "طاولة 3",
      createdAt: DateTime.now(),
      items: const [
        OrderItem(name: "برجر", qty: 2, price: 12.5),
        OrderItem(name: "كولا", qty: 1, price: 3.0),
      ],
    ),
    CustomerOrder(
      id: "1002",
      customerName: "سارة",
      tableOrAddress: "توصيل - وسط المدينة",
      createdAt: DateTime.now().subtract(const Duration(minutes: 7)),
      items: const [
        OrderItem(name: "بيتزا", qty: 1, price: 25.0),
        OrderItem(name: "مياه", qty: 2, price: 2.0),
      ],
    ),
  ];

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _printOrder(CustomerOrder order) async {
    setState(() => _printing = true);
    try {
      final connected = await _svc.isConnected();
      if (!connected) {
        _snack("الطابعة غير متصلة. ارجع لصفحة الاتصال.");
        return;
      }

      final ok = await _svc.printOrderArabic(order);
      _snack(ok ? "تمت طباعة الطلب #${order.id} ✅" : "فشل الطباعة ❌");
    } catch (e) {
      _snack("خطأ: $e");
    } finally {
      setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerName = _svc.selectedName ?? "غير محددة";

    return Scaffold(
      appBar: AppBar(
        title: const Text("طلبات المطعم"),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            icon: const Icon(Icons.bluetooth),
            tooltip: "العودة لصفحة الاتصال",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text("الطابعة: $printerName"),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final o = _orders[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "طلب رقم #${o.id}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text("الزبون: ${o.customerName}"),
                          Text("المكان: ${o.tableOrAddress}"),
                          const SizedBox(height: 8),
                          ...o.items.map(
                            (it) => Text(
                              "${it.qty} × ${it.name}  =  ${it.total.toStringAsFixed(2)}",
                            ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "الإجمالي: ${o.total.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _printing
                                    ? null
                                    : () => _printOrder(o),
                                icon: _printing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.print),
                                label: const Text("طباعة"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
