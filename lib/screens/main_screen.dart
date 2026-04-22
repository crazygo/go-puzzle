import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'capture_game_screen.dart';
import 'daily_puzzle_screen.dart';
import 'settings_screen.dart';
import 'skills_screen.dart';

/// Main screen with a custom bottom tab bar.
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

class _MainTabScaffold extends StatefulWidget {
  const _MainTabScaffold();

  @override
  State<_MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<_MainTabScaffold> {
  int _currentIndex = 0;

  static const _tabs = <_TabItem>[
    _TabItem(
      label: '吃5子',
      icon: CupertinoIcons.gamecontroller,
      activeIcon: CupertinoIcons.gamecontroller_fill,
      child: CaptureGameScreen(),
    ),
    _TabItem(
      label: '今日谜题',
      icon: CupertinoIcons.calendar,
      activeIcon: CupertinoIcons.calendar_today,
      child: DailyPuzzleScreen(),
    ),
    _TabItem(
      label: '技巧',
      icon: CupertinoIcons.book,
      activeIcon: CupertinoIcons.book_fill,
      child: SkillsScreen(),
    ),
    _TabItem(
      label: '设置',
      icon: CupertinoIcons.settings,
      activeIcon: CupertinoIcons.settings_solid,
      child: SettingsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: CupertinoColors.white),
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                CaptureGameScreen(),
                DailyPuzzleScreen(),
                SkillsScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          _BottomTabBar(
            currentIndex: _currentIndex,
            items: _tabs,
            onSelected: (index) {
              if (_currentIndex == index) {
                return;
              }
              setState(() => _currentIndex = index);
            },
          ),
        ],
      ),
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({
    required this.currentIndex,
    required this.items,
    required this.onSelected,
  });

  final int currentIndex;
  final List<_TabItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.white,
        border: Border(
          top: BorderSide(color: Color(0x4C3C3C43), width: 0),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _TabBarButton(
                  item: items[index],
                  selected: currentIndex == index,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabBarButton extends StatelessWidget {
  const _TabBarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _TabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? CupertinoColors.activeBlue
        : CupertinoColors.inactiveGray;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? item.activeIcon : item.icon,
            size: 27,
            color: color,
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10,
              height: 1.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget child;
}
