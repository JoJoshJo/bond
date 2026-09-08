import 'dart:math';

/// One curated prompt: a warm, genuine, inclusive relationship question.
class BankPrompt {
  const BankPrompt(this.content, this.category);
  final String content;
  final String category; // communication | gratitude | intimacy | adventure | reflection
}

/// Curated prompt bank for the daily question (AI-personalized prompts are a
/// future layer). Principles: inclusive by default — no assumptions about
/// marriage, kids, gender, or relationship shape. Intimacy is kept SOFT
/// (emotional closeness, not spicy — spicy is a gated v2 feature). Warm and
/// genuine over clever.
class PromptBank {
  const PromptBank._();

  static const prompts = <BankPrompt>[
    // communication
    BankPrompt('What is something you wish I asked you about more often?', 'communication'),
    BankPrompt('When do you feel most understood by me?', 'communication'),
    BankPrompt('Is there something small on your mind lately you haven\'t said out loud?', 'communication'),
    BankPrompt('How do you like to be comforted on a hard day?', 'communication'),
    BankPrompt('What is one way I could show up better for you this week?', 'communication'),
    BankPrompt('What is a topic you\'d love for us to talk about more?', 'communication'),
    BankPrompt('When you\'re quiet, what\'s usually going on inside?', 'communication'),

    // gratitude
    BankPrompt('What is one thing I did recently that made your day easier?', 'gratitude'),
    BankPrompt('What is a small thing about me you\'re grateful for?', 'gratitude'),
    BankPrompt('What is a moment from this week you want to remember?', 'gratitude'),
    BankPrompt('What is something you appreciate about us that\'s easy to overlook?', 'gratitude'),
    BankPrompt('Who or what are you thankful for right now, and why?', 'gratitude'),
    BankPrompt('What made you smile most recently?', 'gratitude'),

    // intimacy (soft — emotional closeness)
    BankPrompt('When did you first feel truly at ease with me?', 'intimacy'),
    BankPrompt('What makes you feel closest to me?', 'intimacy'),
    BankPrompt('What is a memory of us you return to when you miss me?', 'intimacy'),
    BankPrompt('What does feeling safe with someone mean to you?', 'intimacy'),
    BankPrompt('What is something you find quietly beautiful about me?', 'intimacy'),
    BankPrompt('When do you feel most loved — what does it look like?', 'intimacy'),
    BankPrompt('What is a little ritual of ours that means a lot to you?', 'intimacy'),

    // adventure
    BankPrompt('If we could wake up anywhere together tomorrow, where would it be?', 'adventure'),
    BankPrompt('What is something new you\'d love for us to try together?', 'adventure'),
    BankPrompt('What is a tiny adventure we could have this week?', 'adventure'),
    BankPrompt('What is on your someday list that you\'d want me there for?', 'adventure'),
    BankPrompt('If we had a free day with no plans, how would you want to spend it?', 'adventure'),
    BankPrompt('What is a place from your past you\'d love to show me?', 'adventure'),

    // reflection
    BankPrompt('What is something you\'re proud of yourself for lately?', 'reflection'),
    BankPrompt('How have you changed since we met — in a good way?', 'reflection'),
    BankPrompt('What is something you\'re looking forward to?', 'reflection'),
    BankPrompt('What does a good life look like to you right now?', 'reflection'),
    BankPrompt('What is a small goal you\'re quietly working toward?', 'reflection'),
    BankPrompt('What is something you needed to hear this week?', 'reflection'),
    BankPrompt('What is one thing that brought you peace recently?', 'reflection'),
    BankPrompt('What is a fear you\'ve been sitting with, if any?', 'reflection'),
  ];

  /// Pick a prompt not among [recentContents]; falls back to any if all recent.
  static BankPrompt pick(Set<String> recentContents, [Random? random]) {
    final r = random ?? Random();
    final fresh =
        prompts.where((p) => !recentContents.contains(p.content)).toList();
    final pool = fresh.isNotEmpty ? fresh : prompts;
    return pool[r.nextInt(pool.length)];
  }
}
