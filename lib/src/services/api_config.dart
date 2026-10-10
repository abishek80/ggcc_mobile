import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kDebugMode) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2/ggcc/api';
      }
      return 'http://localhost/ggcc/api';
    }
    return 'https://ggcc.org.in/api';
  }
}