import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../theme/app_theme.dart';
import '../widgets/status_card.dart';
import '../widgets/location_card.dart';
import '../widgets/info_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool connected = true;
  String place = "Locating...";
  DateTime lastUpdate = DateTime.now();
  StreamSubscription<Position>? _posSub;
  Timer? _ageTimer;
  Timer? _holdTimer;
  bool _isHolding = false;
  double _holdProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _startTracking();
    _ageTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  Future<void> _startTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => connected = false);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => connected = false);
        return;
      }
    }

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        final p = placemarks.first;
        setState(() {
          place =
              "${p.subLocality ?? p.locality ?? ''}, ${p.locality ?? ''}"
                  .trim();
          lastUpdate = DateTime.now();
          connected = true;
        });
      } catch (_) {
        setState(() {
          lastUpdate = DateTime.now();
          connected = true;
        });
      }
    }, onError: (_) => setState(() => connected = false));
  }

  String get _updatedLabel {
    final diff = DateTime.now().difference(lastUpdate);
    if (diff.inMinutes < 1) return "${diff.inSeconds}s ago";
    return "${diff.inMinutes} min ago";
  }

  // Press and hold 2 seconds logic
  void _onHoldStart() {
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    const interval = Duration(milliseconds: 50);
    _holdTimer = Timer.periodic(interval, (timer) {
      setState(() {
        _holdProgress += 50 / 2000; // 2000ms = 2 seconds
      });

      if (_holdProgress >= 1.0) {
        timer.cancel();
        _holdProgress = 1.0;
        _triggerAlert();
      }
    });
  }

  void _onHoldEnd() {
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  void _triggerAlert() {
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });

    // TODO: Connect to Firebase to send SMS
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              '🚨 Alert Sent!',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Emergency alert has been sent to all your contacts!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(color: AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ageTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatusCard(
              status: connected
                  ? SafetyStatus.safe
                  : SafetyStatus.disconnected,
            ),
            const SizedBox(height: 16),
            connected
                ? LocationCard(
                    place: place,
                    updatedLabel: "updated $_updatedLabel",
                    live: true,
                  )
                : LocationCard(
                    place: "Last seen: $place",
                    updatedLabel: _updatedLabel,
                    live: false,
                  ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InfoTile(label: 'Contacts', value: '3'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InfoTile(
                    label: 'Device',
                    value: connected ? 'Connected' : 'Disconnected',
                    valueColor:
                        connected ? AppColors.teal : AppColors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Emergency Alert Button
            connected
                ? GestureDetector(
                    onLongPressStart: (_) => _onHoldStart(),
                    onLongPressEnd: (_) => _onHoldEnd(),
                    child: Stack(
                      children: [
                        // Button background
                        Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.red,
                                AppColors.redDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.red.withOpacity(0.4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Trigger emergency alert',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Progress overlay while holding
                        if (_isHolding)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: LinearProgressIndicator(
                                value: _holdProgress,
                                backgroundColor:
                                    Colors.white.withOpacity(0.2),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                minHeight: double.infinity,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )

                // Reconnect button when disconnected
                : Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Center(
                      child: TextButton(
                        onPressed: _startTracking,
                        child: const Text(
                          'Reconnect device',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

            const SizedBox(height: 6),
            Center(
              child: Text(
                connected
                    ? 'Press and hold for 2 seconds to send'
                    : 'Emergency alert needs device connection',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}