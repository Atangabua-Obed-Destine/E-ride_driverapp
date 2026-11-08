import 'package:flutter/material.dart';

/// Red count badge pinned to the top-right corner of [child]. Hidden at zero;
/// pops in when the count changes. With [dot] it shows a plain dot instead.
class UnreadBadge extends StatelessWidget {
  final int count;
  final Widget child;
  final bool dot;
  final Offset offset;
  final Color? borderColor;

  const UnreadBadge({
    super.key,
    required this.count,
    required this.child,
    this.dot = false,
    this.offset = const Offset(-2, -2),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color brand = Theme.of(context).primaryColor;
    final Color ring = borderColor ?? Theme.of(context).cardColor;
    final String label = count > 99 ? '99+' : '$count';

    return Stack(clipBehavior: Clip.none, children: [
      child,
      Positioned(
        top: offset.dy,
        right: offset.dx,
        child: IgnorePointer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              child: child,
            ),
            child: count <= 0
                ? const SizedBox.shrink(key: ValueKey<int>(0))
                : Semantics(
                    key: ValueKey<String>(dot ? 'dot' : label),
                    label: '$count unread',
                    child: dot
                        ? Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(color: brand, shape: BoxShape.circle, border: Border.all(color: ring, width: 2)),
                          )
                        : Container(
                            constraints: const BoxConstraints(minWidth: 19),
                            height: 19,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: brand,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ring, width: 2),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.1),
                            ),
                          ),
                  ),
          ),
        ),
      ),
    ]);
  }
}

/// Inline unread count for list rows ("Messages  3 >").
class CountPill extends StatelessWidget {
  final int count;
  const CountPill({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: count <= 0 ? const SizedBox.shrink() : Container(
        key: ValueKey<int>(count),
        margin: const EdgeInsetsDirectional.only(end: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(12)),
        child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
