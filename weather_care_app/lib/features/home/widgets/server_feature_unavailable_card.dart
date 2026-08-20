import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';
import 'home_section_header.dart';

class ServerFeatureUnavailableCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const ServerFeatureUnavailableCard({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(
            icon: icon,
            title: title,
            subtitle: '운영 서버에서 계산하는 기능입니다',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: WeatherCareTheme.textSecondary,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '운영 서버 미연결로 미지원',
                    style: TextStyle(
                      color: WeatherCareTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
