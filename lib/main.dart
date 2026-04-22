import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait orientation on mobile
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const GoPuzzleApp());
}

class _NoHintCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const _NoHintCupertinoLocalizations();

  @override
  String tabSemanticsLabel({required int tabIndex, required int tabCount}) {
    final label = super.tabSemanticsLabel(
      tabIndex: tabIndex,
      tabCount: tabCount,
    );
    if (kIsWeb) {
      debugPrint(
        '[tabSemanticsLabel] web tabIndex=$tabIndex tabCount=$tabCount => "$label"',
      );
    }
    return label;
  }
}

class _NoHintCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _NoHintCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return SynchronousFuture<CupertinoLocalizations>(
      const _NoHintCupertinoLocalizations(),
    );
  }

  @override
  bool shouldReload(_NoHintCupertinoLocalizationsDelegate old) => false;
}

class GoPuzzleApp extends StatelessWidget {
  const GoPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '围棋谜题',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        // Force opaque navigation/tab bar backgrounds to avoid generating
        // backdrop-filter on web (especially iOS WebKit/Chrome), which can
        // cause a white overlay and hidden bottom tab bar.
        barBackgroundColor: CupertinoColors.systemBackground,
        brightness: Brightness.light,
        textTheme: CupertinoTextThemeData(
          navLargeTitleTextStyle: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.label,
          ),
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        _NoHintCupertinoLocalizationsDelegate(),
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
    );
  }
}
