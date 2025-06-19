import 'package:flutter/material.dart';

class LoadingIndicator extends StatefulWidget {
  final String? message;
  final Color primaryColor;
  final Color backgroundColor;
  final double size;
  final IconData? icon;

  const LoadingIndicator({
    super.key, 
    this.message,
    this.primaryColor = const Color(0xFF673AB7), // Deep Purple
    this.backgroundColor = Colors.white,
    this.size = 100,
    this.icon,
  });

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Setup pulsating animation
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    _pulseController.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated loading container
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.backgroundColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(widget.size / 5),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.2),
                blurRadius: widget.size / 5,
                spreadRadius: 5,
              )
            ]
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer spinning circle
                SizedBox(
                  width: widget.size * 0.8,
                  height: widget.size * 0.8,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.primaryColor.withOpacity(0.7)
                    ),
                    strokeWidth: 4,
                  ),
                ),
                // Inner pulsating circle
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: widget.size * 0.6 * _pulseAnimation.value,
                      height: widget.size * 0.6 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        color: widget.primaryColor.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                // App icon
                Icon(
                  widget.icon ?? Icons.queue,
                  color: widget.backgroundColor,
                  size: widget.size * 0.3,
                ),
              ],
            ),
          ),
        ),
        // Display message if provided
        if (widget.message != null) ...[
          SizedBox(height: widget.size * 0.3),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.6, end: 1.0),
            duration: Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Text(
              widget.message!,
              style: TextStyle(
                color: widget.primaryColor.withOpacity(0.9),
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
} 