import 'package:flutter/foundation.dart';

/// BOND's neutral AI response — what the app sees regardless of provider.
@immutable
class AiResponse {
  const AiResponse({
    required this.text,
    required this.provider,
    required this.model,
  });

  final String text;
  final String provider;
  final String model;

  factory AiResponse.fromJson(Map<String, dynamic> json) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AiResponse(
      text: (json['text'] as String?) ?? '',
      provider: (meta['provider'] as String?) ?? 'unknown',
      model: (meta['model'] as String?) ?? 'unknown',
    );
  }
}
