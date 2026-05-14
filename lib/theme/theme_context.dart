import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'app_theme.dart';

extension AppThemeContext on BuildContext {
  AppThemePalette get appPalette {
    try {
      final palette =
          select<SettingsProvider, AppThemePalette>((s) => s.appTheme.palette);
      return palette.resolve(this);
    } on ProviderNotFoundException {
      return AppThemePalette.agarwood.resolve(this);
    }
  }

  bool get isClassicAppTheme {
    try {
      return select<SettingsProvider, bool>(
          (s) => s.appTheme == AppVisualTheme.classic);
    } on ProviderNotFoundException {
      return false;
    }
  }
}
