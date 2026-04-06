import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ── Design Tokens ──────────────────────────────────────────────────────────
const _green = Color(0xFF10B981);
const _greenDark = Color(0xFF059669);
const _blue = Color(0xFF3B82F6);
const _purple = Color(0xFF8B5CF6);
const _amber = Color(0xFFF59E0B);
const _red = Color(0xFFEF4444);
const _pink = Color(0xFFEC4899);
const _cyan = Color(0xFF06B6D4);
const _bg = Color(0xFFF0FDF4);

/// Chart colors for categories
const _chartColors = [_green, _blue, _purple, _amber, _red, _pink, _cyan,
  Color(0xFF8B5CF6), Color(0xFFF97316)];

/// Health Analytics Screen — Data Visualization using fl_chart.
///
/// Demonstrates:
///  - Pie Chart: Records by category distribution
///  - Bar Chart: Records added per month (last 6 months)
///  - Line Chart: Health records trend over time
///  - Summary statistics cards
class HealthAnalyticsScreen extends StatefulWidget {
  const HealthAnalyticsScreen({super.key});
  @override
  State<HealthAnalyticsScreen> createState() => _HealthAnalyticsScreenState();
}

class _HealthAnalyticsScreenState extends State<HealthAnalyticsScreen> {
  bool _isLoading = true;
  String? _error;

  // Data
  Map<String, int> _categoryData = {};
  Map<String, int> _monthlyData = {};
  List<Map<String, dynamic>> _timelineData = [];
  int _totalRecords = 0;
  int _totalAppointments = 0;
  String _mostCommonCategory = '—';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final db = FirebaseFirestore.instance;

      // Fetch health records
      final recordsSnap = await db
          .collection('health_records')
          .where('patientId', isEqualTo: uid)
          .orderBy('date', descending: true)
          .get();

      // Fetch appointments count
      final apptsSnap = await db
          .collection('appointments')
          .where('patientId', isEqualTo: uid)
          .get();

      // Process category distribution (for Pie Chart)
      final Map<String, int> catCounts = {};
      final Map<String, int> monthlyCounts = {};
      final List<Map<String, dynamic>> timeline = [];

      for (final doc in recordsSnap.docs) {
        final data = doc.data();
        final category = data['category'] as String? ?? 'General';
        final ts = data['date'] as Timestamp?;
        final date = ts?.toDate() ?? DateTime.now();

        // Category counts
        catCounts[category] = (catCounts[category] ?? 0) + 1;

        // Monthly counts (last 6 months)
        final monthKey = DateFormat('MMM yy').format(date);
        monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;

        // Timeline data
        timeline.add({
          'date': date,
          'category': category,
          'title': data['title'] as String? ?? '',
        });
      }

      // Find most common category
      String topCat = '—';
      int topCount = 0;
      catCounts.forEach((key, value) {
        if (value > topCount) {
          topCount = value;
          topCat = key;
        }
      });

      if (!mounted) return;
      setState(() {
        _categoryData = catCounts;
        _monthlyData = monthlyCounts;
        _timelineData = timeline;
        _totalRecords = recordsSnap.size;
        _totalAppointments = apptsSnap.size;
        _mostCommonCategory = topCat;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _green,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF064E3B), _green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.bar_chart_rounded,
                                  color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Health Analytics',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold)),
                                  Text('Data Visualization & Insights',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.75),
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _green),
                    SizedBox(height: 16),
                    Text('Loading analytics...',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: _red, size: 48),
                    const SizedBox(height: 16),
                    const Text('Failed to load analytics',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Summary Stats ─────────────────────────────
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.folder_rounded,
                          label: 'Total Records',
                          value: '$_totalRecords',
                          color: _blue,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          icon: Icons.calendar_today_rounded,
                          label: 'Appointments',
                          value: '$_totalAppointments',
                          color: _green,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          icon: Icons.star_rounded,
                          label: 'Top Category',
                          value: _mostCommonCategory,
                          color: _purple,
                          smallText: true,
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── PIE CHART: Records by Category ────────────
                    _ChartCard(
                      title: 'Records by Category',
                      subtitle: 'Distribution of health record types',
                      icon: Icons.pie_chart_rounded,
                      color: _purple,
                      child: _categoryData.isEmpty
                          ? _emptyChart('No records to visualize')
                          : SizedBox(
                              height: 220,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 3,
                                        centerSpaceRadius: 36,
                                        sections: _buildPieSections(),
                                        pieTouchData: PieTouchData(
                                          enabled: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: _buildLegend(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // ── BAR CHART: Monthly Records ────────────────
                    _ChartCard(
                      title: 'Monthly Records',
                      subtitle: 'Number of records added per month',
                      icon: Icons.bar_chart_rounded,
                      color: _blue,
                      child: _monthlyData.isEmpty
                          ? _emptyChart('No monthly data available')
                          : SizedBox(
                              height: 220,
                              child: BarChart(
                                BarChartData(
                                  alignment: BarChartAlignment.spaceAround,
                                  maxY: (_monthlyData.values.isEmpty
                                          ? 5
                                          : _monthlyData.values
                                                  .reduce((a, b) =>
                                                      a > b ? a : b)
                                                  .toDouble() +
                                              2),
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      tooltipRoundedRadius: 8,
                                      getTooltipItem: (group, groupIndex,
                                          rod, rodIndex) {
                                        final key = _monthlyData.keys
                                            .toList()[groupIndex];
                                        return BarTooltipItem(
                                          '$key\n${rod.toY.toInt()} records',
                                          const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    show: true,
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final keys =
                                              _monthlyData.keys.toList();
                                          if (value.toInt() < keys.length) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 8),
                                              child: Text(
                                                keys[value.toInt()],
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                        reservedSize: 30,
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 30,
                                        getTitlesWidget: (value, meta) {
                                          if (value == value.roundToDouble()) {
                                            return Text(
                                              '${value.toInt()}',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 11,
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: 1,
                                    getDrawingHorizontalLine: (value) =>
                                        FlLine(
                                      color: Colors.grey[200]!,
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  barGroups: _buildBarGroups(),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // ── LINE CHART: Records Trend ─────────────────
                    _ChartCard(
                      title: 'Records Timeline',
                      subtitle: 'Cumulative health records over time',
                      icon: Icons.show_chart_rounded,
                      color: _green,
                      child: _timelineData.isEmpty
                          ? _emptyChart('No timeline data available')
                          : SizedBox(
                              height: 220,
                              child: LineChart(
                                LineChartData(
                                  lineTouchData: LineTouchData(
                                    enabled: true,
                                    touchTooltipData: LineTouchTooltipData(
                                      tooltipRoundedRadius: 8,
                                      getTooltipItems: (spots) {
                                        return spots.map((spot) {
                                          return LineTooltipItem(
                                            '${spot.y.toInt()} records',
                                            const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        }).toList();
                                      },
                                    ),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: 1,
                                    getDrawingHorizontalLine: (value) =>
                                        FlLine(
                                      color: Colors.grey[200]!,
                                      strokeWidth: 1,
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 30,
                                        interval: 1,
                                        getTitlesWidget: (value, meta) {
                                          final spots = _buildLineSpots();
                                          final idx = value.toInt();
                                          if (idx >= 0 &&
                                              idx < spots.length &&
                                              idx % 2 == 0) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8),
                                              child: Text(
                                                _getMonthLabel(idx,
                                                    spots.length),
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 10,
                                                ),
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 30,
                                        getTitlesWidget: (value, meta) {
                                          if (value ==
                                              value.roundToDouble()) {
                                            return Text(
                                              '${value.toInt()}',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 11,
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _buildLineSpots(),
                                      isCurved: true,
                                      curveSmoothness: 0.3,
                                      color: _green,
                                      barWidth: 3,
                                      isStrokeCapRound: true,
                                      dotData: FlDotData(
                                        show: true,
                                        getDotPainter:
                                            (spot, percent, barData, index) {
                                          return FlDotCirclePainter(
                                            radius: 4,
                                            color: Colors.white,
                                            strokeWidth: 2,
                                            strokeColor: _green,
                                          );
                                        },
                                      ),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color:
                                            _green.withValues(alpha: 0.12),
                                      ),
                                    ),
                                  ],
                                  minY: 0,
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    // ── Category Breakdown List ──────────────────
                    _ChartCard(
                      title: 'Category Breakdown',
                      subtitle: 'Detailed count per category',
                      icon: Icons.list_alt_rounded,
                      color: _amber,
                      child: _categoryData.isEmpty
                          ? _emptyChart('No categories found')
                          : Column(
                              children: _categoryData.entries.map((entry) {
                                final idx = _categoryData.keys
                                    .toList()
                                    .indexOf(entry.key);
                                final color =
                                    _chartColors[idx % _chartColors.length];
                                final percentage = _totalRecords > 0
                                    ? (entry.value / _totalRecords * 100)
                                    : 0.0;

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: color
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${entry.value}',
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.key,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: percentage / 100,
                                                backgroundColor: Colors
                                                    .grey[200],
                                                color: color,
                                                minHeight: 6,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${percentage.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  CHART DATA BUILDERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Build pie chart sections from category data
  List<PieChartSectionData> _buildPieSections() {
    final entries = _categoryData.entries.toList();
    return entries.asMap().entries.map((mapEntry) {
      final idx = mapEntry.key;
      final entry = mapEntry.value;
      final color = _chartColors[idx % _chartColors.length];
      final percentage = _totalRecords > 0
          ? (entry.value / _totalRecords * 100)
          : 0.0;

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 55,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  /// Build legend items for pie chart
  List<Widget> _buildLegend() {
    final entries = _categoryData.entries.toList();
    return entries.asMap().entries.map((mapEntry) {
      final idx = mapEntry.key;
      final entry = mapEntry.value;
      final color = _chartColors[idx % _chartColors.length];

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${entry.key} (${entry.value})',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  /// Build bar chart groups from monthly data
  List<BarChartGroupData> _buildBarGroups() {
    final entries = _monthlyData.entries.toList();
    // Take last 6 entries
    final display =
        entries.length > 6 ? entries.sublist(entries.length - 6) : entries;

    return display.asMap().entries.map((mapEntry) {
      final idx = mapEntry.key;
      final entry = mapEntry.value;

      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: _blue,
            width: 22,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: (_monthlyData.values.isEmpty
                      ? 5
                      : _monthlyData.values
                              .reduce((a, b) => a > b ? a : b)
                              .toDouble() +
                          2),
              color: Colors.grey[100],
            ),
          ),
        ],
      );
    }).toList();
  }

  /// Build line chart spots (cumulative records over time)
  List<FlSpot> _buildLineSpots() {
    if (_timelineData.isEmpty) return [const FlSpot(0, 0)];

    // Sort by date ascending
    final sorted = List<Map<String, dynamic>>.from(_timelineData)
      ..sort((a, b) =>
          (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Group by month and show cumulative count
    final Map<String, int> monthly = {};
    for (final item in sorted) {
      final date = item['date'] as DateTime;
      final key = DateFormat('MMM yy').format(date);
      monthly[key] = (monthly[key] ?? 0) + 1;
    }

    int cumulative = 0;
    final spots = <FlSpot>[];
    int i = 0;
    for (final entry in monthly.entries) {
      cumulative += entry.value;
      spots.add(FlSpot(i.toDouble(), cumulative.toDouble()));
      i++;
    }

    return spots.isEmpty ? [const FlSpot(0, 0)] : spots;
  }

  String _getMonthLabel(int index, int total) {
    if (_timelineData.isEmpty) return '';
    final sorted = List<Map<String, dynamic>>.from(_timelineData)
      ..sort((a, b) =>
          (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    final Map<String, int> monthly = {};
    for (final item in sorted) {
      final date = item['date'] as DateTime;
      final key = DateFormat('MMM').format(date);
      monthly[key] = (monthly[key] ?? 0) + 1;
    }

    final keys = monthly.keys.toList();
    if (index < keys.length) return keys[index];
    return '';
  }

  Widget _emptyChart(String msg) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_chart_outlined_rounded,
                color: Colors.grey[300], size: 40),
            const SizedBox(height: 10),
            Text(msg, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 4),
            Text('Add health records to see charts',
                style: TextStyle(color: Colors.grey[350], fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool smallText;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.smallText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: smallText ? 12 : 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
