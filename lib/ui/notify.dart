import 'package:flutter/material.dart';

void ok(BuildContext context, String msg) => smartNotify(context, msg);
void err(BuildContext context, String msg) =>
    smartNotify(context, msg, icon: Icons.error_outline);

void smartNotify(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_outline,
  Color? bg,
  Color? fg,
}) {
  final theme = Theme.of(context);
  final color = theme.colorScheme;
  final bgc = bg ?? color.surface;
  final fgc = fg ?? color.onSurface;

  final overlay = Overlay.of(context);
  if (overlay == null) return;

  final entry = OverlayEntry(
    builder: (_) => _ToastWidget(
      message: message,
      icon: icon,
      bg: bgc,
      fg: fgc,
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 2), () {
    try {
      entry.remove();
    } catch (_) {}
  });
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color bg;
  final Color fg;
  const _ToastWidget({
    super.key,
    required this.message,
    required this.icon,
    required this.bg,
    required this.fg,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
        ..forward();
  late final Animation<double> _slide =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(_slide),
        child: FadeTransition(
          opacity: _slide,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: ShapeDecoration(
                    color: widget.bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: widget.fg),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: widget.fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.close, size: 18, color: widget.fg.withOpacity(.7)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
