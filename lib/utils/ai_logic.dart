import 'dart:math';
import 'package:flutter/material.dart';
import '../models/vehicle.dart';

/// Utility class for AI-driven collision prediction and swarm intelligence logic.
// Updated: Optimized collision detection algorithms
class AILogic {
  /// Calculates the safe distance (Ds) between two vehicles.
  /// Simple heuristic: minimum distance required to avoid collision.
  static double calculateSafeDistance(Vehicle v1, Vehicle v2) {
    return (v1.position - v2.position).distance;
  }

  /// Calculates the probability of collision (Pconf) based on distance and velocities.
  /// Higher probability if vehicles are close and moving towards each other.
  static double calculateCollisionProbability(Vehicle v1, Vehicle v2) {
    double distance = calculateSafeDistance(v1, v2);
    double relativeSpeed = (v1.velocity - v2.velocity).distance;
    // Simple formula: probability increases as distance decreases
    double prob = max(0, 1 - (distance / 100.0));
    // Adjust based on relative speed
    prob *= (relativeSpeed / 5.0).clamp(0.5, 2.0);
    return prob.clamp(0.0, 1.0);
  }

  /// Determines the overall status based on minimum distance and probabilities.
  static String getStatus(List<Vehicle> vehicles) {
    if (vehicles.length < 2) return 'Safe';

    double minDistance = double.infinity;
    double maxProb = 0.0;

    for (int i = 0; i < vehicles.length; i++) {
      for (int j = i + 1; j < vehicles.length; j++) {
        double dist = calculateSafeDistance(vehicles[i], vehicles[j]);
        double prob = calculateCollisionProbability(vehicles[i], vehicles[j]);
        if (dist < minDistance) minDistance = dist;
        if (prob > maxProb) maxProb = prob;
      }
    }

    if (minDistance < 30 || maxProb > 0.8) return 'Conflict';
    if (minDistance < 50 || maxProb > 0.5) return 'Caution';
    return 'Safe';
  }

  /// Gets the color for AR overlay based on status.
  static Color getStatusColor(String status) {
    switch (status) {
      case 'Safe':
        return Colors.green.withOpacity(0.3);
      case 'Caution':
        return Colors.yellow.withOpacity(0.3);
      case 'Conflict':
        return Colors.red.withOpacity(0.3);
      default:
        return Colors.transparent;
    }
  }
}
