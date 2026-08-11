import 'package:flutter/material.dart';
import '../../../models/weather.dart';

class WeatherInfoCard extends StatelessWidget {
  final CurrentWeather current;

  const WeatherInfoCard({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '현재 ${current.temperature.toStringAsFixed(1)}°C',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text('${current.sky ?? '맑음'}'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _info('체감', '${current.apparentTemperature.toStringAsFixed(1)}°C'),
                if (current.humidity != null) _info('습도', '${current.humidity!.toStringAsFixed(0)}%'),
                if (current.uvIndex != null) _info('UV', current.uvIndex!.toStringAsFixed(1)),
                if (current.pm25 != null) _info('PM2.5', '${current.pm25}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Chip(label: Text('$label $value'));
  }
}

