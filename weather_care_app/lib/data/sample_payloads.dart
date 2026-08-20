Map<String, dynamic> sampleTodayPayload(String installationId) {
  return {
    'dataSource': '샘플 데이터',
    'region': {'nx': 60, 'ny': 121, 'name': '수원'},
    'brief': '오늘은 덥다가 퇴근할 때 비가 와요.',
    'current': {
      'temperature': 29.5,
      'apparentTemperature': 32.1,
      'pm10': 33,
      'pm25': 18,
      'humidity': 58,
      'windSpeed': 2.4,
      'uvIndex': 7,
      'skyCondition': '부분 흐림'
    },
    'recommendations': [
      {
        'type': 'UMBRELLA',
        'recommended': true,
        'priority': 90,
        'title': '우산이 필요해요',
        'description': '오후 비가 예상돼요. 우산을 챙겨요.',
        'notificationEligible': true,
      },
      {
        'type': 'WATER',
        'recommended': true,
        'priority': 70,
        'title': '물을 챙겨요',
        'description': '체감온도가 높아요. 수분을 자주 보충하세요.',
        'notificationEligible': true,
      },
      {
        'type': 'SUNSCREEN',
        'recommended': true,
        'priority': 65,
        'title': '선크림 챙겨요',
        'description': '낮 시간대 자외선이 강해요.',
        'notificationEligible': true,
      },
      {
        'type': 'OUTERWEAR',
        'recommended': false,
        'priority': 0,
        'title': '겉옷은 필요하지 않아요',
        'description': '현재는 기온차가 크지 않아요.',
        'notificationEligible': false,
      },
    ],
    'lifestyleMessages': [
      {
        'type': 'LAUNDRY_GOOD',
        'title': '빨래는 오전에 끝내요',
        'description': '오후 4시 전까지는 비 걱정이 적어요.',
      },
      {
        'type': 'OUTDOOR_ACTIVITY_CAUTION',
        'title': '산책은 해 질 무렵에',
        'description': '낮 더위를 피해 오후 8시 이후가 편안해요.',
      },
      {
        'type': 'VENTILATION_GOOD',
        'title': '환기는 오후에 짧게',
        'description': '대기질이 무난한 오후 2시 전후를 추천해요.',
      },
    ],
    'timeline': [
      {
        'timeLabel': '07',
        'stateLabel': '출근할 때',
        'detail': '선선해요. 특별히 챙길 건 없어요.',
        'recommendations': [
          {
            'type': 'OUTERWEAR',
            'recommended': false,
            'priority': 0,
            'title': '겉옷',
            'description': '필요 없음',
            'notificationEligible': false,
          },
        ],
      },
      {
        'timeLabel': '12',
        'stateLabel': '점심 무렵',
        'detail': '햇볕이 강하고 체감온도가 높아요.',
        'recommendations': [
          {
            'type': 'SUNSCREEN',
            'recommended': true,
            'priority': 80,
            'title': '선크림',
            'description': '자외선 주의',
            'notificationEligible': true
          },
          {
            'type': 'PARASOL',
            'recommended': true,
            'priority': 75,
            'title': '양산',
            'description': '장시간 외출 시',
            'notificationEligible': false
          },
          {
            'type': 'WATER',
            'recommended': true,
            'priority': 70,
            'title': '물',
            'description': '수분 보충',
            'notificationEligible': true
          },
        ],
      },
      {
        'timeLabel': '18',
        'stateLabel': '퇴근할 때',
        'detail': '비 올 가능성이 높아요.',
        'recommendations': [
          {
            'type': 'UMBRELLA',
            'recommended': true,
            'priority': 90,
            'title': '우산',
            'description': '퇴근 전 강수',
            'notificationEligible': true
          },
        ],
      },
    ],
    'hourly': [
      {
        'time': '06',
        'temperature': 23.0,
        'apparentTemperature': 23.5,
        'precipitationProbability': 10,
        'precipitationAmount': 0,
        'snowProbability': 0,
        'snowfallAmount': 0,
        'windSpeed': 1.4,
        'skyCondition': '맑음',
      },
      {
        'time': '09',
        'temperature': 26.0,
        'apparentTemperature': 27.2,
        'precipitationProbability': 10,
        'precipitationAmount': 0,
        'snowProbability': 0,
        'snowfallAmount': 0,
        'windSpeed': 1.8,
        'skyCondition': '구름 조금',
      },
      {
        'time': '12',
        'temperature': 29.5,
        'apparentTemperature': 32.1,
        'precipitationProbability': 20,
        'precipitationAmount': 0,
        'snowProbability': 0,
        'snowfallAmount': 0,
        'windSpeed': 2.4,
        'skyCondition': '부분 흐림',
      },
      {
        'time': '15',
        'temperature': 31.0,
        'apparentTemperature': 34.0,
        'precipitationProbability': 35,
        'precipitationAmount': 0,
        'snowProbability': 0,
        'snowfallAmount': 0,
        'windSpeed': 3.1,
        'skyCondition': '흐림',
      },
      {
        'time': '18',
        'temperature': 27.0,
        'apparentTemperature': 29.0,
        'precipitationProbability': 75,
        'precipitationAmount': 3.2,
        'snowProbability': 0,
        'snowfallAmount': 0,
        'windSpeed': 5.8,
        'skyCondition': '비',
      },
      {
        'time': '21',
        'temperature': 24.0,
        'apparentTemperature': 25.0,
        'precipitationProbability': 60,
        'precipitationAmount': 1.1,
        'snowProbability': 0,
        'snowfallAmount': 0,
        'windSpeed': 4.3,
        'skyCondition': '비',
      },
    ],
    'installationId': installationId,
  };
}

Map<String, dynamic> sampleWeeklyPayload() {
  return {
    'days': [
      {
        'date': '월',
        'weatherLabel': '맑음',
        'min': '24',
        'max': '32',
        'recommendations': [
          {
            'type': 'PARASOL',
            'recommended': true,
            'priority': 80,
            'title': '양산',
            'description': '햇빛 강함',
            'notificationEligible': false
          },
          {
            'type': 'SUNSCREEN',
            'recommended': true,
            'priority': 75,
            'title': '선크림',
            'description': '자외선 강함',
            'notificationEligible': false
          },
        ]
      },
      {
        'date': '화',
        'weatherLabel': '비',
        'min': '23',
        'max': '28',
        'recommendations': [
          {
            'type': 'UMBRELLA',
            'recommended': true,
            'priority': 90,
            'title': '우산',
            'description': '비가 가능',
            'notificationEligible': false
          },
        ],
      },
      {
        'date': '수',
        'weatherLabel': '흐림',
        'min': '22',
        'max': '27',
        'recommendations': [
          {
            'type': 'OUTERWEAR',
            'recommended': true,
            'priority': 60,
            'title': '겉옷',
            'description': '쌀쌀',
            'notificationEligible': false
          },
        ],
      },
      {
        'date': '목',
        'weatherLabel': '맑음',
        'min': '24',
        'max': '31',
        'recommendations': [
          {
            'type': 'WATER',
            'recommended': true,
            'priority': 60,
            'title': '물',
            'description': '더위',
            'notificationEligible': false
          },
          {
            'type': 'SUNSCREEN',
            'recommended': true,
            'priority': 60,
            'title': '선크림',
            'description': '자외선',
            'notificationEligible': false
          },
        ],
      },
      {
        'date': '금',
        'weatherLabel': '맑음',
        'min': '23',
        'max': '30',
        'recommendations': [
          {
            'type': 'WATER',
            'recommended': true,
            'priority': 65,
            'title': '물',
            'description': '수분 보충',
            'notificationEligible': false
          },
        ],
      },
      {
        'date': '토',
        'weatherLabel': '맑음',
        'min': '24',
        'max': '29',
        'recommendations': []
      },
      {
        'date': '일',
        'weatherLabel': '흐림',
        'min': '21',
        'max': '26',
        'recommendations': []
      },
    ],
  };
}
