Map<String, dynamic> sampleTodayPayload(String installationId) {
  return {
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
        'type': 'VERY_HOT_AND_HUMID',
        'title': '땀이 비 오듯 나는 날',
      },
      {
        'type': 'LAUNDRY_GOOD',
        'title': '빨래가 잘 마르는 날',
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
          {'type': 'SUNSCREEN', 'recommended': true, 'priority': 80, 'title': '선크림', 'description': '자외선 주의', 'notificationEligible': true},
          {'type': 'PARASOL', 'recommended': true, 'priority': 75, 'title': '양산', 'description': '장시간 외출 시', 'notificationEligible': false},
          {'type': 'WATER', 'recommended': true, 'priority': 70, 'title': '물', 'description': '수분 보충', 'notificationEligible': true},
        ],
      },
      {
        'timeLabel': '18',
        'stateLabel': '퇴근할 때',
        'detail': '비 올 가능성이 높아요.',
        'recommendations': [
          {'type': 'UMBRELLA', 'recommended': true, 'priority': 90, 'title': '우산', 'description': '퇴근 전 강수', 'notificationEligible': true},
        ],
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
          {'type': 'PARASOL', 'recommended': true, 'priority': 80, 'title': '양산', 'description': '햇빛 강함', 'notificationEligible': false},
          {'type': 'SUNSCREEN', 'recommended': true, 'priority': 75, 'title': '선크림', 'description': '자외선 강함', 'notificationEligible': false},
        ]
      },
      {
        'date': '화',
        'weatherLabel': '비',
        'min': '23',
        'max': '28',
        'recommendations': [
          {'type': 'UMBRELLA', 'recommended': true, 'priority': 90, 'title': '우산', 'description': '비가 가능', 'notificationEligible': false},
        ],
      },
      {
        'date': '수',
        'weatherLabel': '흐림',
        'min': '22',
        'max': '27',
        'recommendations': [
          {'type': 'OUTERWEAR', 'recommended': true, 'priority': 60, 'title': '겉옷', 'description': '쌀쌀', 'notificationEligible': false},
        ],
      },
      {
        'date': '목',
        'weatherLabel': '맑음',
        'min': '24',
        'max': '31',
        'recommendations': [
          {'type': 'WATER', 'recommended': true, 'priority': 60, 'title': '물', 'description': '더위', 'notificationEligible': false},
          {'type': 'SUNSCREEN', 'recommended': true, 'priority': 60, 'title': '선크림', 'description': '자외선', 'notificationEligible': false},
        ],
      },
      {
        'date': '금',
        'weatherLabel': '맑음',
        'min': '23',
        'max': '30',
        'recommendations': [
          {'type': 'WATER', 'recommended': true, 'priority': 65, 'title': '물', 'description': '수분 보충', 'notificationEligible': false},
        ],
      },
      {'date': '토', 'weatherLabel': '맑음', 'min': '24', 'max': '29', 'recommendations': []},
      {'date': '일', 'weatherLabel': '흐림', 'min': '21', 'max': '26', 'recommendations': []},
    ],
  };
}

