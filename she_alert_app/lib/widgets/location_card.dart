import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LocationCard extends StatelessWidget {
  final String place;
  final String updatedLabel;
  final bool live;
  const LocationCard({
    super.key,
    required this.place,
    required this.updatedLabel,
    this.live = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = live ? AppColors.teal : AppColors.textSecondary;
    return Container(
      width: double.infinity,
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.card(),
      child: Stack(
        children: [
          if (live)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    CircleAvatar(
                      radius: 3,
                      backgroundColor: AppColors.teal,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: AppColors.teal,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Center(
            child: Icon(Icons.location_on, color: color, size: 42),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  place,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      updatedLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}