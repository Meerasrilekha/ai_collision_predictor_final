import 'dart:async';

/// Monitors and reports performance metrics for the simulation.
class PerformanceMonitor {
  final Stopwatch _frameStopwatch = Stopwatch();
  final List<double> _frameTimes = [];
  final List<double> _cpuUsages = [];
  final List<int> _memoryUsages = [];

  Timer? _monitorTimer;
  int _frameCount = 0;
  double _fps = 0.0;
  double _averageFrameTime = 0.0;

  // Callbacks
  Function(double fps, double avgFrameTime, int memoryUsage)? onPerformanceUpdate;

  /// Start performance monitoring
  void startMonitoring() {
    _frameStopwatch.start();
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), _updateMetrics);
  }

  /// Record frame time
  void recordFrame() {
    _frameCount++;
    if (_frameStopwatch.elapsedMilliseconds > 0) {
      double frameTime = _frameStopwatch.elapsedMilliseconds / 1000.0;
      _frameTimes.add(frameTime);
      if (_frameTimes.length > 60) _frameTimes.removeAt(0); // Keep last 60 frames

      _frameStopwatch.reset();
      _frameStopwatch.start();
    }
  }

  void _updateMetrics(Timer timer) {
    // Calculate FPS
    if (_frameTimes.isNotEmpty) {
      _fps = _frameTimes.length / _frameTimes.reduce((a, b) => a + b);
      _averageFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    }

    // Estimate memory usage (simplified)
    // In a real app, you'd use platform-specific APIs
    int estimatedMemory = (_frameTimes.length * 8) + (_cpuUsages.length * 8) + 1024; // KB

    _memoryUsages.add(estimatedMemory);
    if (_memoryUsages.length > 60) _memoryUsages.removeAt(0);

    // Notify listeners
    onPerformanceUpdate?.call(_fps, _averageFrameTime, estimatedMemory);
  }

  /// Get current performance metrics
  Map<String, dynamic> getMetrics() {
    return {
      'fps': _fps,
      'averageFrameTime': _averageFrameTime,
      'frameCount': _frameCount,
      'memoryUsage': _memoryUsages.isNotEmpty ? _memoryUsages.last : 0,
      'cpuUsage': _cpuUsages.isNotEmpty ? _cpuUsages.last : 0.0,
    };
  }

  /// Check if performance is optimal
  bool isPerformanceOptimal() {
    return _fps >= 20.0 && _averageFrameTime <= 0.05;
  }

  /// Get performance status
  String getPerformanceStatus() {
    if (_fps >= 30.0) return 'Excellent';
    if (_fps >= 20.0) return 'Good';
    if (_fps >= 15.0) return 'Fair';
    return 'Poor';
  }

  /// Reset monitoring data
  void reset() {
    _frameTimes.clear();
    _cpuUsages.clear();
    _memoryUsages.clear();
    _frameCount = 0;
    _fps = 0.0;
    _averageFrameTime = 0.0;
  }

  /// Stop monitoring
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _frameStopwatch.stop();
  }
}
