import 'package:flutter/material.dart';

void main() {
  runApp(const SheAlertApp());
}

class SheAlertApp extends StatelessWidget {
  const SheAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SheAlert',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool alertActive = false;
  DateTime? lastAlertTime;

  void _triggerTestAlert() {
    setState(() {
      alertActive = true;
      lastAlertTime = DateTime.now();
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🚨 PANIC ALERT TRIGGERED'),
        content: Text(
          'Simulated alert fired.\nTimestamp: ${lastAlertTime.toString()}\n\n'
          '(Real version will attach photo + GPS + send via WhatsApp/SMS)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SheAlert Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              alertActive ? Icons.warning_amber_rounded : Icons.shield_outlined,
              size: 80,
              color: alertActive ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 20),
            Text(
              alertActive ? 'Last Alert Sent' : 'No Active Alerts',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (lastAlertTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('${lastAlertTime!.toLocal()}'),
              ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _triggerTestAlert,
              icon: const Icon(Icons.emergency),
              label: const Text('Trigger Test Alert'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}