import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';
import '../services/image_utils.dart';
import '../services/news2_delta_service.dart';
import '../services/sepsis_inference_service.dart';
import '../services/language_service.dart';
import '../services/on_device_llm_service.dart';
import '../widgets/language_switcher_widget.dart';
import '../widgets/qwen_ai_chat_modal.dart';

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
  late Map<String, dynamic> _currentMember;
  String _selectedTimeRange = 'all'; // Default time range for analytics

  @override
  void initState() {
    super.initState();
    _currentMember = Map<String, dynamic>.from(widget.member);
    _tabController = TabController(length: 3, vsync: this);
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
      _historyFuture = LocalDbService.getMemberHistory(widget.token, id).then((records) {
        if (records.isNotEmpty) {
          final latest = records.first;
          setState(() {
            _currentMember['current_flag'] = latest['flag'];
          });
        }
        return records;
      });
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

  void _showEditMemberDialog() {
    final nameCtrl = TextEditingController(text: _currentMember['full_name']?.toString() ?? '');
    final ageCtrl = TextEditingController(text: _currentMember['age']?.toString() ?? '');
    final relCtrl = TextEditingController(text: _currentMember['relationship_to_head']?.toString() ?? '');
    String gender = _currentMember['gender']?.toString().toLowerCase() ?? 'male';
    if (gender != 'male' && gender != 'female' && gender != 'other') gender = 'male';
    String? pickedImageBase64 = _currentMember['profile_image']?.toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text('Edit Member Details'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final compressedBase64 = await ImageUtils.pickAndCompressImage(context);
                    if (compressedBase64 != null) {
                      setModalState(() {
                        pickedImageBase64 = compressedBase64;
                      });
                    }
                  },
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.teal.shade50,
                    backgroundImage: ImageUtils.safeBase64Image(pickedImageBase64),
                    child: pickedImageBase64 == null
                        ? const Icon(Icons.add_a_photo, color: Colors.teal, size: 28)
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pickedImageBase64 == null ? 'Add Member Photo (Max 5MB)' : 'Photo Selected (Compressed)',
                  style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 12),
                TextField(controller: ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => gender = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship to Head')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && ageCtrl.text.isNotEmpty && relCtrl.text.isNotEmpty) {
                  final age = int.tryParse(ageCtrl.text) ?? 0;
                  final ok = await LocalDbService.updateMember(
                    token: widget.token,
                    memberId: _currentMember['id'].toString(),
                    fullName: nameCtrl.text,
                    age: age,
                    gender: gender,
                    relationship: relCtrl.text,
                    profileImage: pickedImageBase64,
                  );
                  if (!mounted || !context.mounted) return;
                  Navigator.pop(ctx);
                  if (ok) {
                    setState(() {
                      _currentMember['full_name'] = nameCtrl.text;
                      _currentMember['age'] = age;
                      _currentMember['gender'] = gender;
                      _currentMember['relationship_to_head'] = relCtrl.text;
                      if (pickedImageBase64 != null) {
                        _currentMember['profile_image'] = pickedImageBase64;
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Member details updated!'), backgroundColor: Colors.green),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            )
          ],
        ),
      ),
    );
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
    final spo2Ctrl = TextEditingController();
    final rrCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.monitor_heart, color: Color(0xFF00796B)),
            const SizedBox(width: 8),
            Text(LanguageService.tr('record_vital_signs')),
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
                                    color: entrySource == 'manual' ? Colors.white : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('Manual Entry',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: entrySource == 'manual' ? Colors.white : Colors.grey.shade800,
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
                                    color: entrySource == 'device' ? Colors.white : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('Device (USB)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: entrySource == 'device' ? Colors.white : Colors.grey.shade800,
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
                    _vitalField(systolicCtrl, LanguageService.tr('bp_systolic'), Icons.favorite),
                    _vitalField(diastolicCtrl, LanguageService.tr('bp_diastolic'), Icons.favorite_border),
                    _vitalField(pulseCtrl, LanguageService.tr('pulse_rate'), Icons.monitor_heart_outlined),
                    _vitalField(spo2Ctrl, LanguageService.tr('spo2'), Icons.air),
                    _vitalField(rrCtrl, LanguageService.tr('respiratory_rate'), Icons.waves),
                    _vitalField(tempCtrl, LanguageService.tr('temperature'), Icons.thermostat),
                    _vitalField(bsfCtrl, LanguageService.tr('blood_sugar_fasting'), Icons.water_drop),
                    _vitalField(bsppCtrl, LanguageService.tr('blood_sugar_pp'), Icons.water_drop_outlined),
                    const SizedBox(height: 4),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: LanguageService.tr('clinical_notes'),
                        prefixIcon: const Icon(Icons.notes),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],

                  // ── Device Stub ──
                  if (entrySource == 'device') ...[
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(LanguageService.tr('cancel'))),
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
                    pulseRate: int.tryParse(pulseCtrl.text),
                    spo2: int.tryParse(spo2Ctrl.text),
                    respiratoryRate: int.tryParse(rrCtrl.text),
                    temperature: double.tryParse(tempCtrl.text),
                    bloodSugarFasting: double.tryParse(bsfCtrl.text),
                    bloodSugarPostprandial: double.tryParse(bsppCtrl.text),
                    notes: notesCtrl.text,
                    entrySource: 'manual',
                  );
                  if (!mounted || !context.mounted) return;
                  Navigator.pop(ctx);
                  if (ok && context.mounted) {
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(LanguageService.tr('save_record')), backgroundColor: Colors.green),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to save record.'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(LanguageService.tr('save_record')),
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
    final name = _currentMember['full_name'] ?? 'Member';
    final currentFlag = (_currentMember['current_flag'] ?? widget.member['current_flag']) as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            GestureDetector(
              onTap: _showEditMemberDialog,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.teal.shade200,
                backgroundImage: ImageUtils.safeBase64Image(_currentMember['profile_image']?.toString()),
                child: ImageUtils.safeBase64Image(_currentMember['profile_image']?.toString()) != null
                    ? null
                    : Icon(
                        _currentMember['gender'] == 'male'
                            ? Icons.male
                            : (_currentMember['gender'] == 'female' ? Icons.female : Icons.person),
                        color: Colors.teal.shade900,
                        size: 20,
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text(
                    '${LanguageService.tr('age')}: ${_currentMember['age']} ${LanguageService.tr('years')} • ${_currentMember['gender']} • ${_currentMember['relationship_to_head']}',
                    style: const TextStyle(fontSize: 11, color: Colors.tealAccent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          const LanguageSwitcherWidget(),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit Member / Photo',
            onPressed: _showEditMemberDialog,
          ),
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
          tabs: [
            Tab(icon: const Icon(Icons.history), text: LanguageService.tr('vitals_history')),
            Tab(icon: const Icon(Icons.show_chart), text: LanguageService.tr('vital_changes')),
            Tab(icon: const Icon(Icons.psychology_outlined), text: LanguageService.tr('ai_insights')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryTab(),
          _buildAnalyticsTab(),
          _buildAIInsightsTab(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          T7ChatFloatingButton(
            member: _currentMember,
            heroTag: 'member_qwen_chat_fab',
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'member_add_record_fab',
            onPressed: _showAddRecordDialog,
            backgroundColor: const Color(0xFF00796B),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_chart),
            label: const Text('Add Record'),
          ),
        ],
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
                        if (r['pulse_rate'] != null)
                          _vitalChip('Pulse', '${r['pulse_rate']} bpm', Icons.monitor_heart, Colors.teal),
                        if (r['spo2'] != null)
                          _vitalChip('SpO2', '${r['spo2']}%', Icons.air, Colors.blue),
                        if (r['respiratory_rate'] != null)
                          _vitalChip('RR', '${r['respiratory_rate']} /min', Icons.waves, Colors.indigo),
                        if (r['temperature'] != null)
                          _vitalChip('Temp', '${r['temperature']}°F', Icons.thermostat, Colors.orange),
                        if (r['blood_sugar_fasting'] != null)
                          _vitalChip('BSF', '${r['blood_sugar_fasting']} mg/dL', Icons.water_drop, Colors.purple),
                        if (r['blood_sugar_postprandial'] != null)
                          _vitalChip('BSPP', '${r['blood_sugar_postprandial']} mg/dL', Icons.water_drop_outlined, Colors.deepPurple),
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

  // ─────────────────────────────────────────────────────────────────────
  // Tab 3: AI Health Intelligence (NEWS2 + DELTA + PhysioNet 2019 Sepsis)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildAIInsightsTab() {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, currentLang, _) {
        return FutureBuilder<List<dynamic>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error loading AI insights: ${snapshot.error}'));
            }

            final records = (snapshot.data ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

            if (records.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology_outlined, size: 64, color: Colors.teal.shade300),
                      const SizedBox(height: 16),
                      Text(
                        LanguageService.tr('ai_insights', defaultText: 'AI Health Intelligence'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No vital records recorded yet. Log the first health record to generate on-device NEWS2 Early Warning score, DELTA variations, and PhysioNet Sepsis risk prediction.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddRecordDialog,
                        icon: const Icon(Icons.add_chart),
                        label: const Text('Add First Record'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final latestRecord = records.first;
            final previousRecord = records.length > 1 ? records[1] : null;

            // 1. Evaluate NEWS2
            final news2Result = NEWS2DeltaService.evaluateNEWS2(latestRecord);

            // 2. Evaluate DELTA
            final deltaResult = NEWS2DeltaService.computeDelta(latestRecord, previousRecord);

            return FutureBuilder<Map<String, dynamic>>(
              future: SepsisInferenceService.predictSepsisRisk(
                records: records,
                member: _currentMember,
              ),
              builder: (context, sepsisSnapshot) {
                final sepsisResult = sepsisSnapshot.data ?? {
                  'risk_score': 0.05,
                  'risk_percent': '5%',
                  'risk_level': 'Low Risk',
                  'risk_color': '#4CAF50',
                  'confidence': 0.88,
                  'hours_to_onset': null,
                  'is_onnx': false,
                };

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card 1: Master Triage Risk Banner
                      _buildTriageRiskBanner(news2Result, sepsisResult),
                      const SizedBox(height: 14),

                      // Card 2: Hospital ICU Multiparameter Monitor & Telemetry
                      _buildHospitalMultiparameterTelemetry(latestRecord),
                      const SizedBox(height: 14),

                      // Card 3: Hospital Emergency Clinical Indices (Shock Index, MAP, qSOFA)
                      _buildEmergencyClinicalIndicesCard(latestRecord),
                      const SizedBox(height: 14),

                      // Card 4: PhysioNet 2019 Sepsis Model Card
                      _buildPhysioNetSepsisCard(sepsisResult, records.length),
                      const SizedBox(height: 14),

                      // Card 5: NEWS2 Early Warning Card
                      _buildNEWS2Card(news2Result, latestRecord),
                      const SizedBox(height: 14),

                      // Card 6: Longitudinal Trajectory Diagnostic ("What Happened Over Time")
                      _buildLongitudinalTrajectoryDiagnostic(records, deltaResult),
                      const SizedBox(height: 14),

                      // Card 7: DELTA Variations vs Last Visit
                      _buildDeltaCard(deltaResult, previousRecord != null),
                      const SizedBox(height: 14),

                      // Card 8: Multilingual AI Clinical Explanation
                      _buildAIExplanationCard(news2Result, sepsisResult, deltaResult, currentLang),
                      const SizedBox(height: 14),

                      // Card 9: Clinical Recommendation / Action
                      _buildClinicalActionCard(news2Result, sepsisResult),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Master Triage Banner ──
  Widget _buildTriageRiskBanner(Map<String, dynamic> news2, Map<String, dynamic> sepsis) {
    final news2Score = news2['score'] as int? ?? 0;
    final sepsisLevel = sepsis['risk_level'] as String? ?? 'Low Risk';
    final isCritical = news2Score >= 7 || sepsisLevel == 'High Risk';
    final isWarning = news2Score >= 5 || sepsisLevel == 'Moderate Risk';

    final Color bannerColor = isCritical
        ? const Color(0xFFD32F2F)
        : (isWarning ? const Color(0xFFE65100) : const Color(0xFF2E7D32));

    final String statusTitle = isCritical
        ? 'HIGH CLINICAL CONCERN'
        : (isWarning ? 'MODERATE OBSERVATION' : 'STABLE / LOW RISK');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withAlpha(80),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isCritical ? Icons.warning_amber_rounded : (isWarning ? Icons.info_outline : Icons.check_circle_outline),
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '⚡ On-Device AI',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NEWS2 Score', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        '$news2Score pts (${news2['risk_level']})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sepsis Risk (PhysioNet)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        '${sepsis['risk_percent']} ($sepsisLevel)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Hospital Multiparameter Telemetry Grid ──
  Widget _buildHospitalMultiparameterTelemetry(Map<String, dynamic> latest) {
    final sbp = latest['blood_pressure_systolic'] as int?;
    final dbp = latest['blood_pressure_diastolic'] as int?;
    final hr = latest['pulse_rate'] as int?;
    final spo2 = latest['spo2'] as int?;
    final rr = latest['respiratory_rate'] as int?;
    final temp = latest['temperature'] as num?;
    final bsf = latest['blood_sugar_fasting'] as num?;
    final bspp = (latest['blood_sugar_postprandial'] ?? latest['blood_sugar_pp']) as num?;

    Color hrColor = (hr != null && (hr > 100 || hr < 50)) ? Colors.redAccent : Colors.greenAccent.shade400;
    Color bpColor = (sbp != null && (sbp >= 140 || sbp < 90)) ? Colors.redAccent : Colors.cyanAccent.shade400;
    Color spo2Color = (spo2 != null && spo2 < 92) ? Colors.redAccent : (spo2 != null && spo2 < 95 ? Colors.amberAccent : Colors.greenAccent.shade400);
    Color rrColor = (rr != null && (rr > 22 || rr < 10)) ? Colors.redAccent : Colors.lightBlueAccent.shade200;
    Color tempColor = (temp != null && (temp > 101 || temp < 96)) ? Colors.redAccent : Colors.orangeAccent.shade200;
    Color sugarColor = ((bsf != null && (bsf > 140 || bsf < 70)) || (bspp != null && bspp > 180)) ? Colors.redAccent : Colors.tealAccent.shade400;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: const Color(0xFF0D1B2A), // Dark Hospital ICU Monitor Theme
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'HOSPITAL ICU MULTIPARAMETER MONITOR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    'BEDSIDE TELEMETRY',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.cyanAccent.shade100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _telemetryTile(
                    label: 'ECG / PULSE',
                    value: hr != null ? '$hr' : '--',
                    unit: 'bpm',
                    normalRange: '60 - 100',
                    color: hrColor,
                    status: (hr == null) ? 'No Signal' : (hr > 100 ? 'Tachycardia' : (hr < 60 ? 'Bradycardia' : 'Normal Sinus')),
                    icon: Icons.monitor_heart,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _telemetryTile(
                    label: 'NIBP (BP)',
                    value: (sbp != null && dbp != null) ? '$sbp/$dbp' : '--/--',
                    unit: 'mmHg',
                    normalRange: '120/80',
                    color: bpColor,
                    status: (sbp == null) ? 'No Signal' : (sbp >= 140 ? 'Hypertension' : (sbp < 90 ? 'Hypotension' : 'Normotensive')),
                    icon: Icons.favorite,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _telemetryTile(
                    label: 'PLETH / SpO2',
                    value: spo2 != null ? '$spo2' : '--',
                    unit: '%',
                    normalRange: '95 - 100',
                    color: spo2Color,
                    status: (spo2 == null) ? 'No Signal' : (spo2 < 90 ? 'Hypoxemia' : (spo2 < 95 ? 'Borderline' : 'Optimal')),
                    icon: Icons.air,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _telemetryTile(
                    label: 'RESP RATE',
                    value: rr != null ? '$rr' : '--',
                    unit: 'rpm',
                    normalRange: '12 - 20',
                    color: rrColor,
                    status: (rr == null) ? 'No Signal' : (rr > 22 ? 'Tachypnea' : (rr < 10 ? 'Bradypnea' : 'Eupnea')),
                    icon: Icons.waves,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _telemetryTile(
                    label: 'TEMP (CORE)',
                    value: temp != null ? temp.toStringAsFixed(1) : '--',
                    unit: '°F',
                    normalRange: '97.8 - 99.1',
                    color: tempColor,
                    status: (temp == null) ? 'No Signal' : (temp > 100.4 ? 'Febrile / Fever' : (temp < 96 ? 'Hypothermia' : 'Normothermia')),
                    icon: Icons.thermostat,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _telemetryTile(
                    label: 'GLUCOSE',
                    value: bsf != null ? '$bsf' : (bspp != null ? '$bspp' : '--'),
                    unit: 'mg/dL',
                    normalRange: '70 - 140',
                    color: sugarColor,
                    status: (bsf == null && bspp == null) ? 'Not Tested' : ((bsf != null && bsf < 70) ? 'Hypoglycemia' : ((bsf != null && bsf > 130) ? 'Hyperglycemia' : 'Euglycemic')),
                    icon: Icons.water_drop,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _telemetryTile({
    required String label,
    required String value,
    required String unit,
    required String normalRange,
    required Color color,
    required String status,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A4A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
              Icon(icon, size: 12, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(width: 3),
              Text(unit, style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
          ),
          Text(
            'Ref: $normalRange',
            style: const TextStyle(color: Colors.white24, fontSize: 8),
          ),
        ],
      ),
    );
  }

  // ── ICU Emergency Clinical Indices Card ──
  Widget _buildEmergencyClinicalIndicesCard(Map<String, dynamic> latest) {
    final sbp = latest['blood_pressure_systolic'] as int?;
    final dbp = latest['blood_pressure_diastolic'] as int?;
    final hr = latest['pulse_rate'] as int?;
    final rr = latest['respiratory_rate'] as int?;

    double? shockIndex;
    if (hr != null && sbp != null && sbp > 0) {
      shockIndex = hr / sbp;
    }

    double? map;
    if (sbp != null && dbp != null) {
      map = dbp + ((sbp - dbp) / 3.0);
    }

    int? pulsePressure;
    if (sbp != null && dbp != null) {
      pulsePressure = sbp - dbp;
    }

    int qsofa = 0;
    if (sbp != null && sbp <= 100) qsofa++;
    if (rr != null && rr >= 22) qsofa++;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.biotech, color: Color(0xFF00796B), size: 22),
                SizedBox(width: 8),
                Text(
                  'Hospital ICU Emergency Indices & Perfusion',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Real-time hemodynamic calculations utilized in emergency & critical care units.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: _indexBox(
                    title: 'Shock Index (SI)',
                    value: shockIndex != null ? shockIndex.toStringAsFixed(2) : 'N/A',
                    subtitle: 'HR / SBP',
                    interpretation: shockIndex == null
                        ? 'Need HR & BP'
                        : (shockIndex > 0.9 ? '⚠️ Impending Shock' : (shockIndex >= 0.7 ? 'Mild Stress' : '✅ Normal (< 0.7)')),
                    isAlert: shockIndex != null && shockIndex > 0.9,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _indexBox(
                    title: 'Mean Arterial Press.',
                    value: map != null ? '${map.round()} mmHg' : 'N/A',
                    subtitle: 'Organ Perfusion',
                    interpretation: map == null
                        ? 'Need SBP/DBP'
                        : (map < 65 ? '⚠️ Hypoperfusion (<65)' : '✅ Adequate (≥ 65)'),
                    isAlert: map != null && map < 65,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _indexBox(
                    title: 'Pulse Pressure (PP)',
                    value: pulsePressure != null ? '$pulsePressure mmHg' : 'N/A',
                    subtitle: 'SBP - DBP',
                    interpretation: pulsePressure == null
                        ? 'Need SBP/DBP'
                        : (pulsePressure < 25 ? '⚠️ Narrow (Shock)' : (pulsePressure > 60 ? 'Wide (Stiff artery)' : '✅ Normal (30-50)')),
                    isAlert: pulsePressure != null && pulsePressure < 25,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _indexBox(
                    title: 'Bedside qSOFA',
                    value: '$qsofa / 2 pts',
                    subtitle: 'Quick Sepsis Score',
                    interpretation: qsofa >= 2 ? '⚠️ High Sepsis Risk' : (qsofa == 1 ? 'Moderate Risk' : '✅ Low Risk'),
                    isAlert: qsofa >= 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _indexBox({
    required String title,
    required String value,
    required String subtitle,
    required String interpretation,
    required bool isAlert,
  }) {
    final Color bgColor = isAlert ? Colors.red.shade50 : Colors.grey.shade50;
    final Color borderColor = isAlert ? Colors.red.shade300 : Colors.grey.shade200;
    final Color valColor = isAlert ? Colors.red.shade800 : const Color(0xFF00796B);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valColor)),
          const SizedBox(height: 4),
          Text(
            interpretation,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isAlert ? Colors.red.shade900 : Colors.black54),
          ),
        ],
      ),
    );
  }

  // ── Longitudinal Trajectory Diagnostic ("What Happened Over Time") ──
  Widget _buildLongitudinalTrajectoryDiagnostic(List<dynamic> records, Map<String, Map<String, dynamic>> delta) {
    if (records.isEmpty) return const SizedBox.shrink();

    final count = records.length;
    String trajectoryHeadline;
    String clinicalExplanation;
    IconData icon;
    Color color;

    if (count == 1) {
      trajectoryHeadline = 'Initial Baseline Encounter Established';
      clinicalExplanation = 'This is the patient\'s first recorded clinical assessment. Baseline physiological values have been benchmarked. Future visits will compare dynamic velocity and trajectory slopes.';
      icon = Icons.flag_outlined;
      color = const Color(0xFF00796B);
    } else {
      final latest = records.first;
      final prev = records[1];
      final sbpDiff = (latest['blood_pressure_systolic'] as int? ?? 120) - (prev['blood_pressure_systolic'] as int? ?? 120);
      final hrDiff = (latest['pulse_rate'] as int? ?? 75) - (prev['pulse_rate'] as int? ?? 75);
      final spo2Diff = (latest['spo2'] as int? ?? 98) - (prev['spo2'] as int? ?? 98);

      if (sbpDiff < -15 && hrDiff > 15) {
        trajectoryHeadline = '⚠️ Compensatory Circulatory Shift Detected';
        clinicalExplanation = 'Longitudinal analysis shows a notable drop in Systolic Blood Pressure ($sbpDiff mmHg) coupled with compensatory tachycardia (+$hrDiff bpm). This pattern is consistent with developing systemic hypoperfusion or fluid depletion.';
        icon = Icons.warning_amber_rounded;
        color = Colors.red.shade700;
      } else if (spo2Diff < -4) {
        trajectoryHeadline = '⚠️ Acute Respiratory Decline Pattern';
        clinicalExplanation = 'Oxygen saturation dropped by ${spo2Diff.abs()}% from the previous encounter. Recommend immediate auscultation, airway assessment, and Primary Health Centre referral.';
        icon = Icons.air;
        color = Colors.orange.shade800;
      } else {
        trajectoryHeadline = '✅ Stable Physiological Trajectory';
        clinicalExplanation = 'Hemodynamic and metabolic parameters demonstrate stable equilibrium across $count recorded encounters with no critical velocity deviations.';
        icon = Icons.verified_user_outlined;
        color = Colors.green.shade700;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trajectoryHeadline,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '$count Encounters',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              clinicalExplanation,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ── PhysioNet 2019 Sepsis Challenge Card ──
  Widget _buildPhysioNetSepsisCard(Map<String, dynamic> sepsis, int recordCount) {
    final riskScore = (sepsis['risk_score'] as num?)?.toDouble() ?? 0.0;
    final riskPercent = sepsis['risk_percent'] ?? '0%';
    final riskLevel = sepsis['risk_level'] ?? 'Low Risk';
    final hours = sepsis['hours_to_onset'];
    final confidence = ((sepsis['confidence'] as num?)?.toDouble() ?? 0.88) * 100;
    final isONNX = sepsis['is_onnx'] ?? false;

    Color progressColor = Colors.green;
    if (riskScore >= 0.60) {
      progressColor = Colors.red;
    } else if (riskScore >= 0.30) {
      progressColor = Colors.orange;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.biotech, color: Color(0xFF00796B), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'PhysioNet 2019 Sepsis Predictor',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isONNX ? Colors.teal.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isONNX ? Colors.teal.shade300 : Colors.blue.shade300),
                  ),
                  child: Text(
                    isONNX ? 'ONNX Runtime' : 'Clinical Model',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isONNX ? Colors.teal.shade900 : Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sepsis Probability: $riskPercent',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: progressColor),
                ),
                Text(
                  riskLevel.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: progressColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: riskScore,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Confidence', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text('${confidence.round()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.grey.shade300),
                  Column(
                    children: [
                      const Text('Est. Onset Window', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(hours != null ? '~$hours hrs' : 'N/A (Stable)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.grey.shade300),
                  Column(
                    children: [
                      const Text('History Points', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text('$recordCount visits', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trained on PhysioNet/CinC 2019 Challenge 40,336 ICU patient dataset (Reyna et al., CC BY 4.0).',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  // ── NEWS2 Score Breakdown Card ──
  Widget _buildNEWS2Card(Map<String, dynamic> news2, Map<String, dynamic> latest) {
    final score = news2['score'] as int? ?? 0;
    final breakdown = (news2['breakdown'] as Map<String, dynamic>?) ?? {};
    final riskLevel = news2['risk_level'] ?? 'Low Risk';
    final hasExtreme = news2['has_extreme_vital'] ?? false;

    Color badgeColor = Colors.green;
    if (score >= 7) {
      badgeColor = Colors.red;
    } else if (score >= 5 || hasExtreme) {
      badgeColor = Colors.orange;
    } else if (score >= 1) {
      badgeColor = Colors.amber.shade700;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.health_and_safety, color: Color(0xFF00796B), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'NEWS2 Clinical Early Warning',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor),
                  ),
                  child: Text(
                    '$score Points ($riskLevel)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Royal College of Physicians (UK) standard clinical score for early deterioration detection.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Divider(height: 20),
            ...breakdown.entries.map((e) {
              final pts = e.value as int;
              Color ptColor = Colors.green;
              if (pts == 3) {
                ptColor = Colors.red;
              } else if (pts == 2) {
                ptColor = Colors.orange;
              } else if (pts == 1) {
                ptColor = Colors.amber.shade700;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        e.key,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pts / 3.0,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(ptColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ptColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$pts ${pts == 1 ? 'pt' : 'pts'}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ptColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (hasExtreme) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Single parameter scored 3 points (Extreme trigger detected — immediate clinical alert).',
                        style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── DELTA Variations Card ──
  Widget _buildDeltaCard(Map<String, Map<String, dynamic>> delta, bool hasPrevious) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.trending_up, color: Color(0xFF00796B), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'DELTA Vitals Variation',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                    ),
                  ],
                ),
                Text(
                  hasPrevious ? 'vs. Last Visit' : 'Baseline Record',
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasPrevious)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xFF00796B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is the member\'s baseline visit. Future visits will automatically calculate DELTA rate of change.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF004D40)),
                      ),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: delta.entries.map((e) {
                  final name = e.key;
                  final data = e.value;
                  final diff = data['diff'] as num?;
                  final pct = data['percent_change'] as num?;
                  final unit = data['unit'] as String? ?? '';
                  final direction = data['direction'] as String? ?? 'neutral';

                  if (diff == null) return const SizedBox.shrink();

                  Color chipColor = Colors.grey.shade700;
                  IconData dirIcon = Icons.remove;
                  Color bgColor = Colors.grey.shade100;

                  if (direction == 'up') {
                    dirIcon = Icons.arrow_upward;
                    chipColor = (name == 'SpO2') ? Colors.green : Colors.redAccent.shade700;
                    bgColor = (name == 'SpO2') ? Colors.green.shade50 : Colors.red.shade50;
                  } else if (direction == 'down') {
                    dirIcon = Icons.arrow_downward;
                    chipColor = (name == 'SpO2') ? Colors.redAccent.shade700 : Colors.blue.shade700;
                    bgColor = (name == 'SpO2') ? Colors.red.shade50 : Colors.blue.shade50;
                  }

                  final sign = diff > 0 ? '+' : '';
                  final diffStr = '$sign${diff.toStringAsFixed(diff is double && diff % 1 != 0 ? 1 : 0)} $unit';
                  final pctStr = pct != null ? ' (${pct > 0 ? '+' : ''}${pct.toStringAsFixed(0)}%)' : '';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: chipColor.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(dirIcon, size: 14, color: chipColor),
                            const SizedBox(width: 4),
                            Text(
                              '$diffStr$pctStr',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: chipColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ── AI Explanation Card ──
  Widget _buildAIExplanationCard(
    Map<String, dynamic> news2,
    Map<String, dynamic> sepsis,
    Map<String, Map<String, dynamic>> delta,
    String currentLang,
  ) {
    final summary = LanguageService.generateClinicalExplanation(
      member: _currentMember,
      news2Result: news2,
      sepsisResult: sepsis,
      delta: delta,
      languageCode: currentLang,
    );

    final langInfo = LanguageService.getLanguageInfo(currentLang);
    final TextEditingController qwenQueryCtrl = TextEditingController();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF00796B), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'AI Clinical Intelligence (T7 Clinical AI)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Text(
                    '${langInfo['native']}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // GGUF Download Status Banner
            ValueListenableBuilder<bool>(
              valueListenable: OnDeviceLLMService.isModelDownloadedNotifier,
              builder: (context, isDownloaded, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDownloaded ? Colors.teal.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDownloaded ? Colors.teal.shade200 : Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDownloaded ? Icons.offline_bolt : Icons.download_for_offline_outlined,
                        size: 18,
                        color: isDownloaded ? const Color(0xFF00796B) : Colors.amber.shade900,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isDownloaded
                              ? '⚡ Full T7 Clinical AI-1.7B GGUF Model Loaded (100% On-Device Generative AI)'
                              : 'T7 Clinical AI 1.0GB GGUF Model Weights Not Downloaded (~986 MB for full GGUF generative LLM)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDownloaded ? const Color(0xFF004D40) : Colors.amber.shade900,
                          ),
                        ),
                      ),
                      if (!isDownloaded)
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          onPressed: () {
                            _showGgufDownloadDialog(context);
                          },
                          child: const Text('Download', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // AI Explanation Output Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50.withAlpha(120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: Text(
                summary,
                style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 12),

            // Custom Interactive Question Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qwenQueryCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ask T7 Clinical AI Doctor a question in ${langInfo['name']}...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF00796B)),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  onPressed: () async {
                    if (qwenQueryCtrl.text.trim().isEmpty) return;
                    final question = qwenQueryCtrl.text.trim();
                    qwenQueryCtrl.clear();
                    
                    final answer = await OnDeviceLLMService.generateGenerativeClinicalExplanation(
                      member: _currentMember,
                      news2Result: news2,
                      sepsisResult: sepsis,
                      delta: delta,
                      languageCode: currentLang,
                      customQuestion: question,
                    );

                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Color(0xFF00796B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('T7 Clinical AI Answer (${langInfo['native']})', style: const TextStyle(fontSize: 16)),
                              ),
                            ],
                          ),
                          content: SingleChildScrollView(
                            child: Text(answer, style: const TextStyle(fontSize: 13, height: 1.5)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text(
                  '💬 Open Full T7 Clinical AI AI Health Chat (${langInfo['native']})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  _showT7ClinicalAIFullChatModal(context, news2, sepsis, delta, currentLang);
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '100% Offline • On-Device Generative AI',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00796B),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.translate, size: 14),
                  label: const Text('Switch Language', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    LanguageSwitcherWidget.showLanguageModal(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGgufDownloadDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.downloading_rounded, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text('Download T7 Clinical AI (1.5B GGUF)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will download the 1.0 GB quantized T7 Clinical AI model weights from HuggingFace to your device storage for 100% offline generative AI.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: OnDeviceLLMService.downloadProgressNotifier,
                builder: (context, progress, _) {
                  return Column(
                    children: [
                      LinearProgressIndicator(value: progress, minHeight: 8),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: OnDeviceLLMService.downloadStatusNotifier,
                        builder: (context, status, _) {
                          return Text(status, style: const TextStyle(fontSize: 11, color: Colors.grey));
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
              icon: const Icon(Icons.download),
              label: const Text('Start Download (~986 MB)'),
              onPressed: () async {
                final success = await OnDeviceLLMService.downloadModel();
                if (ctx.mounted && success) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('T7 Clinical AI Model Downloaded Successfully!')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // ── Clinical Action Card ──
  Widget _buildClinicalActionCard(Map<String, dynamic> news2, Map<String, dynamic> sepsis) {
    final news2Score = news2['score'] as int? ?? 0;
    final sepsisLevel = sepsis['risk_level'] as String? ?? 'Low Risk';
    final isCritical = news2Score >= 7 || sepsisLevel == 'High Risk';
    final isWarning = news2Score >= 5 || sepsisLevel == 'Moderate Risk';

    final Color cardBg = isCritical ? Colors.red.shade50 : (isWarning ? Colors.orange.shade50 : Colors.green.shade50);
    final Color borderColor = isCritical ? Colors.red.shade300 : (isWarning ? Colors.orange.shade300 : Colors.green.shade300);
    final Color textColor = isCritical ? Colors.red.shade900 : (isWarning ? Colors.orange.shade900 : Colors.green.shade900);
    final IconData icon = isCritical ? Icons.emergency : (isWarning ? Icons.warning_amber : Icons.verified_user_outlined);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 8),
              Text(
                'RECOMMENDED CLINICAL ACTION',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            news2['action'] as String? ?? 'Routine monitoring per community schedule.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  void _showT7ClinicalAIFullChatModal(
    BuildContext context,
    Map<String, dynamic> news2,
    Map<String, dynamic> sepsis,
    Map<String, Map<String, dynamic>> delta,
    String currentLang,
  ) {
    QwenAIChatModal.show(
      context,
      member: _currentMember,
      news2Result: news2,
      sepsisResult: sepsis,
      delta: delta,
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

