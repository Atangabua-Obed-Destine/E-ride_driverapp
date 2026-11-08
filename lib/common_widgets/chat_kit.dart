import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared pieces of the E-Ride trip chat (same file in both apps).

const Color _ink = Color(0xFF1C1C1E);

/// Dark chat header: back, the other person's photo, name, a live status line
/// ("typing…", or who they are), and a call button.
class ChatHeader extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? imageUrl;
  final bool typing;
  final bool online;
  final String? plate;
  final VoidCallback? onCall;
  final VoidCallback onBack;

  const ChatHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onBack,
    this.imageUrl,
    this.typing = false,
    this.online = true,
    this.plate,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.of(context).padding.top;
    final Color brand = Theme.of(context).primaryColor;

    return Container(
      padding: EdgeInsets.fromLTRB(4, top + 6, 12, 14),
      decoration: const BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Row(children: [
        IconButton(
          onPressed: onBack,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        ),
        ChatAvatar(name: name, imageUrl: imageUrl, size: 44, online: online, ringColor: _ink),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: typing
                  ? Row(key: const ValueKey('typing'), mainAxisSize: MainAxisSize.min, children: [
                      TypingDots(color: brand, size: 5),
                      const SizedBox(width: 6),
                      Text('typing'.tr, style: TextStyle(color: brand, fontSize: 13, fontWeight: FontWeight.w600)),
                    ])
                  : Row(key: const ValueKey('status'), mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                        ),
                      ),
                      if ((plate ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD60A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            plate!.toUpperCase(),
                            style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ]),
            ),
          ]),
        ),
        if (onCall != null)
          Material(
            color: Colors.white.withValues(alpha: 0.1),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onCall,
              child: const Padding(
                padding: EdgeInsets.all(11),
                child: Icon(Icons.call_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Round photo with initials as the fallback, and an optional green
/// "in an active trip" dot.
class ChatAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final bool online;
  final Color ringColor;

  const ChatAvatar({super.key, required this.name, this.imageUrl, this.size = 40, this.online = false, this.ringColor = Colors.white});

  String get _initials {
    final List<String> parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final Widget initials = Center(
      child: Text(_initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).primaryColor),
          child: (imageUrl ?? '').isNotEmpty && !(imageUrl!.endsWith('/'))
              ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials)
              : initials,
        ),
        if (online)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: const Color(0xFF34C759),
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Three dots that rise in turn, for "typing…".
class TypingDots extends StatefulWidget {
  final Color color;
  final double size;
  const TypingDots({super.key, required this.color, this.size = 7});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final double t = ((_c.value - i * 0.18) % 1.0);
          final double lift = still ? 0 : (t < 0.35 ? Curves.easeOut.transform(t / 0.35) : (t < 0.7 ? 1 - Curves.easeIn.transform((t - 0.35) / 0.35) : 0));
          return Container(
            margin: EdgeInsets.symmetric(horizontal: widget.size * 0.22),
            child: Transform.translate(
              offset: Offset(0, -lift * widget.size * 0.7),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.45 + 0.55 * lift),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// "The other person is typing" bubble shown at the bottom of the chat.
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 16, top: 6, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2C2C2E) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: TypingDots(color: Theme.of(context).hintColor),
      ),
    );
  }
}

/// One-tap replies above the message box.
class QuickReplies extends StatelessWidget {
  final List<String> replies;
  final ValueChanged<String> onTap;
  const QuickReplies({super.key, required this.replies, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color brand = Theme.of(context).primaryColor;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: replies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Material(
          color: dark ? const Color(0xFF2C2C2E) : Colors.white,
          shape: StadiumBorder(side: BorderSide(color: brand.withValues(alpha: 0.35))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => onTap(replies[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: Text(
                  replies[i],
                  style: TextStyle(color: dark ? Colors.white : _ink, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Delivery state under my own messages: sending, sent, seen, or not sent.
class MessageTicks extends StatelessWidget {
  final bool pending;
  final bool failed;
  final bool read;
  final Color color;

  const MessageTicks({super.key, required this.pending, required this.failed, required this.read, required this.color});

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Icon(Icons.error_outline_rounded, size: 14, color: Theme.of(context).colorScheme.error);
    }
    if (pending) {
      return Icon(Icons.schedule_rounded, size: 13, color: color.withValues(alpha: 0.7));
    }
    return Icon(
      read ? Icons.done_all_rounded : Icons.done_rounded,
      size: 15,
      color: read ? Theme.of(context).primaryColor : color.withValues(alpha: 0.7),
      semanticLabel: read ? 'seen'.tr : 'sent'.tr,
    );
  }
}

/// Shown instead of the message box once the trip is over.
class ChatClosedBar extends StatelessWidget {
  const ChatClosedBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).hintColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(Icons.lock_outline_rounded, size: 18, color: Theme.of(context).hintColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text('chat_closed_trip_ended'.tr, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
        ),
      ]),
    );
  }
}
