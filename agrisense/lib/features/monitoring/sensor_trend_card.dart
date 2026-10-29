import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class TrendPoint {
  const TrendPoint(this.at, this.value);
  final DateTime at;
  final double value;
}

class _Range {
  _Range(this.at);
  final DateTime at;
  final values = <double>[];
  double get low => values.reduce(math.min);
  double get high => values.reduce(math.max);
  double get average => values.reduce((a, b) => a + b) / values.length;
}

class SensorTrendCard extends StatelessWidget {
  const SensorTrendCard({
    required this.metric,
    required this.unit,
    required this.points,
    required this.daily,
    super.key,
  });

  final String metric, unit;
  final List<TrendPoint> points;
  final bool daily;

  String _date(DateTime at) => '${at.month}/${at.day}/${at.year}';
  String _time(DateTime at, {bool seconds = false}) {
    final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final minute = at.minute.toString().padLeft(2, '0');
    final second = seconds ? ':${at.second.toString().padLeft(2, '0')}' : '';
    return '$hour:$minute$second ${at.hour < 12 ? 'AM' : 'PM'}';
  }

  double _tickStep(double value) {
    final base = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    for (final multiplier in [1, 2, 5, 10]) {
      if (base * multiplier >= value) return base * multiplier;
    }
    return base * 10;
  }

  // Calendar-day coordinates avoid DST changing the width of a day.
  int _day(DateTime at) =>
      DateTime.utc(at.year, at.month, at.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  double _labelWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 11)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget _axisLabels(List<DateTime> dates, bool seconds) => LayoutBuilder(
    builder: (context, constraints) {
      final labels = dates
          .map(
            (at) =>
                daily ? '${at.month}/${at.day}' : _time(at, seconds: seconds),
          )
          .toList();
      const style = TextStyle(color: muted, fontSize: 11);
      final widest = labels
          .map((label) => _labelWidth(context, label))
          .reduce(math.max);
      final visible = labels.toSet().length == 1
          ? [labels.first]
          : labels.toSet().length < 3 || constraints.maxWidth / 3 < widest + 8
          ? [labels.first, labels.last]
          : labels;
      return Row(
        children: [
          for (var i = 0; i < visible.length; i++)
            Expanded(
              child: Text(
                visible[i],
                style: style,
                textAlign: visible.length == 1
                    ? TextAlign.center
                    : i == 0
                    ? TextAlign.left
                    : i == visible.length - 1
                    ? TextAlign.right
                    : TextAlign.center,
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final data = points.where((p) => p.value.isFinite).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    if (data.isEmpty) return const SizedBox.shrink();
    final first = data.first.at, last = data.last.at;
    final values = data.map((p) => p.value).toList();
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final average = values.reduce((a, b) => a + b) / values.length;
    final sparse = data.length < 3 || first == last;
    final span = math.max(
      1.0,
      last.difference(first).inMilliseconds.toDouble(),
    );
    final calendarDays = _day(last) - _day(first) + 1;
    final bucketDays = calendarDays <= 31 ? 1 : (calendarDays / 30).ceil();
    final ranges = <int, _Range>{};
    if (daily && !sparse) {
      for (final point in data) {
        final index = (_day(point.at) - _day(first)) ~/ bucketDays;
        final at = DateTime(
          first.year,
          first.month,
          first.day + index * bucketDays,
        );
        (ranges[index] ??= _Range(at)).values.add(point.value);
      }
    }
    final rangeCount = ranges.isEmpty ? 0 : ranges.keys.last;
    final padding = math.max((high - low) * .15, .2);
    final step = _tickStep((high - low + padding * 2) / 4);
    final minY = ((low - padding) / step).floor() * step;
    final maxY = ((high + padding) / step).ceil() * step;
    final yWidth = math.max(
      42.0,
      math.max(
            _labelWidth(context, minY.toStringAsFixed(step < 1 ? 1 : 0)),
            _labelWidth(context, maxY.toStringAsFixed(step < 1 ? 1 : 0)),
          ) +
          8,
    );
    final bars = <LineChartBarData>[];
    if (daily && !sparse) {
      for (final entry in ranges.entries) {
        bars.add(
          LineChartBarData(
            spots: [
              FlSpot(entry.key.toDouble(), entry.value.low),
              FlSpot(entry.key.toDouble(), entry.value.high),
            ],
            color: accent.withValues(alpha: .55),
            barWidth: 6,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        );
      }
      bars.add(
        LineChartBarData(
          spots: [
            for (final entry in ranges.entries)
              FlSpot(entry.key.toDouble(), entry.value.average),
          ],
          barWidth: 0,
          color: Colors.transparent,
          dotData: FlDotData(
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(
              radius: 3,
              color: accent,
              strokeWidth: 1.5,
              strokeColor: background,
            ),
          ),
        ),
      );
    } else if (!sparse) {
      bars.add(
        LineChartBarData(
          spots: [
            for (var i = 0; i < data.length; i++) ...[
              if (i > 0 &&
                  data[i].at.difference(data[i - 1].at) >
                      const Duration(minutes: 30))
                FlSpot.nullSpot,
              FlSpot(
                data[i].at.difference(first).inMilliseconds / span,
                data[i].value,
              ),
            ],
          ],
          color: accent,
          barWidth: 2,
          dotData: FlDotData(
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(
              radius: data.length > 48 ? 1.5 : 2.5,
              color: accent,
              strokeWidth: 0,
            ),
          ),
        ),
      );
    }
    final seconds = span < 120000;
    final axisDates = daily
        ? [
            first,
            DateTime(
              first.year,
              first.month,
              first.day + (rangeCount ~/ 2) * bucketDays,
            ),
            last,
          ]
        : [first, first.add(Duration(milliseconds: (span / 2).round())), last];
    return Panel(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '${values.last.toStringAsFixed(1)} $unit',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(
            'Last recorded ${_date(last)}, ${_time(last)}',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          if (sparse) ...[
            Text(
              'Only ${data.length} ${data.length == 1 ? 'reading' : 'readings'} recorded',
            ),
            const Text(
              'More readings are needed to show a trend.',
              style: TextStyle(color: muted),
            ),
            for (final point in data.take(2))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_date(point.at)}, ${_time(point.at, seconds: true)} · ${point.value.toStringAsFixed(1)} $unit',
                ),
              ),
          ] else ...[
            Text(
              daily
                  ? (bucketDays == 1
                        ? 'Daily low–high · dot = average'
                        : '$bucketDays-day low–high · dot = average')
                  : 'Readings · ${_date(first)}${_day(first) == _day(last) ? '' : ' – ${_date(last)}'}',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            Semantics(
              label:
                  '$metric chart. Lowest ${low.toStringAsFixed(1)} $unit. Highest ${high.toStringAsFixed(1)} $unit. Missing readings are left blank.',
              child: SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minX: daily ? -.5 : 0,
                    maxX: daily ? rangeCount + .5 : 1,
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: step,
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: bars,
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: yWidth,
                          interval: step,
                          getTitlesWidget: (value, _) => Text(
                            value.toStringAsFixed(step < 1 ? 1 : 0),
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      getTouchedSpotIndicator: (_, indexes) => [
                        for (final _ in indexes)
                          const TouchedSpotIndicatorData(
                            FlLine(color: Colors.transparent, strokeWidth: 0),
                            FlDotData(show: false),
                          ),
                      ],
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) => spots.map((spot) {
                          if (daily) {
                            if (spot.barIndex != bars.length - 1) return null;
                            final range = ranges[spot.x.round()]!;
                            final end = DateTime(
                              range.at.year,
                              range.at.month,
                              range.at.day + bucketDays - 1,
                            );
                            return LineTooltipItem(
                              '${_date(range.at)}${bucketDays == 1 ? '' : ' – ${_date(end)}'}\n'
                              'Low ${range.low.toStringAsFixed(1)} · High ${range.high.toStringAsFixed(1)} $unit\n'
                              'Average ${range.average.toStringAsFixed(1)} $unit\n${range.values.length} readings',
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            );
                          }
                          final at = first.add(
                            Duration(milliseconds: (spot.x * span).round()),
                          );
                          return LineTooltipItem(
                            '${_date(at)}, ${_time(at, seconds: seconds)}\n${spot.y.toStringAsFixed(1)} $unit',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Labels live outside the plot so their full height is included in layout.
            Padding(
              padding: EdgeInsets.only(left: yWidth, top: 8),
              child: _axisLabels(axisDates, seconds),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap for details. Gaps mean no readings were recorded.',
              style: TextStyle(color: muted),
            ),
          ],
          if (!sparse) const SizedBox(height: 16),
          if (!sparse)
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                Text('Lowest ${low.toStringAsFixed(1)} $unit'),
                Text('Highest ${high.toStringAsFixed(1)} $unit'),
              ],
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Reading details'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${data.length} recorded readings\nAverage of recorded readings: ${average.toStringAsFixed(1)} $unit\n'
                  'Recorded ${_date(first)}, ${_time(first)} – ${_date(last)}, ${_time(last)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
