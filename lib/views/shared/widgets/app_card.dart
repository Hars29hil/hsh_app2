import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimens.dart';

/// Base surface for every card in the app: borderless, rounded, soft
/// shadow. Pass [gradient] for hero-style cards (balance, net due, ...).
/// Tappable cards animate with a subtle press-scale for premium feedback.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final bool elevated;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.cardPadding),
    this.onTap,
    this.color,
    this.gradient,
    this.radius = AppDimens.radiusLg,
    this.elevated = true,
    this.width,
    this.height,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.radius);
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          width: widget.width,
          height: widget.height,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.gradient == null ? (widget.color ?? AppColors.surface) : null,
            gradient: widget.gradient,
            borderRadius: borderRadius,
            boxShadow: widget.elevated
                ? (widget.gradient != null
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: _pressed ? 0.14 : 0.28),
                            blurRadius: _pressed ? 14 : 28,
                            offset: Offset(0, _pressed ? 4 : 12),
                          ),
                        ]
                      : AppColors.softShadow)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
