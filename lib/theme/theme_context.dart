import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'app_theme.dart';

extension AppThemeContext on BuildContext {
  AppThemePalette get appPalette {
    try {
      return watch<SettingsProvider>().appTheme.palette;
    } on ProviderNotFoundException {
      return AppThemePalette.agarwood;
    }
  }
}
