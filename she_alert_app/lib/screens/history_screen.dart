import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AlertType { auto, manual }

class AlertEntry {
  final AlertType type;
  final String title;
  final String time;
  final String location;
  AlertEntry({
    required this.type,
    required this.title,
    required this.time,
    required this.location,
  });
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String filter = 'All';
  final List<AlertEntry> entries = [
    AlertEntry(
      type: AlertType.auto,
      title: '"Help help please save me..."',
      time: 'Today, 2:14 PM',
      location: 'T Nagar, Chennai',
    ),
    AlertEntry(
      type: AlertType.manual,
      title: 'Manual test triggered from app',
      time: 'Yesterday, 9:02 AM',
      location: 'Anna Nagar, Chennai',
    ),
    AlertEntry(
      type: AlertType.manual,
      title: 'Manual test triggered from app',
      time: '3 days ago, 6:10 PM',
      location: 'Velachery, Chennai',
    ),
  ];

  List<AlertEntry> get filtered {
    if (filter == 'Auto') {
      return entries.where((e) => e.type == AlertType.auto).toList();
    }
    if (filter == 'Manual') {
      return entries.where((e) => e.type == AlertType.manual).toList();
    }
    return entries;
  }

  int get autoCount => entries.where((e) => e.type == AlertType.auto).length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _summaryTile('TOTAL', '${entries.length}', false),
                const SizedBox(width: 10),
                _summaryTile('AUTO', '$autoCount', true),
                const SizedBox(width: 10),
                _summaryTile('THIS WEEK', '3', false),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: ['All', 'Auto', 'Manual'].map((f) {
                final selected = filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.teal
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _alertCard(filtered[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String label, String value, bool isAuto) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isAuto ? const Color(0xFF0D2E2A) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAuto
                ? AppColors.teal.withOpacity(0.3)
                : AppColors.cardBorder,
          ),
        ),
        child: Column(
          children: [
            if (isAuto)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFFB300), size: 14),
                  SizedBox(width: 4),
                  Text('AUTO',
                      style: TextStyle(
                          color: AppColors.teal, fontSize: 11)),
                ],
              )
            else
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _alertCard(AlertEntry alert) {
    final isAuto = alert.type == AlertType.auto;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAuto ? const Color(0xFF0D2E2A) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAuto
              ? AppColors.teal.withOpacity(0.3)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isAuto
                        ? Icons.warning_amber_rounded
                        : Icons.pan_tool_alt,
                    color: AppColors.teal,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAuto ? 'Auto alert' : 'Manual alert',
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                alert.time,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            alert.title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on,
                  color: Colors.redAccent, size: 14),
              const SizedBox(width: 4),
              Text(
                alert.location,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}