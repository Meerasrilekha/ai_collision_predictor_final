import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:async';
import '../providers/simulation_provider.dart';
import '../providers/environmental_provider.dart';
import '../utils/ai_logic.dart';
import '../models/vehicle.dart';

/// AR Visualization page showing augmented reality style overlay for alerts.
/// Includes gesture controls and training scenarios.
class ARVisualizationPage extends StatefulWidget {
  const ARVisualizationPage({super.key});

  @override
  State<ARVisualizationPage> createState() => _ARVisualizationPageState();
}

class _ARVisualizationPageState extends State<ARVisualizationPage>
    with TickerProviderStateMixin {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _isTrainingMode = false;
  late AnimationController _particleController;
  late Animation<double> _particleAnimation;
  final List<Offset> _rainParticles = [];
  final List<Offset> _windParticles = [];
  Timer? _particleTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_particleController);
    _startParticleAnimation();
  }

  @override
  void dispose() {
    _particleController.dispose();
    _particleTimer?.cancel();
    super.dispose();
  }

  void _startParticleAnimation() {
    _particleTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _updateParticles();
        });
      }
    });
  }

  void _updateParticles() {
    final size = MediaQuery.of(context).size;

    // Rain particles
    if (_rainParticles.length < 50) {
      _rainParticles.add(Offset(_random.nextDouble() * size.width, -10));
    }
    for (int i = 0; i < _rainParticles.length; i++) {
      _rainParticles[i] = Offset(_rainParticles[i].dx, _rainParticles[i].dy + 8);
      if (_rainParticles[i].dy > size.height) {
        _rainParticles[i] = Offset(_random.nextDouble() * size.width, -10);
      }
    }

    // Wind particles
    if (_windParticles.length < 30) {
      _windParticles.add(Offset(-10, _random.nextDouble() * size.height));
    }
    for (int i = 0; i < _windParticles.length; i++) {
      _windParticles[i] = Offset(_windParticles[i].dx + 6, _windParticles[i].dy + _random.nextDouble() * 2 - 1);
      if (_windParticles[i].dx > size.width) {
        _windParticles[i] = Offset(-10, _random.nextDouble() * size.height);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Visualization'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(_isTrainingMode ? Icons.school : Icons.visibility),
            onPressed: () {
              setState(() {
                _isTrainingMode = !_isTrainingMode;
              });
            },
            tooltip: _isTrainingMode ? 'Exit Training Mode' : 'Enter Training Mode',
          ),
        ],
      ),
      body: Consumer2<SimulationProvider, EnvironmentalProvider>(
        builder: (context, simProvider, envProvider, child) {
          return GestureDetector(
            onScaleUpdate: (details) {
              setState(() {
                _scale = details.scale.clamp(0.5, 2.0);
                _offset += details.focalPointDelta;
              });
            },
            onDoubleTap: () {
              setState(() {
                _scale = 1.0;
                _offset = Offset.zero;
              });
            },
            onLongPress: () {
              // Add rotation gesture
              setState(() {
                // Reset to default for now
                _scale = 1.0;
                _offset = Offset.zero;
              });
            },
            child: Stack(
              children: [
                // Simulated camera view with zoom and pan
                Transform.scale(
                  scale: _scale,
                  child: Transform.translate(
                    offset: _offset,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: envProvider.timeOfDay == 'Night'
                              ? [Colors.indigo.shade900, Colors.black]
                              : [Colors.lightBlue.shade200, Colors.white],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Sky background
                          Positioned.fill(
                            child: CustomPaint(
                              painter: SkyPainter(envProvider.timeOfDay, envProvider.weatherCondition),
                            ),
                          ),
                          // Weather particles
                          if (envProvider.weatherCondition == 'Rain')
                            ..._rainParticles.map((particle) => Positioned(
                              left: particle.dx,
                              top: particle.dy,
                              child: Container(
                                width: 2,
                                height: 10,
                                color: Colors.blue.withOpacity(0.7),
                              ),
                            )),
                          if (envProvider.weatherCondition == 'Windy')
                            ..._windParticles.map((particle) => Positioned(
                              left: particle.dx,
                              top: particle.dy,
                              child: Icon(
                                Icons.grain,
                                size: 8,
                                color: Colors.grey.withOpacity(0.6),
                              ),
                            )),
                          // Ground/Surface
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 50,
                            child: Container(
                              color: envProvider.timeOfDay == 'Night'
                                  ? Colors.grey.shade800
                                  : Colors.green.shade300,
                            ),
                          ),
                          // Center text
                          Center(
                            child: Text(
                              _isTrainingMode
                                  ? 'Training Mode Active\nPinch to zoom, swipe to pan'
                                  : 'AR Camera View\nGesture controls enabled',
                              style: TextStyle(
                                color: envProvider.timeOfDay == 'Night'
                                    ? Colors.white
                                    : Colors.black,
                                fontSize: 20,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // AR Overlay with environmental effects
                Container(
                  color: AILogic.getStatusColor(simProvider.status).withOpacity(
                    envProvider.weatherCondition == 'Fog' ? 0.8 : 0.3,
                  ),
                ),
                // Environmental AR alerts
                if (envProvider.weatherCondition == 'Windy')
                  const Positioned(
                    top: 100,
                    left: 20,
                    right: 20,
                    child: Card(
                      color: Colors.orange,
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          '💨 Windy conditions affecting vehicle stability',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                // AR Information Display with enhanced metrics
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AR Status: ${simProvider.status}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Speed: ${simProvider.vehicles.isNotEmpty ? simProvider.vehicles[0].velocity.distance.toStringAsFixed(1) : '0.0'} m/s',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          'Distance: ${simProvider.minDistance.toStringAsFixed(1)} m',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          'Collision Risk: ${(simProvider.collisionProbability * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          'Weather: ${envProvider.weatherCondition}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Vehicles: ${simProvider.vehicles.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                // Training Mode Scenarios
                if (_isTrainingMode)
                  Positioned(
                    bottom: 200,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Training Scenarios',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () => _runTrainingScenario('close_encounter'),
                                child: const Text('Close Encounter'),
                              ),
                              ElevatedButton(
                                onPressed: () => _runTrainingScenario('swarm_behavior'),
                                child: const Text('Swarm Behavior'),
                              ),
                              ElevatedButton(
                                onPressed: () => _runTrainingScenario('emergency_brake'),
                                child: const Text('Emergency Brake'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                // AR Alerts with enhanced styling
                if (simProvider.status == 'Caution')
                  Positioned(
                    bottom: 100,
                    left: 20,
                    right: 20,
                    child: Card(
                      color: Colors.yellow,
                      elevation: 10,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '⚠️ Caution: Vehicles approaching safe distance\n${_isTrainingMode ? "Training: Maintain separation" : ""}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                if (simProvider.status == 'Conflict')
                  Positioned(
                    bottom: 100,
                    left: 20,
                    right: 20,
                    child: Card(
                      color: Colors.red,
                      elevation: 10,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '🚨 Conflict: High collision risk detected!\n${_isTrainingMode ? "Training: Emergency protocols activated" : ""}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                // Gesture hints
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      'Pinch: Zoom\nSwipe: Pan\nDouble-tap: Reset\nLong-press: Rotate',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _runTrainingScenario(String scenario) {
    final simProvider = Provider.of<SimulationProvider>(context, listen: false);
    final envProvider = Provider.of<EnvironmentalProvider>(context, listen: false);

    switch (scenario) {
      case 'close_encounter':
        // Create vehicles very close to each other
        simProvider.initializeSimulation(3, const Size(400, 600));
        simProvider.vehicles[0].position = const Offset(200, 300);
        simProvider.vehicles[1].position = const Offset(210, 310);
        simProvider.vehicles[2].position = const Offset(190, 290);
        break;
      case 'swarm_behavior':
        // Create many vehicles to test swarm coordination
        simProvider.initializeSimulation(8, const Size(400, 600));
        break;
      case 'emergency_brake':
        // Create high-speed vehicles approaching each other
        simProvider.initializeSimulation(2, const Size(400, 600));
        simProvider.vehicles[0].position = const Offset(100, 300);
        simProvider.vehicles[0].velocity = const Offset(3, 0);
        simProvider.vehicles[1].position = const Offset(300, 300);
        simProvider.vehicles[1].velocity = const Offset(-3, 0);
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Training scenario "$scenario" activated')),
    );
  }
}

/// Custom painter for sky background with time and weather effects
class SkyPainter extends CustomPainter {
  final String timeOfDay;
  final String weatherCondition;

  SkyPainter(this.timeOfDay, this.weatherCondition);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    if (timeOfDay == 'Night') {
      // Night sky with stars
      paint.color = Colors.indigo.shade900;
      canvas.drawRect(Offset.zero & size, paint);

      // Draw stars
      final Random random = Random(42); // Fixed seed for consistent stars
      paint.color = Colors.white.withOpacity(0.8);
      for (int i = 0; i < 50; i++) {
        final double x = random.nextDouble() * size.width;
        final double y = random.nextDouble() * size.height * 0.7; // Stars only in upper sky
        canvas.drawCircle(Offset(x, y), 1, paint);
      }

      // Moon
      paint.color = Colors.yellow.shade200;
      canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 30, paint);
    } else {
      // Day sky
      final Gradient gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.lightBlue.shade200,
          Colors.white,
        ],
      );
      paint.shader = gradient.createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, paint);

      // Sun
      paint.shader = null;
      paint.color = Colors.yellow.shade400;
      canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.15), 40, paint);

      // Clouds for clear weather
      if (weatherCondition == 'Clear') {
        paint.color = Colors.white.withOpacity(0.8);
        _drawCloud(canvas, Offset(size.width * 0.3, size.height * 0.1), paint);
        _drawCloud(canvas, Offset(size.width * 0.6, size.height * 0.05), paint);
      }
    }

    // Weather-specific overlays
    switch (weatherCondition) {
      case 'Fog':
        paint.color = Colors.grey.withOpacity(0.3);
        canvas.drawRect(Offset.zero & size, paint);
        break;
      case 'Rain':
        // Rain effect is handled by particles
        break;
      case 'Windy':
        // Wind effect is handled by particles
        break;
    }
  }

  void _drawCloud(Canvas canvas, Offset position, Paint paint) {
    canvas.drawCircle(position, 20, paint);
    canvas.drawCircle(position + const Offset(20, 0), 25, paint);
    canvas.drawCircle(position + const Offset(-20, 0), 25, paint);
    canvas.drawCircle(position + const Offset(10, -10), 20, paint);
    canvas.drawCircle(position + const Offset(-10, -10), 20, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
