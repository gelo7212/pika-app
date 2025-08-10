import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routing/navigation_extensions.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final bool showBackButton;
  final String? backRoute;
  final Widget? leading;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onBackPressed,
    this.actions,
    this.showBackButton = true,
    this.backRoute,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Text(
        title,
        style: theme.textTheme.headlineSmall,
      ),
      leading: leading ??
          (showBackButton
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    size: 18,
                    color: theme.textPrimary,
                  ),
                  onPressed: onBackPressed ??
                      () {
                        if (backRoute != null) {
                          context.go(backRoute!);
                        } else {
                          context.safeGoBack();
                        }
                      },
                )
              : null),
      actions: actions,
      automaticallyImplyLeading: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Alternative simplified version for common use cases
class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? backRoute;

  const SimpleAppBar({
    super.key,
    required this.title,
    this.backRoute,
  });

  @override
  Widget build(BuildContext context) {
    return CustomAppBar(
      title: title,
      backRoute: backRoute,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
