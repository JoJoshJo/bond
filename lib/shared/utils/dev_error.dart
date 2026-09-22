import 'package:supabase_flutter/supabase_flutter.dart';

/// Full, human-readable error text for debugging — PostgREST errors include
/// their code, message, details and hint. Only SHOWN in dev builds
/// (`kShowDevTools`); release builds keep the friendly wording.
String devErrorText(Object e) {
  if (e is PostgrestException) {
    return [
      'PostgrestException ${e.code ?? ''}'.trim(),
      e.message,
      if (e.details != null && '${e.details}'.isNotEmpty) 'details: ${e.details}',
      if (e.hint != null && e.hint!.isNotEmpty) 'hint: ${e.hint}',
    ].join('\n');
  }
  return e.toString();
}
