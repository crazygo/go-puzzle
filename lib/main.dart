import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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

class GoPuzzleApp extends StatelessWidget {
  const GoPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '围棋谜题',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
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
      // Register the global Cupertino delegates explicitly. On WebKit, the
      // default CupertinoApp localization path reproduces a white overlay over
      // CupertinoTabBar for zh_CN, while the explicit global delegates do not.
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
