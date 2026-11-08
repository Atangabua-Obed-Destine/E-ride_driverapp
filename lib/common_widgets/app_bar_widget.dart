import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/images.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final Function()? onBackPressed;
  final Function()? onTap;
  final bool regularAppbar;
  const AppBarWidget({super.key, required this.title, this.showBackButton = true, this.onBackPressed, this.onTap,  this.regularAppbar = false});

  /// Where screens float their pill tab selector over this app bar: just
  /// under the title row, whatever the status bar height. (It used to be a
  /// share of the screen height, which put the pills on the title on phones
  /// with a tall status bar or a large display size.)
  static double overlayTop(BuildContext context) => MediaQuery.paddingOf(context).top + 52;

  @override
  Widget build(BuildContext context) {
    final double minHeight = MediaQuery.paddingOf(context).top + kToolbarHeight + 6;
    final double designHeight = regularAppbar ? 100 : GetPlatform.isAndroid ? 120 : 150;
    return Container(
      height: designHeight > minHeight ? designHeight : minHeight,
      color: Theme.of(context).cardColor,
      child: AppBar(
        title: Text(title, style: textSemiBold.copyWith(
          fontSize: Dimensions.fontSizeExtraLarge,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        )),
        centerTitle: true,
        leading: showBackButton ? IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Theme.of(context).textTheme.bodyMedium?.color,
          onPressed: () => onBackPressed != null ? onBackPressed!() : Navigator.canPop(context) ? Navigator.pop(context) :  Get.offAll(() => const DashboardScreen()),
        ) :
        SizedBox(
          width: Dimensions.iconSizeMedium,
          child: InkWell(
            highlightColor: Colors.transparent,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
              child: Image.asset(
                Images.menuIcon,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                width: Dimensions.iconSizeMedium,
              ),
            ),
          ),
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
      ),
    );
  }

  @override
  Size get preferredSize =>  Size(Dimensions.webMaxWidth, GetPlatform.isAndroid? Dimensions.androidAppBarHeight : Dimensions.appBarHeight);
}