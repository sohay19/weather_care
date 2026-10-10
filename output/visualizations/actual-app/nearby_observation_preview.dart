import 'package:flutter/material.dart';
import '../../../theme/weather_theme.dart';

// 화면 검토용 사본에서만 사용하는 예시 값. 운영 응답/모델 계약이 아니다.
class PreviewSource {
  static double distanceKm = 5.1;
}

class NearbyObservationPreview extends StatelessWidget {
  final double distanceKm;
  const NearbyObservationPreview({super.key, required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final farExample = distanceKm == 51.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: WeatherCareTheme.primarySoft,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: WeatherCareTheme.surface,
              showDragHandle: true,
              builder: (context) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('인근 실황 안내', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Text('현재 위치에서 약 ${distanceKm.toStringAsFixed(1)}km 떨어진 정상 격자의 실황을 사용했어요.'),
                    const SizedBox(height: 12),
                    const Text('기온·체감·습도·바람·강수는 같은 격자의 같은 시각 자료예요.\n기상청 10분 격자 실황 · 11:40 관측'),
                    const SizedBox(height: 12),
                    const Text('지역명과 시간별 예보는 현재 GPS 위치 기준이에요. 자외선·대기질·가시거리는 각각의 자료를 사용해요.'),
                  ],
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.near_me_outlined, size: 16, color: WeatherCareTheme.primaryDeep),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text('인근 실황 · 약 ${distanceKm.toStringAsFixed(1)}km',
                      style: const TextStyle(color: WeatherCareTheme.primaryDeep, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const Icon(Icons.info_outline_rounded, size: 15, color: WeatherCareTheme.primaryDeep),
                ],
              ),
            ),
          ),
        ),
        if (farExample) ...[
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(color: WeatherCareTheme.attentionSoft, borderRadius: BorderRadius.circular(13)),
            child: const Text('실황 출처가 멀어 현재 위치의 날씨와 차이가 클 수 있어요.',
              style: TextStyle(color: WeatherCareTheme.attentionDeep, fontSize: 11, height: 1.45, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}
