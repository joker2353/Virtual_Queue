import 'package:flutter/material.dart';

class LoadingIndicator extends StatefulWidget {
  final Color? color;
  final String? message;
  final double size;
  final bool showMessage;
  final bool useBlurBackground;
  
  const LoadingIndicator({
    Key? key,
    this.color,
    this.message,
    this.size = 40.0,
    this.showMessage = true,
    this.useBlurBackground = false,
  }) : super(key: key);

  @override
  _LoadingIndicatorState createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> with TickerProviderStateMixin {
  late AnimationController _outerController;
  late AnimationController _innerController;

  @override
  void initState() {
    super.initState();
    _outerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _innerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _outerController.dispose();
    _innerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = widget.color ?? theme.colorScheme.primary;
    final defaultMessage = widget.message ?? 'Loading...';
    
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer circle animation
              RotationTransition(
                turns: _outerController,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: effectiveColor.withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                ),
              ),
              // Inner circle animation
              RotationTransition(
                turns: Tween(begin: 0.0, end: -1.0).animate(
                  CurvedAnimation(
                    parent: _innerController,
                    curve: Curves.easeInOutCirc,
                  ),
                ),
                child: Container(
                  width: widget.size * 0.7,
                  height: widget.size * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: effectiveColor,
                      width: 3,
                    ),
                  ),
                ),
              ),
              // Center dot
              Container(
                width: widget.size * 0.2,
                height: widget.size * 0.2,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        if (widget.showMessage) ...[
          SizedBox(height: 16),
          Text(
            defaultMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
    
    // Apply blur background if requested
    if (widget.useBlurBackground) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: EdgeInsets.all(24),
        child: content,
      );
    }
    
    return content;
  }
} 