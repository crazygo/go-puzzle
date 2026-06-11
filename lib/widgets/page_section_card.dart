import 'package:flutter/cupertino.dart';

import '../theme/theme_context.dart';
import 'page_hero_banner.dart';

/// A themed section card used on all main-tab pages.
///
/// Applies [kPageSectionCardPadding] and [kPageSectionCardRadius] and adapts
/// the background, border, and shadow to the current app theme.
///
/// Wrap with a [Padding] using [kPageSectionCardMargin] at the call site when
/// the card needs horizontal page margins.
class PageSectionCard extends StatelessWidget {
  const PageSectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isClassic = context.isClassicAppTheme;
    final cardBackground =
        isClassic ? palette.setupPanelBackground : const Color(0xF7FFFDF9);

    return Container(
      width: double.infinity,
      padding: kPageSectionCardPadding,
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(kPageSectionCardRadius),
        border: isClassic ? null : Border.all(color: const Color(0x26D8C1A4)),
        boxShadow: isClassic
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: child,
    );
  }
}
