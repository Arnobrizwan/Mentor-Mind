// ---------------------------------------------------------------------------
// SupportConfig — /config/support doc shape.
//
// Drives the Profile → Support section tiles. Admins edit this doc in Firebase
// Console to update support contact, legal URLs, and store IDs without
// shipping an app release.
//
// Fallbacks: if a field is missing or empty the corresponding tile shows a
// "coming soon" snack rather than failing silently. See _SettingsList in
// presentation/screens/profile/profile_screen.dart.
// ---------------------------------------------------------------------------

class SupportConfig {
  /// mailto: target for "Help & FAQ" — opens the user's default mail app
  /// pre-filled with the subject. Empty = tile shows a "coming soon" snack.
  final String helpEmail;

  /// Subject line pre-filled when opening the help mailto.
  final String helpEmailSubject;

  /// HTTPS URL for the privacy policy. Empty = "coming soon" snack.
  final String privacyPolicyUrl;

  /// HTTPS URL for the terms of service. Empty = "coming soon" snack.
  final String termsOfServiceUrl;

  /// Android package name used to build the Play Store rating URL
  /// (`market://details?id=<pkg>`). Empty = "coming soon".
  final String playStorePackageName;

  /// Apple App Store numeric app ID used to build the rating URL
  /// (`itms-apps://itunes.apple.com/app/id<id>`). Empty = "coming soon".
  final String appStoreId;

  const SupportConfig({
    required this.helpEmail,
    required this.helpEmailSubject,
    required this.privacyPolicyUrl,
    required this.termsOfServiceUrl,
    required this.playStorePackageName,
    required this.appStoreId,
  });

  factory SupportConfig.fromMap(Map<String, dynamic> data) => SupportConfig(
        helpEmail: (data['helpEmail'] as String?) ?? defaults.helpEmail,
        helpEmailSubject:
            (data['helpEmailSubject'] as String?) ?? defaults.helpEmailSubject,
        privacyPolicyUrl:
            (data['privacyPolicyUrl'] as String?) ?? defaults.privacyPolicyUrl,
        termsOfServiceUrl: (data['termsOfServiceUrl'] as String?) ??
            defaults.termsOfServiceUrl,
        playStorePackageName: (data['playStorePackageName'] as String?) ??
            defaults.playStorePackageName,
        appStoreId: (data['appStoreId'] as String?) ?? defaults.appStoreId,
      );

  Map<String, dynamic> toMap() => {
        'helpEmail': helpEmail,
        'helpEmailSubject': helpEmailSubject,
        'privacyPolicyUrl': privacyPolicyUrl,
        'termsOfServiceUrl': termsOfServiceUrl,
        'playStorePackageName': playStorePackageName,
        'appStoreId': appStoreId,
      };

  static const SupportConfig defaults = SupportConfig(
    helpEmail: 'support@mentorminds.app',
    helpEmailSubject: 'MentorMinds — Help request',
    privacyPolicyUrl: 'https://mentorminds.app/privacy',
    termsOfServiceUrl: 'https://mentorminds.app/terms',
    playStorePackageName: 'com.mentorminds.mentor_minds',
    appStoreId: '',
  );
}
