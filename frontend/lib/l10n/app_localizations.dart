import 'package:flutter/widgets.dart';
import 'app_en.dart';
import 'app_ar.dart';
import '../providers/app_settings.dart';

/// Simple key-based localisation.
/// Usage: AppLocalizations.of(context).t('key')
class AppLocalizations {
  final Map<String, String> _strings;

  AppLocalizations._(this._strings);

  /// Translates [key]. Falls back to the English string, then to [key] itself.
  String t(String key) => _strings[key] ?? appStringsEn[key] ?? key;

  /// Access from any BuildContext.
  static AppLocalizations of(BuildContext context) {
    final lang = AppSettings.instance.locale.languageCode;
    final strings = lang == 'ar' ? appStringsAr : appStringsEn;
    return AppLocalizations._(strings);
  }
}
