import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// A message banner that drops in from the top of the app when a chat message
/// arrives while the user is on another screen: who sent it, what they said,
/// and a tap opens the chat. Swipe it up to dismiss; it leaves by itself.
///
/// Only one banner is on screen at a time; a newer message replaces it.
class ChatBanner {
  static OverlayEntry? _entry;
  static GlobalKey<_ChatBannerViewState>? _key;

  static void show({
    required String title,
    required String subtitle,
    required String body,
    String? imageUrl,
    required VoidCallback onTap,
  }) {
    final OverlayState? overlay = Get.key.currentState?.overlay;
    if (overlay == null) return;
    HapticFeedback.mediumImpact();

    // Same sender again: update the banner in place instead of re-animating.
    final _ChatBannerViewState? current = _key?.currentState;
    if (current != null && current.mounted && current.widget.title == title) {
      current.replace(body);
      return;
    }

    dismiss(animated: false);
    final GlobalKey<_ChatBannerViewState> key = GlobalKey<_ChatBannerViewState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _ChatBannerView(
      key: key,
      title: title,
      subtitle: subtitle,
      body: body,
      imageUrl: imageUrl,
      onTap: () {
        dismiss();
        onTap();
      },
      onGone: () {
        if (identical(_entry, entry)) {
          _entry = null;
          _key = null;
        }
        if (entry.mounted) entry.remove();
      },
    ));
    _entry = entry;
    _key = key;
    overlay.insert(entry);
  }

  /// Swaps the text of the banner on screen for [title] (same message,
  /// better text), without counting it as a new message.
  static void updateBody(String title, String body) {
    final _ChatBannerViewState? current = _key?.currentState;
    if (current != null && current.mounted && current.widget.title == title && body.isNotEmpty) {
      current.replace(body, countAsNew: false);
    }
  }

  static void dismiss({bool animated = true}) {
    final _ChatBannerViewState? state = _key?.currentState;
    if (animated && state != null && state.mounted) {
      state.close();
      return;
    }
    final OverlayEntry? entry = _entry;
    _entry = null;
    _key = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _ChatBannerView extends StatefulWidget {
  final String title;
  final String subtitle;
  final String body;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback onGone;

  const _ChatBannerView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.imageUrl,
    required this.onTap,
    required this.onGone,
  });

  @override
  State<_ChatBannerView> createState() => _ChatBannerViewState();
}

class _ChatBannerViewState extends State<_ChatBannerView> with SingleTickerProviderStateMixin {
  static const Duration _stay = Duration(milliseconds: 4800);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  Timer? _timer;
  double _drag = 0;
  late String _body = widget.body;
  int _count = 1;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(_stay, close);
  }

  void replace(String body, {bool countAsNew = true}) {
    _timer?.cancel();
    setState(() {
      _body = body;
      if (countAsNew) _count++;
    });
    _timer = Timer(_stay, close);
  }

  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted) await _controller.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _initials {
    final List<String> parts = widget.title.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color brand = theme.primaryColor;
    final double top = MediaQuery.of(context).padding.top + 8;
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final Animation<double> curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: curve,
        builder: (context, child) => Opacity(
          opacity: curve.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, reduceMotion ? 0 : (-90 * (1 - curve.value)) + _drag),
            child: child,
          ),
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(-120.0, 12.0)),
          onVerticalDragEnd: (d) {
            if (_drag < -28 || (d.primaryVelocity ?? 0) < -300) {
              close();
            } else {
              setState(() => _drag = 0);
            }
          },
          child: Semantics(
            liveRegion: true,
            label: '${widget.title}, ${widget.subtitle}: $_body',
            button: true,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: brand),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: (widget.imageUrl ?? '').isNotEmpty
                          ? Image.network(
                              widget.imageUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _InitialsText(_initials),
                            )
                          : _InitialsText(_initials),
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF1C1C1E), width: 2),
                        ),
                        child: Icon(Icons.chat_bubble_rounded, size: 10, color: brand),
                      ),
                    ),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${widget.subtitle}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                        ),
                        if (_count > 1) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(10)),
                            child: Text('$_count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _body,
                          key: ValueKey<String>(_body),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88), fontSize: 14, height: 1.3),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'reply'.tr,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialsText extends StatelessWidget {
  final String text;
  const _InitialsText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16));
  }
}
