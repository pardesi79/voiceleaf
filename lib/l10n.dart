import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'app_prefs.dart';

String tr(String s) => L10n.I.tr(s);

/// Translates a template such as 'Page {1}' and fills in the values.
String trf(String tpl, List<Object> vals) => L10n.I.trf(tpl, vals);

/// App display language. English is built in. Any other language is made
/// on the phone with Google ML Kit translation (model downloads once).
class L10n extends ChangeNotifier {
  L10n._();
  static final L10n I = L10n._();

  Map<String, String> _m = {};
  String code = 'en';
  int version = 0;
  static const _rtl = {'ar', 'he', 'fa', 'ur'};

  bool get isRtl => _rtl.contains(code);
  String tr(String s) => _m[s] ?? s;

  /// Same as [tr], but for text that carries numbers or names.
  /// The template keeps its placeholders, so it is translated once.
  String trf(String tpl, List<Object> vals) {
    var s = _m[tpl] ?? tpl;
    for (var i = 0; i < vals.length; i++) {
      s = s.replaceAll('{${i + 1}}', '${vals[i]}');
    }
    return s;
  }

  Future<void> load() async {
    final c = AppPrefs.I.str('uiLang') ?? 'en';
    if (c == 'en') return;
    final j = AppPrefs.I.str('ui_$c');
    if (j == null) return;
    try {
      _m = Map<String, String>.from(jsonDecode(j) as Map);
      code = c;
    } catch (_) {}
  }

  Future<void> setLanguage(TranslateLanguage lang, void Function(String) status) async {
    if (lang == TranslateLanguage.english) {
      _m = {};
      code = 'en';
      await AppPrefs.I.setStr('uiLang', 'en');
      version++;
      notifyListeners();
      return;
    }
    final mm = OnDeviceTranslatorModelManager();
    for (final l in [TranslateLanguage.english, lang]) {
      if (!await mm.isModelDownloaded(l.bcpCode)) {
        status('Downloading ${l.name} language files (one time)...');
        await mm.downloadModel(l.bcpCode, isWifiRequired: false);
      }
    }
    final src = (jsonDecode(await rootBundle.loadString('assets/ui_strings.json')) as List)
        .cast<String>();
    final t = OnDeviceTranslator(sourceLanguage: TranslateLanguage.english, targetLanguage: lang);
    final out = <String, String>{};
    try {
      for (var i = 0; i < src.length; i++) {
        if (i % 10 == 0) status('Translating app text ${i + 1} of ${src.length}');
        try {
          out[src[i]] = await t.translateText(src[i]);
        } catch (_) {}
      }
    } finally {
      await t.close();
    }
    _m = out;
    code = lang.bcpCode;
    await AppPrefs.I.setStr('ui_${lang.bcpCode}', jsonEncode(out));
    await AppPrefs.I.setStr('uiLang', lang.bcpCode);
    version++;
    notifyListeners();
  }
}
