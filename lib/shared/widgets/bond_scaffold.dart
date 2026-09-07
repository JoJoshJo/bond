import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Consistent screen wrapper: app background, safe area, standard horizontal
/// padding, and an optional soft (transparent) app bar with a title.
class BondScaffold extends StatelessWidget {
  const BondScaffold({
    super.key,
    required this.child,
    this.title,
    this.showBack = false,
    this.actions,
    this.padded = true,
    this.scrollable = false,
  });

  final Widget child;
  final String? title;
  final bool showBack;
  final List<Widget>? actions;
  final bool padded;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final hasBar = title != null || showBack || actions != null;

    Widget body = child;
    if (padded) {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPad),
        child: body,
      );
    }
    if (scrollable) {
      body = SingleChildScrollView(child: body);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: hasBar
          ? AppBar(
              automaticallyImplyLeading: showBack,
              title: title != null ? Text(title!) : null,
              actions: actions,
            )
          : null,
      body: SafeArea(child: body),
    );
  }
}
