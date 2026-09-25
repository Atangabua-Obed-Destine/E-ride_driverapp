import 'package:flutter/material.dart';

class CustomThemeColors extends ThemeExtension<CustomThemeColors> {
  final Color upComingTagColor;
  final Color warningBackGroundColor;
  final Color infoColor;

  const CustomThemeColors({
    required this.upComingTagColor,
    required this.warningBackGroundColor,
    required this.infoColor,

  });

  // Predefined themes for light and dark modes
  factory CustomThemeColors.light() => const CustomThemeColors(
    upComingTagColor: Color(0xff5D40B2),
    warningBackGroundColor: Color(0xffFFF1F1),
      infoColor:  Color(0xFF0177CD)

  );

  factory CustomThemeColors.dark() => const CustomThemeColors(
      upComingTagColor: Color(0xff5D40B2),
      warningBackGroundColor: Color(0xffFFF1F1),
      infoColor:  Color(0xFF0177CD)

  );

  @override
  CustomThemeColors copyWith({
    Color? upComingTagColor,
    Color? warningBackGroundColor,
    Color? infoColor,

  }) {
    return CustomThemeColors(
      upComingTagColor: upComingTagColor ?? this.upComingTagColor,
      warningBackGroundColor: warningBackGroundColor ?? this.warningBackGroundColor,
        infoColor: infoColor ?? this.infoColor
    );
  }

  @override
  CustomThemeColors lerp(ThemeExtension<CustomThemeColors>? other, double t) {
    if (other is! CustomThemeColors) return this;

    return CustomThemeColors(
      upComingTagColor: Color.lerp(upComingTagColor, other.upComingTagColor, t)!,
      warningBackGroundColor: Color.lerp(warningBackGroundColor, other.warningBackGroundColor, t)!,
      infoColor: Color.lerp(infoColor, other.infoColor, t)!,
    );
  }
}