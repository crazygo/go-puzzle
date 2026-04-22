import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'capture_game_screen.dart';
import 'daily_puzzle_screen.dart';
import 'settings_screen.dart';
import 'skills_screen.dart';

/// Main screen with a Cupertino tab bar at the bottom.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const _MainTabScaffold(),
    );
  }
}

class _MainTabScaffold extends StatelessWidget {
  const _MainTabScaffold();

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gamecontroller),
            activeIcon: Icon(CupertinoIcons.gamecontroller_fill),
            label: '吃5子',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            activeIcon: Icon(CupertinoIcons.calendar_today),
            label: '今日谜题',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book),
            activeIcon: Icon(CupertinoIcons.book_fill),
            label: '技巧',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            activeIcon: Icon(CupertinoIcons.settings_solid),
            label: '设置',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoTabView(
              builder: (_) => const CaptureGameScreen(),
            );
          case 1:
            return CupertinoTabView(
              builder: (_) => const DailyPuzzleScreen(),
            );
          case 2:
            return CupertinoTabView(
              builder: (_) => const SkillsScreen(),
            );
          case 3:
            return CupertinoTabView(
              builder: (_) => const SettingsScreen(),
            );
          default:
            return CupertinoTabView(
              builder: (_) => const CaptureGameScreen(),
            );
        }
      },
    );
  }
}
