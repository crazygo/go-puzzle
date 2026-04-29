import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'screens/capture_game_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

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
    final showThreeBoardDebug =
        Uri.base.queryParameters['threeBoardDebug'] == '1';

    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: Selector<SettingsProvider, AppThemePalette>(
        selector: (_, settings) => settings.appTheme.palette,
        builder: (context, palette, _) {
          return CupertinoApp(
            title: '小闲围棋',
            theme: CupertinoThemeData(
              primaryColor: palette.primary,
              brightness: Brightness.light,
              textTheme: CupertinoTextThemeData(
                textStyle: const TextStyle(
                  fontSize: 17,
                ),
                actionTextStyle: const TextStyle(
                  fontSize: 17,
                  color: Color(0xFF007AFF),
                ),
                tabLabelTextStyle: TextStyle(
                  fontSize: 10,
                  color: palette.tabInactive,
                ),
                navTitleTextStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
                navLargeTitleTextStyle: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label,
                ),
                navActionTextStyle: TextStyle(
                  fontSize: 17,
                  color: palette.primary,
                ),
              ),
            ),
            home: showThreeBoardDebug
                ? const ThreeBoardDebugScreen()
                : const MainScreen(),
            debugShowCheckedModeBanner: false,
            // Register the global Cupertino delegates explicitly. On WebKit,
            // the default CupertinoApp localization path reproduces a white
            // overlay over CupertinoTabBar for zh_CN, while the explicit global
            // delegates do not.
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
          );
        },
      ),
    );
  }
}
