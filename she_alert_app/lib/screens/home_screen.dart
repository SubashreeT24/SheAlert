import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/status_card.dart';
import '../widgets/location_card.dart';
import '../widgets/info_tile.dart';

// TODO: replace with real auth uid once login is built
const String currentUserId = 'testuser1';

// Your Cloud Function URL — must match exactly (case-sensitive)
const String _manualAlertUrl =
    'https://asia-southeast1-shealert-222cc.cloudfunctions.net/manualAlert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool connected = true;
  String place = "Locating...";
  double? _currentLat;
  double? _currentLng;
  DateTime lastUpdate = DateTime.now();
  StreamSubscription<Position>? _posSub;
  Timer? _ageTimer;
  Timer? _holdTimer;
  bool _isHolding = false;
  double _holdProgress = 0.0;
  bool _isSendingAlert = false;

  late final Stream<int> _contactCountStream;

  @override
  void initState() {
    super.initState();
    _contactCountStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('contacts')
        .snapshots()
        .map((snap) => snap.docs.length);

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
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .set({
          'lastKnownLocation': {
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          }
        }, SetOptions(merge: true));
      } catch (_) {}

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

  void _onHoldStart() {
    if (_isSendingAlert) return;
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    const interval = Duration(milliseconds: 50);
    _holdTimer = Timer.periodic(interval, (timer) {
      setState(() {
        _holdProgress += 50 / 2000;
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
    if (!_isSendingAlert) {
      setState(() {
        _isHolding = false;
        _holdProgress = 0.0;
      });
    }
  }

  Future<void> _triggerAlert() async {
    if (_isSendingAlert) return;

    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
      _isSendingAlert = true;
    });

    // Check contacts first — abort early if none
    final contactSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('contacts')
        .get();

    if (contactSnap.docs.isEmpty) {
      if (mounted) {
        setState(() => _isSendingAlert = false);
        _showErrorSnackbar(
            'No contacts found. Please add emergency contacts first.');
      }
      return;
    }

    // Show optimistic dialog immediately
    if (mounted) _showSendingDialog();

    try {
      final body = <String, dynamic>{'userId': currentUserId};
      if (_currentLat != null && _currentLng != null) {
        body['location'] = {
          'latitude': _currentLat,
          'longitude': _currentLng,
        };
      }

      debugPrint('Sending manual alert to: $_manualAlertUrl');
      debugPrint('Body: ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse(_manualAlertUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 70));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (!mounted) return;

      // Close the sending dialog
      Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        final respBody = jsonDecode(response.body) as Map<String, dynamic>;
        final sent = respBody['sent'] ?? 0;
        final message = respBody['message'] as String? ?? 'Alert sent';
        _showSuccessDialog(sent: sent as int, message: message);
      } else {
        String errorMessage = 'Unknown error (${response.statusCode})';
        try {
          final respBody = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage =
              respBody['error'] ?? respBody['message'] ?? errorMessage;
        } catch (_) {
          errorMessage = 'Status ${response.statusCode}: ${response.body}';
        }
        _showErrorSnackbar('Alert failed: $errorMessage');
      }
    } on TimeoutException {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorSnackbar('Request timed out. Check your connection.');
    } on http.ClientException catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorSnackbar('Network error: ${e.message}');
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorSnackbar('Could not send alert: $e');
    } finally {
      if (mounted) setState(() => _isSendingAlert = false);
    }
  }

  void _showSendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              '🚨 Sending Alert...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Row(
          children: [
            CircularProgressIndicator(
              color: AppColors.teal,
              strokeWidth: 2.5,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Sending emergency alert to your contacts via WhatsApp. This may take up to a minute.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog({int sent = 0, String message = ''}) {
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
        content: Text(
          sent > 0
              ? 'Emergency alert sent to $sent contact${sent == 1 ? '' : 's'} via WhatsApp!'
              : message.isNotEmpty
                  ? message
                  : 'Emergency alert has been sent to your contacts via WhatsApp!',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.teal)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 6),
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
                  child: StreamBuilder<int>(
                    stream: _contactCountStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return InfoTile(
                        label: 'Contacts',
                        value: '$count',
                      );
                    },
                  ),
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

            connected
                ? GestureDetector(
                    onLongPressStart: (_) => _onHoldStart(),
                    onLongPressEnd: (_) => _onHoldEnd(),
                    child: Stack(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.red, AppColors.redDark],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.red.withOpacity(0.4),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isSendingAlert
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Row(
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
                                        Colors.white),
                                minHeight: double.infinity,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )

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
                _isSendingAlert
                    ? 'Sending alert...'
                    : connected
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