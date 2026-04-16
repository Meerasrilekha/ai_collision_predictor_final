import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/simulation_provider.dart';
import '../providers/environmental_provider.dart';
import '../utils/ai_logic.dart';
import '../utils/performance_monitor.dart';
import 'dart:async';

/// Simulation page visualizing flying cars with swarm intelligence.
/// Displays real-time metrics and AR-style overlay.
class SimulationPage extends StatefulWidget {
  const SimulationPage({super.key});

  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage>
    with TickerProviderStateMixin {
  late Timer _timer;
  late Size _screenSize;
  late AnimationController _hudController;
  late Animation<double> _hudAnimation;
  late PerformanceMonitor _performanceMonitor;
  double _fps = 0.0;
  double _cpuUsage = 0.0;

  @override
  void initState() {
    super.initState();
    _performanceMonitor = PerformanceMonitor();
    _performanceMonitor.onPerformanceUpdate = (fps, avgFrameTime, memoryUsage) {
      setState(() {
        _fps = fps;
        _cpuUsage = memoryUsage.toDouble(); // Simplified CPU estimation
      });
    };
    _performanceMonitor.startMonitoring();

    _hudController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _hudAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hudController, curve: Curves.easeInOut),
    );
    _hudController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenSize = MediaQuery.of(context).size;
      final provider = Provider.of<SimulationProvider>(context, listen: false);
      provider.initializeSimulation(provider.vehicleCount, _screenSize);
      _startSimulation();
    });
  }

  void _startSimulation() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final envProvider = Provider.of<EnvironmentalProvider>(context, listen: false);
      final simProvider = Provider.of<SimulationProvider>(context, listen: false);
      simProvider.updateSimulation(_screenSize, envProvider);
      // Update metrics with environmental factors
      simProvider.updateMetricsWithEnvironment(envProvider);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _hudController.dispose();
    _performanceMonitor.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulation'),
        backgroundColor: Colors.blue,
      ),
      body: Consumer2<SimulationProvider, EnvironmentalProvider>(
        builder: (context, simProvider, envProvider, child) {
          return Stack(
            children: [
              // Simulation Canvas with 3D effect
              CustomPaint(
                painter: SimulationPainter3D(simProvider.vehicles, envProvider),
                size: Size.infinite,
              ),
              // AR Overlay with environmental effects
              Container(
                color: AILogic.getStatusColor(simProvider.status).withOpacity(
                  envProvider.weatherCondition == 'Fog' ? 0.8 : 0.3,
                ),
              ),
              // Environmental Effects
              if (envProvider.weatherCondition == 'Rain')
                Container(
                  color: Colors.blue.withOpacity(0.1),
                  child: const Center(
                    child: Text(
                      '🌧️ Rainy Conditions',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                ),
              if (envProvider.weatherCondition == 'Fog')
                Container(
                  color: Colors.grey.withOpacity(0.5),
                  child: const Center(
                    child: Text(
                      '🌫️ Foggy Conditions',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                ),
              // Real-time HUD
              Positioned(
                top: 20,
                left: 20,
                child: AnimatedBuilder(
                  animation: _hudAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _hudAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: ${simProvider.status}',
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            Text(
                              'Speed: ${simProvider.vehicles.isNotEmpty ? simProvider.vehicles[0].velocity.distance.toStringAsFixed(1) : '0.0'} m/s',
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              'Distance: ${simProvider.minDistance.toStringAsFixed(1)} m',
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              'P(conf): ${(simProvider.collisionProbability * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Performance Monitor
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'FPS: ${_fps.toStringAsFixed(1)}\nCPU: ${_cpuUsage.toStringAsFixed(0)} KB',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              // Control Button
              Positioned(
                bottom: 20,
                right: 20,
                child: Row(
                  children: [
                    FloatingActionButton(
                      onPressed: () {
                        if (simProvider.isRecording) {
                          simProvider.stopRecording();
                        } else {
                          simProvider.startRecording();
                        }
                      },
                      backgroundColor: simProvider.isRecording ? Colors.red : Colors.green,
                      child: Icon(
                        simProvider.isRecording ? Icons.stop : Icons.videocam,
                      ),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      onPressed: () {
                        simProvider.toggleSimulation();
                      },
                      child: Icon(
                        simProvider.isRunning ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Custom painter for drawing vehicles on the canvas with 3D effect.
class SimulationPainter3D extends CustomPainter {
  final List vehicles;
  final EnvironmentalProvider environmentalProvider;

  SimulationPainter3D(this.vehicles, this.environmentalProvider);

  @override
  void paint(Canvas canvas, Size size) {
    // Apply environmental visibility
    double visibility = environmentalProvider.visibilityFactor;

    for (var vehicle in vehicles) {
      // 3D perspective effect based on height
      double scale = 1.0 + vehicle.height * 0.1;
      Offset drawPosition = vehicle.position;

      final paint = Paint()
        ..color = vehicle.color.withOpacity(visibility)
        ..style = PaintingStyle.fill;

      // Draw shadow for 3D effect
      canvas.drawCircle(
        drawPosition + const Offset(2, 2),
        10 * scale * 0.8,
        Paint()..color = Colors.black.withOpacity(0.3 * visibility),
      );

      // Draw vehicle
      canvas.drawCircle(drawPosition, 10 * scale, paint);

      // Draw velocity vector with 3D effect
      canvas.drawLine(
        drawPosition,
        drawPosition + vehicle.velocity * 10 * scale,
        Paint()
          ..color = Colors.white.withOpacity(visibility)
          ..strokeWidth = 2,
      );

      // Update height for pseudo-3D
      vehicle.height += (vehicle.velocity.distance * 0.01 - vehicle.height * 0.05);
      vehicle.height = vehicle.height.clamp(-1.0, 1.0);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
