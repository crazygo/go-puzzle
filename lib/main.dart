import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'screens/capture_game_screen.dart';
import 'screens/main_screen.dart';
import 'services/app_log_store.dart';
import 'theme/app_theme.dart';

const List<String> _kWebFontFamilyFallback = [
  'system-ui',
  '-apple-system',
  'BlinkMacSystemFont',
  'SF Pro Text',
  'PingFang SC',
  'Hiragino Sans GB',
  'Segoe UI',
  'Microsoft YaHei',
  'Noto Sans CJK SC',
  'Source Han Sans SC',
  'WenQuanYi Micro Hei',
  'sans-serif',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogStore.instance.restore();
  // On iOS, orientation is controlled by the app's Info.plist:
  // iPhone-only builds use portrait only (UISupportedInterfaceOrientations).
  // Calling setPreferredOrientations on iOS overrides the plist, so skip it there.
  // On other platforms (Android, desktop), lock to portrait explicitly.
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.iOS) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  runApp(const GoPuzzleApp());
}

class GoPuzzleApp extends StatelessWidget {
  const GoPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final showThreeBoardDebug =
        Uri.base.queryParameters['threeBoardDebug'] == '1';

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider.value(value: AppLogStore.instance),
      ],
      child: Selector<SettingsProvider, AppVisualTheme>(
        selector: (_, settings) => settings.appTheme,
        builder: (context, appTheme, _) {
          final palette = appTheme.palette;
          const fontFamilyFallback = kIsWeb ? _kWebFontFamilyFallback : null;
          TextStyle appTextStyle({
            double? fontSize,
            FontWeight? fontWeight,
            Color? color,
          }) {
            return TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              fontFamilyFallback: fontFamilyFallback,
            );
          }

          return CupertinoApp(
            title: 'Baduk Puzzle',
            theme: CupertinoThemeData(
              primaryColor: palette.primary,
              brightness:
                  appTheme == AppVisualTheme.classic ? null : Brightness.light,
              textTheme: CupertinoTextThemeData(
                textStyle: appTextStyle(
                  fontSize: 17,
                ),
                actionTextStyle: appTextStyle(
                  fontSize: 17,
                  color: const Color(0xFF007AFF),
                ),
                tabLabelTextStyle: appTextStyle(
                  fontSize: 10,
                  color: palette.tabInactive,
                ),
                navTitleTextStyle: appTextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
                navLargeTitleTextStyle: appTextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label,
                ),
                navActionTextStyle: appTextStyle(
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
