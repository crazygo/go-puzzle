import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'app_theme.dart';

extension AppThemeContext on BuildContext {
  AppThemePalette get appPalette {
    try {
      return select<SettingsProvider, AppThemePalette>(
          (s) => s.appTheme.palette);
    } on ProviderNotFoundException {
      return AppThemePalette.agarwood;
    }
  }
}
