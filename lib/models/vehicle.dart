import 'package:flutter/material.dart';

/// Represents a flying vehicle in the simulation.
/// Each vehicle has position, velocity, and properties for swarm intelligence.
class Vehicle {
  Offset position;
  Offset velocity;
  Offset acceleration;
  double height; // For 3D visualizationt  effect
  final double maxSpeed;
  final double maxForce;
  final double safeDistance;
  final Color color;

  Vehicle({
    required this.position,
    required this.velocity,
    this.acceleration = Offset.zero,
    this.maxSpeed = 2.0,
    this.maxForce = 0.1,
    this.safeDistance = 50.0,
    this.color = Colors.blue,
    this.height = 0.0,
  });

  /// Updates the vehicle's position based on its velocity.
  void update() {
    velocity += acceleration;
    // Limit velocity to maxSpeed
    if (velocity.distance > maxSpeed) {
      velocity = velocity / velocity.distance * maxSpeed;
    }
    position += velocity;
    acceleration = Offset.zero; // Reset acceleration each frame
  }

  /// Applies a force to the vehicle, limiting it to maxForce.
  void applyForce(Offset force) {
    if (force.distance == 0.0) return; // Avoid division by zero
    Offset limitedForce = force * maxForce / force.distance;
    acceleration += limitedForce;
  }

  /// Calculates separation force from nearby vehicles to avoid collisions.
  Offset separate(List<Vehicle> vehicles) {
    Offset steer = Offset.zero;
    int count = 0;
    for (var other in vehicles) {
      double distance = (position - other.position).distance;
      if (distance > 0.0 && distance < safeDistance) {
        Offset diff = position - other.position;
        if (diff.distance > 0.0) {
          diff = diff / diff.distance; // Normalize
          diff = diff / distance; // Weight by distance
          steer += diff;
          count++;
        }
      }
    }
    if (count > 0) {
      steer = steer / count.toDouble();
      if (steer.distance > 0.0) {
        steer = steer / steer.distance * maxSpeed; // Normalize to maxSpeed
        steer -= velocity; // Steering force
      }
    }
    return steer;
  }

  /// Calculates alignment force to match velocity with nearby vehicles.
  Offset align(List<Vehicle> vehicles) {
    Offset sum = Offset.zero;
    int count = 0;
    for (var other in vehicles) {
      double distance = (position - other.position).distance;
      if (distance > 0.0 && distance < safeDistance * 2.0) {
        sum += other.velocity;
        count++;
      }
    }
    if (count > 0) {
      Offset avg = sum / count.toDouble();
      if (avg.distance > 0.0) {
        avg = avg / avg.distance * maxSpeed; // Normalize
        Offset steer = avg - velocity;
        return steer;
      }
    }
    return Offset.zero;
  }

  /// Calculates cohesion force to move towards the center of nearby vehicles.
  Offset cohesion(List<Vehicle> vehicles) {
    Offset sum = Offset.zero;
    int count = 0;
    for (var other in vehicles) {
      double distance = (position - other.position).distance;
      if (distance > 0.0 && distance < safeDistance * 2.0) {
        sum += other.position;
        count++;
      }
    }
    if (count > 0) {
      Offset avg = sum / count.toDouble();
      Offset desired = avg - position;
      if (desired.distance > 0.0) {
        desired = desired / desired.distance * maxSpeed;
        Offset steer = desired - velocity;
        return steer;
      }
    }
    return Offset.zero;
  }

  /// Wraps the vehicle around the screen edges.
  void wrapAround(Size screenSize) {
    if (position.dx < 0) position = Offset(screenSize.width, position.dy);
    if (position.dx > screenSize.width) position = Offset(0, position.dy);
    if (position.dy < 0) position = Offset(position.dx, screenSize.height);
    if (position.dy > screenSize.height) position = Offset(position.dx, 0);
  }
}
