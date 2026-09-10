/// Terms of Service + Privacy Policy content for Usora.
///
/// NOTE: written to accurately reflect Usora's actual data practices, but it is
/// NOT lawyer-reviewed — have counsel review before launch. Fill the
/// [contactEmail] / [governingLaw] placeholders with real values.
class LegalContent {
  const LegalContent._();

  static const String lastUpdated = 'September 8, 2026';
  static const String contactEmail = 'support@bond.app'; // TODO: set real contact
  static const String governingLaw =
      'the laws of your jurisdiction'; // TODO: set real governing law

  static const List<LegalSection> privacyPolicy = [
    LegalSection('Who we are',
        'Usora is a private app for two people in a relationship to share a space together — messages, photos, voice notes, memories, daily questions, games, and a companion creature. This policy explains what we collect, how we use it, and the promises we keep.'),
    LegalSection('The short version — our promise',
        'We never sell your data. We never use your content to train AI models. Only the two of you can see your shared space. We ask for the minimum we need, and we tell you plainly what we do with it.'),
    LegalSection('Information we collect',
        'Account: your email address (for sign-in and account recovery).\n\n'
            'Your shared content: the things you and your partner create together — text messages, photos, videos, voice notes, saved memories and captions, daily-question answers, game moves, your couple name and important dates. This belongs to the two of you.\n\n'
            'Location: only when you ask your creature to find nearby places (restaurants, theaters, attractions, museums). Your approximate coordinates are used for that single request and are not stored by us or tracked over time.\n\n'
            'We do not collect your contacts, browsing history, or precise background location, and we do not track you across other apps.'),
    LegalSection('How we use your information',
        'To provide the app: create your account, link you with your partner, and sync your shared space between your devices. To power features you choose to use — the daily question, games, memories, and the AI companion. We use your content only to operate these features for you and your partner.'),
    LegalSection('AI features',
        'When you talk to your creature, your message is sent through our own server to a third-party AI provider (currently Google Gemini) to generate a reply. We send only the minimum needed for that request (for example, your message and a little light context such as your couple name) — never your message history, photos, or private content. AI providers do not use this data to train their models. AI replies and suggestions may be imperfect; the creature finds and suggests, and you always confirm anything that matters.'),
    LegalSection('Third-party services',
        'Supabase — our backend: secure database, authentication, and encrypted file storage.\n\n'
            'Google Gemini (via our server) — generates the creature\'s replies. Minimal context only; not used to train models.\n\n'
            'TMDB — movie and show information for recommendations. This product uses the TMDB API but is not endorsed or certified by TMDB.\n\n'
            'Foursquare — nearby-places information when you ask the creature to find somewhere to go.\n\n'
            'These providers process data only to deliver their part of the service.'),
    LegalSection('How your data is protected',
        'Your shared space is protected by row-level security so that only the two of you can ever access it, and your data is encrypted in transit and at rest. Media is stored in a private bucket and served only through short-lived signed links. We are honest about what we deliver: true end-to-end encryption is not offered yet, so we do not claim it.'),
    LegalSection('Data retention & deletion',
        'We keep your content while your account and couple are active, so it\'s there when you return. If you unlink from your partner or delete your account, your associated data is removed. You can request deletion at any time by contacting us.'),
    LegalSection('Your rights',
        'You can access, correct, or delete your information. Contact us and we\'ll help. Depending on where you live, you may have additional rights under local law, which we honor.'),
    LegalSection('Age',
        'Usora is for adults. You must be 18 or older to use it. We do not knowingly collect information from anyone under 18.'),
    LegalSection('Changes to this policy',
        'If we change this policy, we\'ll update the date above and, for significant changes, let you know in the app.'),
    LegalSection('Contact',
        'Questions about privacy? Reach us at $contactEmail.'),
  ];

  static const List<LegalSection> termsOfService = [
    LegalSection('Acceptance',
        'By creating an account or using Usora, you agree to these Terms. If you don\'t agree, please don\'t use the app.'),
    LegalSection('Eligibility',
        'You must be 18 or older to use Usora. By using it you confirm that you are.'),
    LegalSection('Your account',
        'Keep your login secure and provide accurate information. You\'re responsible for activity under your account. Let us know if you suspect unauthorized access.'),
    LegalSection('The couple space',
        'Usora is designed for two people. When you link with a partner, you share a private space. Content you add is visible to your partner. If you unlink, the shared space is closed per our breakup/unlink process, and progress is handled with care.'),
    LegalSection('Your content',
        'You own the content you create. You grant Usora the limited permission needed to store your content and display it to you and your linked partner, and to operate the features you use. We never sell your content and never use it to train AI models. You\'re responsible for the content you share and confirm you have the right to share it.'),
    LegalSection('Acceptable use',
        'Don\'t use Usora for anything illegal, harmful, harassing, or abusive, and don\'t attempt to break, overload, or misuse the service or access data that isn\'t yours.'),
    LegalSection('AI features',
        'Usora\'s companion can suggest things (like movies or nearby places) using third-party data and AI. Suggestions may be wrong or incomplete and are not professional, medical, legal, or financial advice. The creature finds and suggests; you decide and confirm anything involving money, bookings, or sending.'),
    LegalSection('Third-party services',
        'Usora relies on third-party services (Supabase, Google Gemini, TMDB, Foursquare) to work. Their availability and content are outside our control, and your use of features that depend on them is also subject to their terms.'),
    LegalSection('Disclaimers',
        'Usora is provided "as is" without warranties of any kind. We work hard to keep it reliable, but we can\'t guarantee it will always be available, error-free, or that content from third parties will be accurate.'),
    LegalSection('Limitation of liability',
        'To the extent permitted by law, Usora is not liable for indirect, incidental, or consequential damages arising from your use of the app.'),
    LegalSection('Termination',
        'You may stop using Usora and delete your account at any time. We may suspend or end access if these Terms are violated.'),
    LegalSection('Changes',
        'We may update these Terms; we\'ll update the date above and, for significant changes, notify you in the app. Continued use means you accept the updated Terms.'),
    LegalSection('Governing law',
        'These Terms are governed by $governingLaw.'),
    LegalSection('Contact',
        'Questions about these Terms? Reach us at $contactEmail.'),
  ];
}

/// One heading + body block in a legal document.
class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading;
  final String body;
}
