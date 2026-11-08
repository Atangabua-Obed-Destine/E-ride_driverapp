import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// "How do you want to call?" for calls between a rider and a driver: a
/// normal phone call (recommended) or WhatsApp. Same file in both apps.
///
/// WhatsApp has no public link that starts a call, so the WhatsApp option
/// opens the chat with that number, where the call button is one tap away.
/// The option says so, and is greyed out when WhatsApp is not installed.
class CallOptionsSheet {
  static const Color _whatsAppGreen = Color(0xFF25D366);

  static Future<void> show({required String? phone, String? name}) async {
    final String number = (phone ?? '').trim();
    if (number.isEmpty) return;
    HapticFeedback.selectionClick();

    final String digits = _digits(number);
    final Uri whatsApp = Uri.parse('whatsapp://send?phone=$digits');
    bool hasWhatsApp = false;
    try {
      hasWhatsApp = digits.isNotEmpty && await canLaunchUrl(whatsApp);
    } catch (_) {}

    await Get.bottomSheet(
      _CallOptionsView(
        name: (name ?? '').trim(),
        number: number,
        hasWhatsApp: hasWhatsApp,
        onPhone: () {
          Get.back();
          launchUrl(Uri.parse('tel:$number'));
        },
        onWhatsApp: () {
          Get.back();
          launchUrl(whatsApp, mode: LaunchMode.externalApplication);
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  /// International number without "+" or spaces, as WhatsApp expects.
  static String _digits(String number) {
    String d = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('00')) d = d.substring(2);
    return d;
  }
}

class _CallOptionsView extends StatelessWidget {
  final String name;
  final String number;
  final bool hasWhatsApp;
  final VoidCallback onPhone;
  final VoidCallback onWhatsApp;

  const _CallOptionsView({
    required this.name,
    required this.number,
    required this.hasWhatsApp,
    required this.onPhone,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color surface = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final Color text = dark ? Colors.white : const Color(0xFF1C1C1E);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: theme.hintColor.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name.isNotEmpty ? '${'call'.tr} $name' : 'how_do_you_want_to_call'.tr,
            style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(number, style: TextStyle(color: theme.hintColor, fontSize: 13)),
          const SizedBox(height: 16),

          _CallOption(
            icon: Icons.call_rounded,
            iconColor: Colors.white,
            iconBackground: theme.primaryColor,
            title: 'phone_call'.tr,
            badge: 'recommended'.tr,
            subtitle: 'phone_call_hint'.tr,
            highlighted: true,
            onTap: onPhone,
          ),
          const SizedBox(height: 10),
          _CallOption(
            icon: Icons.phone_in_talk_rounded,
            iconColor: Colors.white,
            iconBackground: CallOptionsSheet._whatsAppGreen,
            title: 'whatsapp_call'.tr,
            subtitle: hasWhatsApp ? 'whatsapp_call_hint'.tr : 'whatsapp_not_installed'.tr,
            enabled: hasWhatsApp,
            onTap: onWhatsApp,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Get.back(),
              child: Text('cancel'.tr, style: TextStyle(color: theme.hintColor, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CallOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String? badge;
  final bool highlighted;
  final bool enabled;
  final VoidCallback onTap;

  const _CallOption({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.highlighted = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color brand = theme.primaryColor;
    final Color text = dark ? Colors.white : const Color(0xFF1C1C1E);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: highlighted ? brand.withValues(alpha: dark ? 0.16 : 0.06) : (dark ? const Color(0xFF2C2C2E) : const Color(0xFFF4F4F6)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: highlighted ? brand.withValues(alpha: 0.55) : Colors.transparent, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                    Text(title, style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w700)),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF1DB954), borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: theme.hintColor, fontSize: 12.5, height: 1.3)),
                ]),
              ),
              if (enabled) Icon(Icons.chevron_right_rounded, color: theme.hintColor),
            ]),
          ),
        ),
      ),
    );
  }
}
