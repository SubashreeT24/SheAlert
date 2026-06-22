import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SafetyStatus { safe, disconnected }

class StatusCard extends StatelessWidget {
  final SafetyStatus status;
  const StatusCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isSafe = status == SafetyStatus.safe;
    final color = isSafe ? AppColors.teal : AppColors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: AppTheme.card(glow: color),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isSafe
                    ? [AppColors.teal, const Color(0xFF38BDF8)]
                    : [color, AppColors.redDark],
              ),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.5), blurRadius: 16),
              ],
            ),
            child: Icon(
              isSafe ? Icons.verified_user : Icons.warning_amber_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isSafe ? 'Your Safety, Your Control' : 'Device disconnected',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isSafe
                    ? 'All Clear. Shield Active.'
                    : 'Tracking paused · reconnect to resume',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}