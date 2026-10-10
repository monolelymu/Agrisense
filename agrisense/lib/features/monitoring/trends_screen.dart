import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../data/models.dart';
import '../../core/app_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({required this.controller, super.key});
  final AppController controller;
  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int days = 7;
  String metric = 'Soil moisture';
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final now = DateTime.now();
    final readings =
        c.readings
            .where(
              (r) =>
                  r.crop == c.selectedCrop &&
                  !r.timestamp.isBefore(now.subtract(Duration(days: days))),
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    double value(SensorReading r) => switch (metric) {
      'Temperature' =>
        c.fahrenheit ? r.temperature * 9 / 5 + 32 : r.temperature,
      'Humidity' => r.humidity,
      'Gas / VOC' => r.gas,
      _ => r.soil,
    };
    final unit = switch (metric) {
      'Temperature' => c.fahrenheit ? '°F' : '°C',
      'Gas / VOC' => 'raw',
      _ => '%',
    };
    final start = now.subtract(Duration(days: days));
    return PageBody(
      children: [
        SectionTitle(
          'Growing patterns',
          '${c.selectedCrop.label} • sample readings over time',
        ),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            CropPicker(value: c.selectedCrop, onChanged: c.selectCrop),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('24 hours')),
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
              ],
              selected: {days},
              onSelectionChanged: (v) => setState(() => days = v.first),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in [
              'Soil moisture',
              'Temperature',
              'Humidity',
              'Gas / VOC',
            ])
              ChoiceChip(
                label: Text(m),
                selected: metric == m,
                onSelected: (_) => setState(() => metric = m),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (readings.isEmpty)
          const EmptyState(
            'No readings in this period',
            'Connect a simulated Sensor Node and record a sample.',
          )
        else
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      '$metric ($unit)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Tag('MOCK DATA'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${readings.length} saved samples • ${dateLabel(start)} to ${dateLabel(now)}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 290,
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: days * 24,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFF304035),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            getTitlesWidget: (value, meta) => Text(
                              value.toStringAsFixed(0),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: days * 6,
                            reservedSize: 30,
                            getTitlesWidget: (v, meta) {
                              final t = start.add(
                                Duration(minutes: (v * 60).round()),
                              );
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  days == 1
                                      ? '${t.hour}:00'
                                      : '${t.month}/${t.day}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (final r in readings)
                              FlSpot(
                                r.timestamp.difference(start).inMilliseconds /
                                    3600000,
                                value(r),
                              ),
                          ],
                          isCurved: false,
                          color: accent,
                          barWidth: 3,
                          dotData: FlDotData(show: readings.length < 8),
                          belowBarData: BarAreaData(
                            show: true,
                            color: accent.withValues(alpha: .07),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        const Text(
          'The initial seven days are generated samples. New points are added by the guided demo, not by a live sensor.',
          style: TextStyle(color: muted),
        ),
      ],
    );
  }
}
