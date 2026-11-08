import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/custom_asset_image_widget.dart';
import 'package:ride_sharing_user_app/features/dashboard/domain/models/navigation_model.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

/// E-Ride driver bottom navigation.
///
/// A light floating dock with every tab labelled and a brand-red active
/// state, and in the middle the raised GO button: red with the brand mark
/// while offline, green while online. It is the one control a driver reaches
/// for most, so it lives on every tab. Tapping it runs the same go-online /
/// go-offline flow as the switch on the status card.
class ERideNavDock extends StatelessWidget {
  final List<NavigationModel> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool online;
  final VoidCallback onGoTap;

  const ERideNavDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.online,
    required this.onGoTap,
  });

  static const double height = 66;
  static const double _goSize = 60;
  static const double _goLift = 24;
  static const Color _onlineGreen = Color(0xFF1DB954);

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Duration duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 260);
    final Color accent = Theme.of(context).primaryColor;
    final Color goColor = online ? _onlineGreen : accent;
    final bool dark = Get.isDarkMode;
    final int half = items.length ~/ 2;

    Widget tab(int i) => Expanded(
          child: _DockItem(
            item: items[i],
            selected: i == currentIndex,
            duration: duration,
            onTap: () => onSelect(i),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimensions.paddingSizeDefault, 0, Dimensions.paddingSizeDefault, 12,
      ),
      child: SizedBox(
        height: height + _goLift,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0, right: 0, bottom: 0, height: height,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).hintColor.withValues(alpha: dark ? 0.25 : 0.14)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.5 : 0.14), blurRadius: 26, offset: const Offset(0, 10)),
                ],
              ),
              child: Row(children: [
                for (int i = 0; i < half; i++) tab(i),
                SizedBox(width: _goSize + 12, child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      style: textSemiBold.copyWith(fontSize: 10, color: goColor),
                      child: Text(online ? 'online'.tr : 'go'.tr),
                    ),
                  ),
                )),
                for (int i = half; i < items.length; i++) tab(i),
              ]),
            ),
          ),

          Positioned(
            top: 0, left: 0, right: 0,
            child: Center(child: _GoButton(color: goColor, online: online, size: _goSize, duration: duration, onTap: onGoTap)),
          ),
        ]),
      ),
    );
  }
}

/// The raised GO button: brand mark on red while offline, a steering-wheel
/// glyph on green while online, with a card-coloured ring so it reads as cut
/// out of the dock.
class _GoButton extends StatelessWidget {
  final Color color;
  final bool online;
  final double size;
  final Duration duration;
  final VoidCallback onTap;
  const _GoButton({required this.color, required this.online, required this.size, required this.duration, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: online ? 'online'.tr : 'go'.tr,
      child: Container(
        width: size + 10,
        height: size + 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).cardColor),
        padding: const EdgeInsets.all(5),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: AnimatedSwitcher(
                  duration: duration,
                  child: online
                      ? const Icon(Icons.directions_car_rounded, key: ValueKey('on'), color: Colors.white, size: 28)
                      : Image.asset(Images.brandMarkOnDark, key: const ValueKey('off'), height: 26, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final NavigationModel item;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  const _DockItem({
    required this.item,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).primaryColor;
    final Color idle = Theme.of(context).hintColor;

    return Semantics(
      button: true,
      selected: selected,
      label: item.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            width: selected ? 18 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
          ),
          AnimatedScale(
            scale: selected ? 1.0 : 0.92,
            duration: duration,
            curve: Curves.easeOutBack,
            child: CustomAssetImageWidget(
              selected ? item.activeIcon : item.inactiveIcon,
              width: 22,
              height: 22,
              color: selected ? accent : idle,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (selected ? textSemiBold : textMedium).copyWith(
              fontSize: 10,
              color: selected ? accent : idle,
            ),
          ),
        ]),
      ),
    );
  }
}
