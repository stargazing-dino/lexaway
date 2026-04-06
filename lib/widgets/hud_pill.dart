import 'package:flutter/material.dart';

/// Rounded dark pill used for HUD elements in the streak bar.
class HudPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const HudPill({super.key, required this.child, this.onTap, this.padding});

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: pill);
    }
    return pill;
  }
}
