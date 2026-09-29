/// Character caps for user-entered text.
///
/// These MUST match the `char_length(...) <= N` CHECK constraints on the
/// matching Postgres columns — the app cap is the friendly stop, the database
/// constraint is what a modified client can't get past.
library;

/// `messages.content` — chat + creature chat.
const int kMaxChatMessageChars = 2000;

/// `prompt_responses.response`.
const int kMaxPromptAnswerChars = 2000;

/// `important_dates.label` / `.note`.
const int kMaxEventTitleChars = 100;
const int kMaxEventNoteChars = 500;

/// `memories.caption`.
const int kMaxMemoryCaptionChars = 500;

/// `couples.name`.
const int kMaxCoupleNameChars = 50;

/// `users.display_name` (provider-supplied; clamped before write).
const int kMaxDisplayNameChars = 50;
