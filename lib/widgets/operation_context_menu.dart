import 'package:flutter/cupertino.dart';

/// Shared shell for the anchored operation menu used in gameplay screens.
class OperationContextMenuShell extends StatelessWidget {
  const OperationContextMenuShell({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground
            .resolveFrom(context)
            .withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: CupertinoColors.separator
              .resolveFrom(context)
              .withValues(alpha: 0.24),
          width: 0.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class OperationMenuDivider extends StatelessWidget {
  const OperationMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.6,
      margin: const EdgeInsets.only(left: 14),
      color: CupertinoColors.separator
          .resolveFrom(context)
          .withValues(alpha: 0.30),
    );
  }
}

class OperationMenuItem extends StatelessWidget {
  const OperationMenuItem({
    super.key,
    required this.text,
    this.subtitle,
    required this.enabled,
    required this.onPressed,
  });

  final String text;
  final String? subtitle;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final titleColor = enabled
        ? CupertinoColors.label.resolveFrom(context)
        : CupertinoColors.inactiveGray.resolveFrom(context);
    final subtitle = this.subtitle;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: enabled ? onPressed : null,
      child: SizedBox(
        height: subtitle == null ? 48 : 58,
        width: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: subtitle == null ? 16 : 15,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: CupertinoColors.inactiveGray.resolveFrom(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showAnchoredOperationMenu({
  required BuildContext context,
  required BuildContext buttonContext,
  required Widget menu,
  required double menuWidth,
  required double menuHeight,
}) {
  final buttonBox = buttonContext.findRenderObject() as RenderBox?;
  final overlayBox =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  if (buttonBox == null || overlayBox == null) {
    return Future.value();
  }

  final buttonTopLeft = buttonBox.localToGlobal(
    Offset.zero,
    ancestor: overlayBox,
  );
  final buttonRect = buttonTopLeft & buttonBox.size;
  const edgePadding = 12.0;
  final media = MediaQuery.of(context);
  final preferredTop = buttonRect.top - menuHeight - 8;
  final menuOpensBelow = preferredTop < media.padding.top + edgePadding;
  final menuAlignment =
      menuOpensBelow ? Alignment.topRight : Alignment.bottomRight;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '關閉操作選單',
    barrierColor: CupertinoColors.black.withValues(alpha: 0.02),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (menuContext, _, __) {
      final menuMedia = MediaQuery.of(menuContext);
      final maxLeft = menuMedia.size.width - menuWidth - edgePadding;
      final left = (buttonRect.right - menuWidth).clamp(edgePadding, maxLeft);
      var top = preferredTop;
      final minTop = menuMedia.padding.top + edgePadding;
      if (top < minTop) {
        top = buttonRect.bottom + 8;
      }

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: menu,
          ),
        ],
      );
    },
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          alignment: menuAlignment,
          child: child,
        ),
      );
    },
  );
}
