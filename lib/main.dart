import 'package:flutter/material.dart';
import 'app_prefs.dart';
import 'home_page.dart';
import 'l10n.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.I.load();
  await L10n.I.load();
  runApp(const VoiceleafApp());
}

class VoiceleafApp extends StatelessWidget {
  const VoiceleafApp({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kPurple, brightness: b),
        appBarTheme: const AppBarTheme(
            backgroundColor: kPurple, foregroundColor: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppPrefs.I, L10n.I]),
      builder: (_, __) => MaterialApp(
        key: ValueKey('app-${L10n.I.version}'),
        title: 'Voiceleaf',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: AppPrefs.I.flag('dark') ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => Directionality(
          textDirection: L10n.I.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HomePage(),
      ),
    );
  }
}
