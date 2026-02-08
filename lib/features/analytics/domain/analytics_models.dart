import 'package:equatable/equatable.dart';

enum TimePeriod { day, week, month, year }

enum AnalyticsParameter {
  ph('pH', 'pH'),
  conductivity('Conductivity', 'µS/cm'),
  tds('TDS', 'ppm'),
  alkalinity('Alkalinity', 'ppm'),
  hardness('Hardness', 'ppm'),
  chloride('Chloride', 'ppm'),
  sulfates('Sulfates', 'ppm'),
  iron('Iron', 'ppm'),
  lsi('LSI', ''),
  rsi('RSI', '');

  final String label;
  final String unit;
  const AnalyticsParameter(this.label, this.unit);
}

class DateRange extends Equatable {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);

  @override
  List<Object> get props => [start, end];
}

class AnalyticsData extends Equatable {
  final Map<AnalyticsParameter, double> metrics;
  final TimePeriod period;
  final DateRange range;

  const AnalyticsData({
    required this.metrics,
    required this.period,
    required this.range,
  });

  @override
  List<Object> get props => [metrics, period, range];
}
