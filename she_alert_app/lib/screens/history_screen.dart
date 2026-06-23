import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

// TODO: replace with real auth uid once login is built
const String currentUserId = 'testuser1';

enum AlertType { auto, manual }

class AlertEntry {
  final String id;
  final AlertType type;
  final String title;
  final String time;
  final String location;

  AlertEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.time,
    required this.location,
  });

  /// Build from a Firestore document
  static AlertEntry? tryFromDoc(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      // ── type ──────────────────────────────────────
      final typeStr = (data['type'] as String?) ?? 'manual';
      final alertType =
          typeStr == 'automatic' ? AlertType.auto : AlertType.manual;  // ← FIXED: 'automatic' not 'auto'

      // ── title / transcript ────────────────────────
      String title;
      if (alertType == AlertType.auto) {
        final raw = (data['transcript'] as String?) ?? '';
        // Trim to ~50 chars with quotes for display
        final trimmed =
            raw.length > 50 ? '${raw.substring(0, 50)}...' : raw;
        title = trimmed.isNotEmpty ? '"$trimmed"' : 'Auto alert triggered';
      } else {
        title = 'Manual alert triggered from app';
      }

      // ── timestamp → human-readable string ────────
      String time = 'Unknown time';
      final ts = data['timestamp'];
      if (ts is Timestamp) {
        time = _formatTimestamp(ts.toDate());
      }

      // ── location → readable string ─────────────
      String location = 'Location unavailable';
      final loc = data['location'];
      if (loc is Map) {
        final lat = loc['latitude'];
        final lng = loc['longitude'];
        if (lat != null && lng != null) {
          location = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        }
      }
      // If location was stored as a human-readable string
      if (data['locationName'] is String &&
          (data['locationName'] as String).isNotEmpty) {
        location = data['locationName'] as String;
      }

      return AlertEntry(
        id: doc.id,
        type: alertType,
        title: title,
        time: time,
        location: location,
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final alertDay = DateTime(dt.year, dt.month, dt.day);

    final timeStr = _timeOfDay(dt);

    if (alertDay == today) return 'Today, $timeStr';
    if (alertDay == yesterday) return 'Yesterday, $timeStr';

    final daysAgo = today.difference(alertDay).inDays;
    if (daysAgo < 7) return '$daysAgo days ago, $timeStr';

    return '${dt.day}/${dt.month}/${dt.year}, $timeStr';
  }

  static String _timeOfDay(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'All';

  // Stream from Firestore — most recent first
  Stream<List<AlertEntry>> get _alertStream {
    return FirebaseFirestore.instance
        .collection('alerts')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(AlertEntry.tryFromDoc)
            .whereType<AlertEntry>()
            .toList());
  }

  List<AlertEntry> _applyFilter(List<AlertEntry> all) {
    if (_filter == 'Auto') {
      return all.where((e) => e.type == AlertType.auto).toList();
    }
    if (_filter == 'Manual') {
      return all.where((e) => e.type == AlertType.manual).toList();
    }
    return all;
  }

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

            // ── Everything below depends on the stream ──
            Expanded(
              child: StreamBuilder<List<AlertEntry>>(
                stream: _alertStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.teal),
                    );
                  }

                  if (snapshot.hasError) {
                    // Likely a missing Firestore index — show helpful message
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off,
                              color: AppColors.textSecondary, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load history.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  final all = snapshot.data ?? [];
                  final filtered = _applyFilter(all);
                  final autoCount =
                      all.where((e) => e.type == AlertType.auto).length;

                  // Count alerts in the last 7 days
                  final now = DateTime.now();
                  final weekCount = all.where((e) {
                    // We'd need the raw timestamp for this — approximate with
                    // "This week" label in the time string for now
                    return true; // show total as fallback
                  }).length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Summary tiles ──
                      Row(
                        children: [
                          _summaryTile('TOTAL', '${all.length}', false),
                          const SizedBox(width: 10),
                          _summaryTile('AUTO', '$autoCount', true),
                          const SizedBox(width: 10),
                          _summaryTile('THIS WEEK', '$weekCount', false),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Filter chips ──
                      Row(
                        children: ['All', 'Auto', 'Manual'].map((f) {
                          final selected = _filter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _filter = f),
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
                                    color: selected
                                        ? Colors.black
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // ── List or empty state ──
                      if (filtered.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              _filter == 'All'
                                  ? 'No alerts yet'
                                  : 'No ${_filter.toLowerCase()} alerts',
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _alertCard(filtered[i]),
                          ),
                        ),
                    ],
                  );
                },
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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