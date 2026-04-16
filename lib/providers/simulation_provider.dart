import 'dart:math';
import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../utils/ai_logic.dart';
import '../utils/audio_manager.dart';
import '../providers/environmental_provider.dart';

/// Provider for managing simulation state, including vehicles, metrics, and controls.
// Updated: Enhanced with data recording capabilities for CSV export
class SimulationProvider with ChangeNotifier {
  List<Vehicle> vehicles = [];
  bool isRunning = false;
  String status = 'Safe';
  double minDistance = 0.0;
  double collisionProbability = 0.0;
  List<double> distanceHistory = [];
  List<String> statusHistory = [];
  int warningCount = 0;
  int vehicleCount = 5;
  double initialSpeed = 2.0;
  double collisionThreshold = 0.5;
  final AudioManager _audioManager = AudioManager();
  String _previousStatus = 'Safe';

  // Recording variables
  bool isRecording = false;
  int frameCount = 0;
  List<Map<String, dynamic>> recordedData = [];

  /// Initializes the simulation with a set number of vehicles.
  void initializeSimulation(int vehicleCount, Size screenSize) {
    vehicles.clear();
    distanceHistory.clear();
    warningCount = 0;
    Random random = Random();
    for (int i = 0; i < vehicleCount; i++) {
      vehicles.add(Vehicle(
        position: Offset(
          random.nextDouble() * screenSize.width,
          random.nextDouble() * screenSize.height,
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 2,
          (random.nextDouble() - 0.5) * 2,
        ),
        color: Colors.primaries[i % Colors.primaries.length],
      ));
    }
    notifyListeners();
  }

  /// Updates the simulation for one frame.
  void updateSimulation(Size screenSize, [EnvironmentalProvider? envProvider]) {
    if (!isRunning) return;

    // Apply swarm forces and environmental effects
    for (var vehicle in vehicles) {
      Offset sep = vehicle.separate(vehicles);
      Offset ali = vehicle.align(vehicles);
      Offset coh = vehicle.cohesion(vehicles);

      // Weight the forces
      sep *= 1.5;
      ali *= 1.0;
      coh *= 1.0;

      // Apply environmental forces if provider is available
      if (envProvider != null) {
        Offset envForce = envProvider.calculateEnvironmentalForce(vehicle);
        vehicle.applyForce(envForce);
      }

      vehicle.applyForce(sep);
      vehicle.applyForce(ali);
      vehicle.applyForce(coh);

      vehicle.update();
      vehicle.wrapAround(screenSize);
    }

    // Update metrics
    updateMetrics();

    // Record data if recording
    if (isRecording) {
      recordFrameData();
    }

    notifyListeners();
  }

  /// Updates collision metrics.
  void updateMetrics() {
    if (vehicles.length < 2) return;

    double minDist = double.infinity;
    double maxProb = 0.0;

    for (int i = 0; i < vehicles.length; i++) {
      for (int j = i + 1; j < vehicles.length; j++) {
        double dist = AILogic.calculateSafeDistance(vehicles[i], vehicles[j]);
        double prob = AILogic.calculateCollisionProbability(vehicles[i], vehicles[j]);
        if (dist < minDist) minDist = dist;
        if (prob > maxProb) maxProb = prob;
      }
    }

    minDistance = minDist;
    collisionProbability = maxProb;
    _previousStatus = status;
    status = AILogic.getStatus(vehicles);
    distanceHistory.add(minDistance);
    statusHistory.add(status);
    if (distanceHistory.length > 100) distanceHistory.removeAt(0); // Keep last 100 points
    if (statusHistory.length > 100) statusHistory.removeAt(0);

    if (status == 'Caution' || status == 'Conflict') warningCount++;

    // Play audio alerts if status changed
    if (status != _previousStatus && (status == 'Caution' || status == 'Conflict')) {
      _audioManager.playAlertSound(status);
    }
  }

  /// Updates collision metrics with environmental factors.
  void updateMetricsWithEnvironment(EnvironmentalProvider envProvider) {
    updateMetrics(); // Call base update

    // Adjust collision probability based on weather
    double weatherMultiplier = 1.0;
    switch (envProvider.weatherCondition) {
      case 'Rain':
        weatherMultiplier = 1.2; // Higher risk in rain
        break;
      case 'Fog':
        weatherMultiplier = 1.5; // Much higher risk in fog
        break;
      case 'Windy':
        weatherMultiplier = 1.1; // Slightly higher risk in wind
        break;
      default:
        weatherMultiplier = 1.0;
    }

    // Adjust based on time of day
    if (envProvider.timeOfDay == 'Night') {
      weatherMultiplier *= 1.3; // Higher risk at night
    }

    collisionProbability *= weatherMultiplier;
    collisionProbability = collisionProbability.clamp(0.0, 1.0);
  }

  /// Toggles the simulation pause/resume.
  void toggleSimulation() {
    isRunning = !isRunning;
    notifyListeners();
  }

  /// Starts recording dataset.
  void startRecording() {
    isRecording = true;
    frameCount = 0;
    recordedData.clear();
    notifyListeners();
  }

  /// Stops recording dataset.
  void stopRecording() {
    isRecording = false;
    notifyListeners();
  }

  /// Resets the simulation.
  void resetSimulation(Size screenSize) {
    isRunning = false;
    isRecording = false;
    frameCount = 0;
    recordedData.clear();
    initializeSimulation(vehicles.length, screenSize);
  }

  /// Records data for the current frame.
  void recordFrameData() {
    frameCount++;
    String timestamp = DateTime.now().toIso8601String();

    for (int i = 0; i < vehicles.length; i++) {
      Vehicle v = vehicles[i];

      // Calculate static risk (min distance to other vehicles)
      double staticRisk = double.infinity;
      double temporalRisk = 0.0;

      for (int j = 0; j < vehicles.length; j++) {
        if (i != j) {
          double dist = AILogic.calculateSafeDistance(v, vehicles[j]);
          double prob = AILogic.calculateCollisionProbability(v, vehicles[j]);
          if (dist < staticRisk) staticRisk = dist;
          if (prob > temporalRisk) temporalRisk = prob;
        }
      }

      recordedData.add({
        'Frame': frameCount,
        'Timestamp': timestamp,
        'VehicleID': i,
        'X': v.position.dx,
        'Y': v.position.dy,
        'VX': v.velocity.dx,
        'VY': v.velocity.dy,
        'AX': v.acceleration.dx,
        'AY': v.acceleration.dy,
        'Status': status,
        'StaticRisk': staticRisk,
        'TemporalRisk': temporalRisk,
      });
    }
  }

  /// Gets summarized metrics for results page.
  Map<String, dynamic> getSummaryMetrics() {
    double avgDistance = distanceHistory.isNotEmpty
        ? distanceHistory.reduce((a, b) => a + b) / distanceHistory.length
        : 0.0;
    return {
      'averageDistance': avgDistance,
      'warningCount': warningCount,
      'maxCollisionProbability': collisionProbability,
      'distanceHistory': distanceHistory,
    };
  }
}
