import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: compute a flag color from a record map
// ─────────────────────────────────────────────────────────────────────────────
Color flagColor(String? flag) {
  switch (flag) {
    case 'critical': return Colors.red;
    case 'warning': return Colors.orange;
    default: return Colors.green;
  }
}

IconData flagIcon(String? flag) {
  switch (flag) {
    case 'critical': return Icons.warning_amber_rounded;
    case 'warning': return Icons.info_outline;
    default: return Icons.check_circle_outline;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MemberDetailScreen
// ─────────────────────────────────────────────────────────────────────────────
class MemberDetailScreen extends StatefulWidget {
  final Map<String, dynamic> member;
  final String token;

  const MemberDetailScreen({super.key, required this.member, required this.token});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<dynamic>> _historyFuture;
  late Future<Map<String, dynamic>> _analyticsFuture;
  String _selectedTimeRange = 'all'; // Default time range for analytics

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    final id = widget.member['id'].toString();
    setState(() {
      _historyFuture = LocalDbService.getMemberHistory(widget.token, id);
      _analyticsFuture = LocalDbService.getMemberAnalytics(widget.token, id);
    });
  }

  DateTime? _getCutoffDate() {
    final now = DateTime.now();
    switch (_selectedTimeRange) {
      case '7d': return now.subtract(const Duration(days: 7));
      case '14d': return now.subtract(const Duration(days: 14));
      case '1m': return now.subtract(const Duration(days: 30));
      case '2m': return now.subtract(const Duration(days: 60));
      case '3m': return now.subtract(const Duration(days: 90));
      case '6m': return now.subtract(const Duration(days: 180));
      case '9m': return now.subtract(const Duration(days: 270));
      case '1y': return now.subtract(const Duration(days: 365));
      case 'all':
      default:
        return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Add Medical Record Dialog
  // ─────────────────────────────────────────────────────────────────────
  void _showAddRecordDialog() {
    String entrySource = 'manual'; // 'manual' or 'device'
    final systolicCtrl = TextEditingController();
    final diastolicCtrl = TextEditingController();
    final bsfCtrl = TextEditingController();
    final bsppCtrl = TextEditingController();
    final tempCtrl = TextEditingController();
    final pulseCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.monitor_heart, color: Color(0xFF00796B)),
            SizedBox(width: 8),
            Text('Add Health Record'),
          ]),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Entry Source Toggle ──
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => entrySource = 'manual'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: entrySource == 'manual' ? const Color(0xFF00796B) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.edit_note,
                                    size: 18,
                                    color: entrySource == 'manual' ? Colors.white : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('Manual Entry',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: entrySource == 'manual' ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => entrySource = 'device'),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: entrySource == 'device' ? const Color(0xFF00796B) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.usb,
                                    size: 18,
                                    color: entrySource == 'device' ? Colors.white : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('Device (USB)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: entrySource == 'device' ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Manual Entry Fields ──
                  if (entrySource == 'manual') ...[
                    _vitalField(systolicCtrl, 'BP Systolic (mmHg)', Icons.favorite),
                    _vitalField(diastolicCtrl, 'BP Diastolic (mmHg)', Icons.favorite_border),
                    _vitalField(bsfCtrl, 'Blood Sugar Fasting (mg/dL)', Icons.water_drop),
                    _vitalField(bsppCtrl, 'Blood Sugar PP (mg/dL)', Icons.water_drop_outlined),
                    _vitalField(tempCtrl, 'Temperature (°F)', Icons.thermostat),
                    _vitalField(pulseCtrl, 'Pulse Rate (bpm)', Icons.monitor_heart_outlined),
                    const SizedBox(height: 4),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],

                  // ── Device Stub ──
                  if (entrySource == 'device') ...[
                    // TODO: Wire up usb_serial package (Android USB OTG) once device output
                    // format is confirmed. iOS does not support direct serial device reading
                    // unless hardware is MFi certified — manual entry must always be
                    // available on iOS regardless.
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.usb, size: 40, color: Colors.orange.shade700),
                          const SizedBox(height: 12),
                          Text(
                            'Device Connection',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connect the health monitoring device via USB OTG to begin reading vitals automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              // TODO: Implement USB serial connection
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Device connection not yet implemented. Use Manual Entry for now.')),
                              );
                            },
                            icon: const Icon(Icons.cable),
                            label: const Text('Connect Device'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            if (entrySource == 'manual')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving ? null : () async {
                  setModalState(() => isSaving = true);
                  final ok = await LocalDbService.addMedicalRecord(
                    token: widget.token,
                    memberId: widget.member['id'].toString(),
                    bloodPressureSystolic: int.tryParse(systolicCtrl.text),
                    bloodPressureDiastolic: int.tryParse(diastolicCtrl.text),
                    bloodSugarFasting: double.tryParse(bsfCtrl.text),
                    bloodSugarPostprandial: double.tryParse(bsppCtrl.text),
                    temperature: double.tryParse(tempCtrl.text),
                    pulseRate: int.tryParse(pulseCtrl.text),
                    notes: notesCtrl.text,
                    entrySource: 'manual',
                  );
                  if (!mounted || !context.mounted) return;
                  Navigator.pop(ctx);
                  if (ok && context.mounted) {
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Health record saved!'), backgroundColor: Colors.green),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to save record.'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Record'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _vitalField(TextEditingController ctrl, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final name = widget.member['full_name'] ?? 'Member';
    final currentFlag = widget.member['current_flag'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'Age: ${widget.member['age']} • ${widget.member['gender']} • ${widget.member['relationship_to_head']}',
              style: const TextStyle(fontSize: 11, color: Colors.tealAccent),
            ),
          ],
        ),
        actions: [
          if (currentFlag != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                backgroundColor: flagColor(currentFlag).withValues(alpha: 0.2),
                side: BorderSide(color: flagColor(currentFlag)),
                label: Text(currentFlag.toUpperCase(),
                  style: TextStyle(color: flagColor(currentFlag), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BFA5),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'Health History'),
            Tab(icon: Icon(Icons.show_chart), text: 'Trends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryTab(),
          _buildAnalyticsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRecordDialog,
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_chart),
        label: const Text('Add Record'),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Tab 1: Health History
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    return FutureBuilder<List<dynamic>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monitor_heart_outlined, size: 54, color: Colors.grey),
                SizedBox(height: 12),
                Text('No health records yet.', style: TextStyle(color: Colors.grey, fontSize: 15)),
                SizedBox(height: 6),
                Text('Tap "+ Add Record" to log the first reading.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, i) {
            final r = records[i];
            final flag = r['flag'] as String? ?? 'normal';
            final isDevice = r['entry_source'] == 'device';
            final dateStr = _formatDate(r['recorded_at']);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isDevice ? Icons.usb : Icons.edit_note,
                          size: 16,
                          color: isDevice ? Colors.blueAccent : Colors.teal,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$dateStr • ${r['recorded_by_name'] ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: flagColor(flag).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: flagColor(flag).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(flagIcon(flag), size: 13, color: flagColor(flag)),
                              const SizedBox(width: 4),
                              Text(flag.toUpperCase(),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: flagColor(flag)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Chip(
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                          label: Text(isDevice ? 'Device' : 'Manual',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDevice ? Colors.blueAccent : Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: isDevice ? Colors.blue.shade50 : Colors.teal.shade50,
                          side: BorderSide(color: isDevice ? Colors.blueAccent.withValues(alpha: 0.4) : Colors.teal.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (r['blood_pressure_systolic'] != null || r['blood_pressure_diastolic'] != null)
                          _vitalChip('BP', '${r['blood_pressure_systolic'] ?? '?'}/${r['blood_pressure_diastolic'] ?? '?'} mmHg', Icons.favorite, Colors.red),
                        if (r['blood_sugar_fasting'] != null)
                          _vitalChip('BSF', '${r['blood_sugar_fasting']} mg/dL', Icons.water_drop, Colors.purple),
                        if (r['blood_sugar_postprandial'] != null)
                          _vitalChip('BSPP', '${r['blood_sugar_postprandial']} mg/dL', Icons.water_drop_outlined, Colors.deepPurple),
                        if (r['temperature'] != null)
                          _vitalChip('Temp', '${r['temperature']}°F', Icons.thermostat, Colors.orange),
                        if (r['pulse_rate'] != null)
                          _vitalChip('Pulse', '${r['pulse_rate']} bpm', Icons.monitor_heart, Colors.teal),
                      ],
                    ),
                    if (r['notes'] != null && (r['notes'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('📝 ${r['notes']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _vitalChip(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Tab 2: Analytics / Charts
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildAnalyticsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analyticsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? {};

        final cutoff = _getCutoffDate();
        List<dynamic> filterData(List<dynamic>? list) {
          if (list == null) return [];
          if (cutoff == null) return list;
          return list.where((item) {
            try {
              return DateTime.parse(item['date'] as String).toLocal().isAfter(cutoff);
            } catch (_) {
              return true;
            }
          }).toList();
        }

        final systolicDataList = filterData(data['blood_pressure_systolic'] as List?);
        final diastolicDataList = filterData(data['blood_pressure_diastolic'] as List?);
        final bsfDataList = filterData(data['blood_sugar_fasting'] as List?);

        final systolicData = _toSpots(systolicDataList);
        final diastolicData = _toSpots(diastolicDataList);
        final bsfData = _toSpots(bsfDataList);

        final bpDates = systolicDataList.map((e) => e['date'] as String).toList();
        final bsfDates = bsfDataList.map((e) => e['date'] as String).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('Time Range: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedTimeRange,
                    isDense: true,
                    underline: Container(height: 1, color: Colors.teal),
                    items: const [
                      DropdownMenuItem(value: '7d', child: Text('Last 7 Days')),
                      DropdownMenuItem(value: '14d', child: Text('Last 14 Days')),
                      DropdownMenuItem(value: '1m', child: Text('Last 1 Month')),
                      DropdownMenuItem(value: '2m', child: Text('Last 2 Months')),
                      DropdownMenuItem(value: '3m', child: Text('Last 3 Months')),
                      DropdownMenuItem(value: '6m', child: Text('Last 6 Months')),
                      DropdownMenuItem(value: '9m', child: Text('Last 9 Months')),
                      DropdownMenuItem(value: '1y', child: Text('Last 1 Year')),
                      DropdownMenuItem(value: 'all', child: Text('All Time')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedTimeRange = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16).copyWith(top: 0),
                children: [
                  _chartCard(
                    title: 'Blood Pressure',
                    subtitle: '— Systolic   ┄ Diastolic',
                    dates: bpDates,
                    lines: [
                      LineChartBarData(
                        spots: systolicData,
                        isCurved: true,
                        color: Colors.red,
                        barWidth: 2,
                        dotData: FlDotData(show: systolicData.length <= 10),
                      ),
                      LineChartBarData(
                        spots: diastolicData,
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 2,
                        dotData: FlDotData(show: diastolicData.length <= 10),
                        dashArray: [5, 4],
                      ),
                    ],
                    yLabel: 'mmHg',
                    emptyMessage: 'No BP data yet',
                    hasData: systolicData.isNotEmpty || diastolicData.isNotEmpty,
                  ),
                  const SizedBox(height: 16),
                  _chartCard(
                    title: 'Blood Sugar (Fasting)',
                    subtitle: '— Fasting glucose',
                    dates: bsfDates,
                    lines: [
                      LineChartBarData(
                        spots: bsfData,
                        isCurved: true,
                        color: Colors.purple,
                        barWidth: 2,
                        dotData: FlDotData(show: bsfData.length <= 10),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.purple.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                    yLabel: 'mg/dL',
                    emptyMessage: 'No blood sugar data yet',
                    hasData: bsfData.isNotEmpty,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<FlSpot> _toSpots(List? dataPoints) {
    if (dataPoints == null || dataPoints.isEmpty) return [];
    return dataPoints.asMap().entries.map((entry) {
      final value = (entry.value['value'] as num).toDouble();
      return FlSpot(entry.key.toDouble(), value);
    }).toList();
  }

  Widget _chartCard({
    required String title,
    required String subtitle,
    required List<String> dates,
    required List<LineChartBarData> lines,
    required String yLabel,
    required String emptyMessage,
    required bool hasData,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            if (!hasData)
              SizedBox(
                height: 120,
                child: Center(child: Text(emptyMessage, style: const TextStyle(color: Colors.grey))),
              )
            else
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    lineBarsData: lines,
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1),
                      getDrawingVerticalLine: (_) =>
                        const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        axisNameWidget: Text(yLabel, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            if (value % 1 != 0) return const SizedBox.shrink();
                            int index = value.toInt();
                            if (index < 0 || index >= dates.length) return const SizedBox.shrink();
                            
                            String dtStr = dates[index];
                            String formatted = '';
                            try {
                              final dt = DateTime.parse(dtStr).toLocal();
                              formatted = DateFormat('dd MMM').format(dt);
                            } catch (_) {
                              formatted = dtStr.substring(0, 5); // Fallback
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                formatted,
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((spot) => LineTooltipItem(
                          spot.y.toStringAsFixed(1),
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )).toList(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return 'Unknown date';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }
}
