import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final Color? color;
  final VoidCallback? onTap;
  final double? height;
  final double? borderRadius;
  final Widget? child;

  const PrimaryButton({
    Key? key,
    this.child,
    this.height,
    this.borderRadius,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: height ?? 45,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius ?? 8),
        ),
        child: Center(child: child),
      ),
    );
  }
}

