import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Button that prevents double-taps by instantly disabling itself
/// until the async callback completes.
class DebouncedButton extends StatefulWidget {
  final FutureOr<void> Function()? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isOutlined;
  final double? width;
  final double height;
  final String? semanticLabel;

  const DebouncedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.backgroundColor,
    this.foregroundColor,
    this.isOutlined = false,
    this.width,
    this.height = 48.0,
    this.semanticLabel,
  });

  @override
  State<DebouncedButton> createState() => _DebouncedButtonState();
}

class _DebouncedButtonState extends State<DebouncedButton> {
  bool _isLoading = false;

  Future<void> _handlePress() async {
    if (_isLoading || widget.onPressed == null) return;

    setState(() => _isLoading = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveChild = _isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          )
        : widget.child;

    final childWidget = Semantics(
      label: widget.semanticLabel,
      button: true,
      enabled: !_isLoading && widget.onPressed != null,
      child: effectiveChild,
    );

    final VoidCallback? callback = widget.onPressed == null || _isLoading ? null : _handlePress;

    Widget button;
    if (widget.isOutlined) {
      button = OutlinedButton(
        style: widget.style ??
            OutlinedButton.styleFrom(
              foregroundColor: widget.foregroundColor ?? AppColors.primary,
              minimumSize: Size(widget.width ?? 88, widget.height),
            ),
        onPressed: callback,
        child: childWidget,
      );
    } else {
      button = ElevatedButton(
        style: widget.style ??
            ElevatedButton.styleFrom(
              backgroundColor: widget.backgroundColor ?? AppColors.primary,
              foregroundColor: widget.foregroundColor ?? Colors.white,
              minimumSize: Size(widget.width ?? 88, widget.height),
            ),
        onPressed: callback,
        child: childWidget,
      );
    }

    if (widget.width != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: button,
      );
    }

    return button;
  }
}
