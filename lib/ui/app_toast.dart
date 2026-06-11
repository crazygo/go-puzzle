import 'package:flutter/cupertino.dart';

void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => AppToastOverlay(
      message: message,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class AppToastOverlay extends StatefulWidget {
  const AppToastOverlay({
    super.key,
    required this.message,
    required this.onDone,
  });

  final String message;
  final VoidCallback onDone;

  @override
  State<AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<AppToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 1400), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 48,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _opacity,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xE6333333),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
