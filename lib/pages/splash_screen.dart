import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({Key? key, required this.nextScreen}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class Particle {
  late Offset position;
  late double radius;
  late Color color;
  late double speed;
  late double theta;

  Particle(Size screenSize) {
    final random = math.Random();
    position = Offset(
      random.nextDouble() * screenSize.width,
      random.nextDouble() * screenSize.height,
    );
    radius = random.nextDouble() * 4 + 1;
    color = Colors.white.withOpacity(random.nextDouble() * 0.7);
    speed = random.nextDouble() * 2;
    theta = random.nextDouble() * math.pi * 2;
  }

  void update() {
    final dx = speed * math.cos(theta);
    final dy = speed * math.sin(theta);
    position = Offset(position.dx + dx, position.dy + dy);
  }
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  final List<Particle> particles = [];
  Size screenSize = Size.zero;
  Timer? _particleTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 0.8, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();

    Timer(Duration(milliseconds: 2800), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: Duration(milliseconds: 800),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      screenSize = MediaQuery.of(context).size;
      _initializeParticles();
      _startParticleAnimation();
    });
  }

  void _initializeParticles() {
    particles.clear();
    for (var i = 0; i < 50; i++) {
      particles.add(Particle(screenSize));
    }
  }

  void _startParticleAnimation() {
    _particleTimer = Timer.periodic(Duration(milliseconds: 30), (timer) {
      if (mounted) {
        setState(() {
          for (var particle in particles) {
            particle.update();

            // Reset particles that go off screen
            if (particle.position.dx < 0 ||
                particle.position.dx > screenSize.width ||
                particle.position.dy < 0 ||
                particle.position.dy > screenSize.height) {
              particle.position = Offset(
                math.Random().nextDouble() * screenSize.width,
                math.Random().nextDouble() * screenSize.height,
              );
              particle.theta = math.Random().nextDouble() * math.pi * 2;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _particleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade900,
              Colors.deepPurple.shade700,
              Colors.deepPurple.shade500,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Particles
            CustomPaint(
              painter: ParticlePainter(particles: particles),
              child: Container(),
            ),

            // Content
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: ShaderMask(
                                  shaderCallback:
                                      (bounds) => LinearGradient(
                                        colors: [
                                          Colors.deepPurple.shade800,
                                          Colors.deepPurple.shade400,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                  child: Icon(
                                    Icons.queue,
                                    size: 90,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 30),
                            ShaderMask(
                              shaderCallback:
                                  (bounds) => LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.9),
                                      Colors.white.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                              child: Text(
                                'Virtual Queue',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 10,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            AnimatedOpacity(
                              opacity: _controller.value > 0.6 ? 1.0 : 0.0,
                              duration: Duration(milliseconds: 500),
                              child: Text(
                                'Manage Your Queues Effortlessly',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            SizedBox(height: 80),
                            AnimatedOpacity(
                              opacity: _controller.value > 0.7 ? 1.0 : 0.0,
                              duration: Duration(milliseconds: 500),
                              child: _buildLoadingIndicator(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        children: [
          // Background circle
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          // Animated progress indicator
          Positioned.fill(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
          // Center dot
          Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()..color = particle.color;
      canvas.drawCircle(particle.position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}
