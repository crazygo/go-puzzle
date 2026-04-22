import 'package:flutter/cupertino.dart';
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

class GoPuzzleApp extends StatelessWidget {
  const GoPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: '围棋谜题',
      theme: CupertinoThemeData(
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
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
    );
  }
}
