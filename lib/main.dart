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
      title: '小闲围棋',
      theme: const CupertinoThemeData(
        primaryColor: Color(0xFFB87A3C),
        brightness: Brightness.light,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontSize: 17,
          ),
          actionTextStyle: TextStyle(
            fontSize: 17,
            color: Color(0xFF007AFF),
          ),
          tabLabelTextStyle: TextStyle(
            fontSize: 10,
            letterSpacing: -0.1,
            color: Color(0xFFAF9C86),
          ),
          navTitleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
          navLargeTitleTextStyle: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.label,
          ),
          navActionTextStyle: TextStyle(
            fontSize: 17,
            color: Color(0xFF007AFF),
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
