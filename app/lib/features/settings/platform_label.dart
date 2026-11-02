/// How a platform is named to a person — "Android", "Windows" — from the
/// `Platform.operatingSystem` string Golfy runs on and a backup records.
String platformLabel(String operatingSystem) => switch (operatingSystem) {
      'android' => 'Android',
      'windows' => 'Windows',
      _ => operatingSystem,
    };
