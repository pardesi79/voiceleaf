import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n.dart';

/// App-wide settings, saved on the phone.
class AppPrefs extends ChangeNotifier {
  AppPrefs._();
  static final AppPrefs I = AppPrefs._();

  late SharedPreferences p;

  static const _defaults = <String, bool>{
    'dark': false,
    'readAuto': true,
    'screenReaderText': false,
    'continueBg': true,
    'processingSound': true,
    'completeSound': true,
    'pageVoice': true,
    'pageTurn': true,
  };

  Future<void> load() async {
    p = await SharedPreferences.getInstance();
  }

  bool flag(String k) => p.getBool(k) ?? _defaults[k] ?? false;
  Future<void> setFlag(String k, bool v) async {
    await p.setBool(k, v);
    notifyListeners();
  }

  double dbl(String k, double d) => p.getDouble(k) ?? d;
  int intv(String k, int d) => p.getInt(k) ?? d;
  String? str(String k) => p.getString(k);
  Future<void> setDbl(String k, double v) => p.setDouble(k, v);
  Future<void> setInt(String k, int v) => p.setInt(k, v);
  Future<void> setStr(String k, String v) async {
    await p.setString(k, v);
  }

  Future<void> remove(String k) => p.remove(k);

  /// 'auto', 'latin' or 'devanagari' - used for photos and scanned PDFs.
  String get ocr => str('ocr') ?? 'auto';
  Future<void> setOcr(String v) async {
    await p.setString('ocr', v);
    notifyListeners();
  }
}
