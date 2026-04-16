import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../providers/simulation_provider.dart';

import 'dart:html' as html;

/// Results page showing summarized metrics and distance vs time graph.
/// Option to save/share screenshot and restart simulation.
class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SimulationProvider>(context);
    final metrics = provider.getSummaryMetrics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results & Analysis'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simulation Summary',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text('Average Distance: ${metrics['averageDistance']?.toStringAsFixed(1) ?? '0.0'} m'),
            Text('Warning Count: ${metrics['warningCount'] ?? 0}'),
            Text('Max Collision Probability: ${(metrics['maxCollisionProbability'] ?? 0.0 * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 40),
            const Text(
              'Distance vs Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: (metrics['distanceHistory'] as List<double>? ?? [])
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value))
                          .toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Safety Indicator History Graph
            const Text(
              'Safety Status History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: provider.statusHistory.asMap().entries.map((entry) {
                        int index = entry.key;
                        String status = entry.value;
                        double value = status == 'Safe' ? 1.0 : status == 'Caution' ? 2.0 : 3.0;
                        return FlSpot(index.toDouble(), value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _exportResults(context, metrics, 'json', provider),
                  child: const Text('Download JSON'),
                ),
                ElevatedButton(
                  onPressed: () => _exportResults(context, metrics, 'csv', provider),
                  child: const Text('Download CSV'),
                ),
                ElevatedButton(
                  onPressed: () {
                    provider.resetSimulation(MediaQuery.of(context).size);
                    Navigator.of(context).pushReplacementNamed('/simulation');
                  },
                  child: const Text('Restart Simulation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportResults(BuildContext context, Map<String, dynamic> metrics, String format, SimulationProvider provider) async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      late String content;

      if (format == 'json') {
        final report = {
          'timestamp': DateTime.now().toIso8601String(),
          'summary': {
            'averageDistance': metrics['averageDistance'],
            'warningCount': metrics['warningCount'],
            'maxCollisionProbability': metrics['maxCollisionProbability'],
          },
          'distanceHistory': metrics['distanceHistory'],
        };
        content = report.toString();
      } else if (format == 'csv') {
        final data = provider.recordedData;
        if (data.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No recorded data available')),
          );
          return;
        }
        content = 'Frame,Timestamp,VehicleID,X,Y,VX,VY,AX,AY,Status,StaticRisk,TemporalRisk\n';
        for (var row in data) {
          content += '${row['Frame']},${row['Timestamp']},${row['VehicleID']},${row['X']},${row['Y']},${row['VX']},${row['VY']},${row['AX']},${row['AY']},${row['Status']},${row['StaticRisk']},${row['TemporalRisk']}\n';
        }
      }

      if (kIsWeb) {
        // For web, open in new tab with data URL
        final encoded = Uri.encodeComponent(content);
        final url = 'data:text/csv;charset=utf-8,$encoded';
        html.window.open(url, '_blank');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV opened in new tab - save the page to download')),
        );
      } else {
        // For mobile/desktop, save to documents directory
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/simulation_${format}_$timestamp.$format');
        await file.writeAsString(content);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report saved to: ${file.path}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save report')),
      );
    }
  }
}
