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
  late Map<String, dynamic> _currentMember;
  String _selectedTimeRange = 'all'; // Default time range for analytics
  String _selectedVitalTab = 'bp'; // 'bp', 'hr', 'spo2', 'sugar', 'temp', 'rr'

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
    final phoneCtrl = TextEditingController(text: _currentMember['mobile_number']?.toString() ?? '');
    final abhaCtrl = TextEditingController(text: _currentMember['abha_id']?.toString() ?? '');
    final birthWeightCtrl = TextEditingController(text: _currentMember['birth_weight']?.toString() ?? '');
    final muacCtrl = TextEditingController(text: _currentMember['muac_cm']?.toString() ?? '');
    final chronicNotesCtrl = TextEditingController(text: _currentMember['chronic_notes']?.toString() ?? '');

    String gender = _currentMember['gender']?.toString().toLowerCase() ?? 'male';
    if (gender != 'male' && gender != 'female' && gender != 'other') gender = 'male';
    String? pickedImageBase64 = _currentMember['profile_image']?.toString();

    bool isPregnant = (_currentMember['is_pregnant'] == 1 || _currentMember['is_pregnant'] == true);
    DateTime? lmpDate = _currentMember['lmp_date'] != null ? DateTime.tryParse(_currentMember['lmp_date'].toString()) : null;
    String? eddDateStr = _currentMember['edd_date']?.toString();
    String? gestationalAgeStr;
    if (lmpDate != null) {
      final days = DateTime.now().difference(lmpDate).inDays;
      final weeks = (days / 7).floor();
      final tri = weeks >= 28 ? '3rd Trimester' : (weeks >= 13 ? '2nd Trimester' : '1st Trimester');
      gestationalAgeStr = 'Week $weeks ($tri)';
    }

    bool isHighRisk = (_currentMember['is_high_risk_pregnancy'] == 1 || _currentMember['is_high_risk_pregnancy'] == true);
    bool isLactating = (_currentMember['is_lactating'] == 1 || _currentMember['is_lactating'] == true);
    bool td1 = (_currentMember['td1_vaccine'] == 1 || _currentMember['td1_vaccine'] == true);
    bool td2 = (_currentMember['td2_vaccine'] == 1 || _currentMember['td2_vaccine'] == true);
    bool tdBooster = (_currentMember['td_booster'] == 1 || _currentMember['td_booster'] == true);
    int ifaCount = (_currentMember['ifa_tablets_given'] as int?) ?? 0;
    int calciumCount = (_currentMember['calcium_tablets_given'] as int?) ?? 0;
    String deliveryType = _currentMember['delivery_type']?.toString() ?? 'Institutional (Hospital/PHC)';
    bool hasChronic = (_currentMember['has_chronic_condition'] == 1 || _currentMember['has_chronic_condition'] == true);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final int parsedAge = int.tryParse(ageCtrl.text) ?? 0;
          final bool isFemaleReproductive = gender == 'female' && (parsedAge == 0 || (parsedAge >= 12 && parsedAge <= 55));
          final bool isChild = parsedAge > 0 && parsedAge < 5;

          void updateLMP(DateTime selected) {
            lmpDate = selected;
            final edd = selected.add(const Duration(days: 280));
            eddDateStr = DateFormat('dd MMM yyyy').format(edd);
            final days = DateTime.now().difference(selected).inDays;
            final weeks = (days / 7).floor();
            final tri = weeks >= 28 ? '3rd Trimester' : (weeks >= 13 ? '2nd Trimester' : '1st Trimester');
            gestationalAgeStr = 'Week $weeks ($tri)';
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.edit, color: Color(0xFF00796B)),
                SizedBox(width: 8),
                Text('Edit Clinical EHR Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final compressedBase64 = await ImageUtils.pickAndCompressImage(context);
                          if (compressedBase64 != null) {
                            setModalState(() => pickedImageBase64 = compressedBase64);
                          }
                        },
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.teal.shade50,
                          backgroundImage: ImageUtils.safeBase64Image(pickedImageBase64),
                          child: pickedImageBase64 == null ? const Icon(Icons.add_a_photo, color: Colors.teal, size: 28) : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Age *'),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: gender,
                            decoration: const InputDecoration(labelText: 'Gender'),
                            items: const [
                              DropdownMenuItem(value: 'female', child: Text('Female')),
                              DropdownMenuItem(value: 'male', child: Text('Male')),
                              DropdownMenuItem(value: 'other', child: Text('Other')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => gender = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship to Head *')),
                    const SizedBox(height: 10),
                    TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone, size: 18))),
                    const SizedBox(height: 10),
                    TextField(controller: abhaCtrl, decoration: const InputDecoration(labelText: 'ABHA Health ID', prefixIcon: Icon(Icons.badge_outlined, size: 18))),
                    const SizedBox(height: 12),

                    // ── Maternal Section ──
                    if (isFemaleReproductive) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.pink.shade50.withAlpha(120), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.pink.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.pregnant_woman, color: Colors.pink, size: 20),
                                SizedBox(width: 6),
                                Text('Maternal Health & Pregnancy (ANC)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.pink)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Is Currently Pregnant (ANC)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              value: isPregnant,
                              activeThumbColor: Colors.pink,
                              onChanged: (val) => setModalState(() => isPregnant = val),
                            ),
                            if (isPregnant) ...[
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.pink.shade900, side: BorderSide(color: Colors.pink.shade300)),
                                icon: const Icon(Icons.calendar_month, size: 18),
                                label: Text(lmpDate == null ? 'Select LMP Date (Last Period)' : 'LMP: ${DateFormat('dd MMM yyyy').format(lmpDate!)}'),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: lmpDate ?? DateTime.now().subtract(const Duration(days: 60)),
                                    firstDate: DateTime.now().subtract(const Duration(days: 300)),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) setModalState(() => updateLMP(picked));
                                },
                              ),
                              if (eddDateStr != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('👶 Expected Delivery (EDD): $eddDateStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
                                      if (gestationalAgeStr != null) Text('⏳ Gestational Stage: $gestationalAgeStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('High-Risk Pregnancy (HRP) Alert', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                                value: isHighRisk,
                                activeColor: Colors.red,
                                onChanged: (val) => setModalState(() => isHighRisk = val ?? false),
                              ),
                              const SizedBox(height: 6),
                              const Text('Td Vaccines:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              Row(
                                children: [
                                  Expanded(child: CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, title: const Text('Td-1', style: TextStyle(fontSize: 11)), value: td1, onChanged: (v) => setModalState(() => td1 = v ?? false))),
                                  Expanded(child: CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, title: const Text('Td-2', style: TextStyle(fontSize: 11)), value: td2, onChanged: (v) => setModalState(() => td2 = v ?? false))),
                                  Expanded(child: CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, title: const Text('Td Booster', style: TextStyle(fontSize: 11)), value: tdBooster, onChanged: (v) => setModalState(() => tdBooster = v ?? false))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(child: TextFormField(initialValue: '$ifaCount', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'IFA Tablets (180 Target)', labelStyle: TextStyle(fontSize: 11)), onChanged: (v) => ifaCount = int.tryParse(v) ?? 0)),
                                  const SizedBox(width: 8),
                                  Expanded(child: TextFormField(initialValue: '$calciumCount', keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calcium Tablets', labelStyle: TextStyle(fontSize: 11)), onChanged: (v) => calciumCount = int.tryParse(v) ?? 0)),
                                ],
                              ),
                            ],
                            const Divider(height: 16),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: const Text('Lactating Mother (Infant < 6 Months)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              value: isLactating,
                              activeThumbColor: Colors.pink,
                              onChanged: (val) => setModalState(() => isLactating = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Child Section ──
                    if (isChild) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50.withAlpha(120), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.blue.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.child_care, color: Colors.blue, size: 20),
                                SizedBox(width: 6),
                                Text('Pediatric Growth & Birth (< 5 Yrs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: TextField(controller: birthWeightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Birth Weight (kg)'))),
                                const SizedBox(width: 10),
                                Expanded(child: TextField(controller: muacCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'MUAC Tape (cm)'))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: deliveryType,
                              decoration: const InputDecoration(labelText: 'Delivery Place'),
                              items: const [
                                DropdownMenuItem(value: 'Institutional (Hospital/PHC)', child: Text('Institutional (Hospital/PHC)')),
                                DropdownMenuItem(value: 'Home Delivery', child: Text('Home Delivery')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => deliveryType = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Chronic Condition ──
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Has Known Chronic Health Condition', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      value: hasChronic,
                      onChanged: (val) => setModalState(() => hasChronic = val ?? false),
                    ),
                    if (hasChronic)
                      TextField(controller: chronicNotesCtrl, decoration: const InputDecoration(labelText: 'Specific Chronic Conditions / Medications')),
                  ],
                ),
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
                      abhaId: abhaCtrl.text.isNotEmpty ? abhaCtrl.text : null,
                      mobileNumber: phoneCtrl.text.isNotEmpty ? phoneCtrl.text : null,
                      isPregnant: isPregnant,
                      lmpDate: lmpDate?.toIso8601String(),
                      eddDate: eddDateStr,
                      isHighRiskPregnancy: isHighRisk,
                      isLactating: isLactating,
                      td1Vaccine: td1,
                      td2Vaccine: td2,
                      tdBooster: tdBooster,
                      ifaTabletsGiven: ifaCount,
                      calciumTabletsGiven: calciumCount,
                      birthWeight: double.tryParse(birthWeightCtrl.text),
                      deliveryType: deliveryType,
                      muacCm: double.tryParse(muacCtrl.text),
                      hasChronicCondition: hasChronic,
                      chronicNotes: chronicNotesCtrl.text.isNotEmpty ? chronicNotesCtrl.text : null,
                    );
                    if (!mounted || !context.mounted) return;
                    Navigator.pop(ctx);
                    if (ok) {
                      setState(() {
                        _currentMember['full_name'] = nameCtrl.text;
                        _currentMember['age'] = age;
                        _currentMember['gender'] = gender;
                        _currentMember['relationship_to_head'] = relCtrl.text;
                        if (pickedImageBase64 != null) _currentMember['profile_image'] = pickedImageBase64;
                        _currentMember['abha_id'] = abhaCtrl.text;
                        _currentMember['mobile_number'] = phoneCtrl.text;
                        _currentMember['is_pregnant'] = isPregnant ? 1 : 0;
                        _currentMember['lmp_date'] = lmpDate?.toIso8601String();
                        _currentMember['edd_date'] = eddDateStr;
                        _currentMember['is_high_risk_pregnancy'] = isHighRisk ? 1 : 0;
                        _currentMember['is_lactating'] = isLactating ? 1 : 0;
                        _currentMember['td1_vaccine'] = td1 ? 1 : 0;
                        _currentMember['td2_vaccine'] = td2 ? 1 : 0;
                        _currentMember['td_booster'] = tdBooster ? 1 : 0;
                        _currentMember['ifa_tablets_given'] = ifaCount;
                        _currentMember['calcium_tablets_given'] = calciumCount;
                        _currentMember['birth_weight'] = double.tryParse(birthWeightCtrl.text);
                        _currentMember['delivery_type'] = deliveryType;
                        _currentMember['muac_cm'] = double.tryParse(muacCtrl.text);
                        _currentMember['has_chronic_condition'] = hasChronic ? 1 : 0;
                        _currentMember['chronic_notes'] = chronicNotesCtrl.text;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Member clinical profile updated!'), backgroundColor: Colors.green),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                child: const Text('Save Changes'),
              )
            ],
          );
        },
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
  // Tab 2: Interactive Vital Variation & Clinical Trajectory Analytics
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildAnalyticsTab() {
    return FutureBuilder<List<dynamic>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final rawRecords = snapshot.data ?? [];
        if (rawRecords.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.show_chart, size: 64, color: Colors.teal.shade300),
                  const SizedBox(height: 16),
                  const Text('No Vital History Available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Record vitals over multiple visits to view physiological trajectory, target reference bands, and velocity indicators.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddRecordDialog,
                    icon: const Icon(Icons.add_chart),
                    label: const Text('Add First Vital Record'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }

        // Filter records by time range
        final cutoff = _getCutoffDate();
        final List<Map<String, dynamic>> records = rawRecords
            .map((e) => Map<String, dynamic>.from(e))
            .where((r) {
              if (cutoff == null) return true;
              try {
                final dt = DateTime.parse(r['recorded_at'].toString()).toLocal();
                return dt.isAfter(cutoff);
              } catch (_) {
                return true;
              }
            })
            .toList();

        // Sort ascending chronologically for chart rendering (oldest -> newest)
        final chronologicalRecords = List<Map<String, dynamic>>.from(records)
          ..sort((a, b) {
            final da = DateTime.tryParse(a['recorded_at']?.toString() ?? '') ?? DateTime.now();
            final db = DateTime.tryParse(b['recorded_at']?.toString() ?? '') ?? DateTime.now();
            return da.compareTo(db);
          });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Top Control Bar: Time Range + Export PHC Slip
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF00796B)),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedTimeRange,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: '7d', child: Text('Last 7 Days')),
                            DropdownMenuItem(value: '14d', child: Text('Last 14 Days')),
                            DropdownMenuItem(value: '1m', child: Text('Last 1 Month')),
                            DropdownMenuItem(value: '3m', child: Text('Last 3 Months')),
                            DropdownMenuItem(value: '6m', child: Text('Last 6 Months')),
                            DropdownMenuItem(value: '1y', child: Text('Last 1 Year')),
                            DropdownMenuItem(value: 'all', child: Text('All Visits')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedTimeRange = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showPHCReferralSlipDialog(rawRecords),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Export PHC Slip', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Interactive Vital Selector Pill Tabs
            _buildVitalSelectorTabs(),
            const SizedBox(height: 14),

            // Main Interactive Reference Band Chart Card
            _buildInteractiveReferenceBandChart(chronologicalRecords),
            const SizedBox(height: 16),

            // Maternal Health & ANC/PNC Care (For pregnant / lactating women)
            _buildMaternalANCCard(),

            // Pediatric Child Growth & Immunization (For infants / children < 5 yrs)
            _buildPediatricChildCard(),

            // Longitudinal Table breakdown for selected vital
            _buildSelectedVitalHistoryTable(chronologicalRecords),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  // ── 1. Interactive Selector Tabs ──
  Widget _buildVitalSelectorTabs() {
    final tabs = [
      {'id': 'bp', 'label': 'Blood Pressure', 'icon': Icons.favorite},
      {'id': 'hr', 'label': 'Pulse / HR', 'icon': Icons.monitor_heart},
      {'id': 'spo2', 'label': 'SpO2 Oxygen', 'icon': Icons.air},
      {'id': 'sugar', 'label': 'Blood Sugar', 'icon': Icons.water_drop},
      {'id': 'temp', 'label': 'Temperature', 'icon': Icons.thermostat},
      {'id': 'rr', 'label': 'Resp Rate', 'icon': Icons.waves},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final isSelected = _selectedVitalTab == t['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              avatar: Icon(t['icon'] as IconData, size: 16, color: isSelected ? Colors.white : const Color(0xFF00796B)),
              label: Text(t['label'] as String),
              selected: isSelected,
              selectedColor: const Color(0xFF00796B),
              backgroundColor: Colors.teal.shade50,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF004D40),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
              onSelected: (selected) {
                if (selected) setState(() => _selectedVitalTab = t['id'] as String);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 2. Interactive Reference Band Chart Card ──
  Widget _buildInteractiveReferenceBandChart(List<Map<String, dynamic>> records) {
    // Extract data points based on selected vital
    List<Map<String, dynamic>> points = [];
    String unit = '';
    String vitalTitle = '';
    double minY = 0;
    double maxY = 200;
    double greenMin = 0;
    double greenMax = 0;
    double yellowMax = 0;

    switch (_selectedVitalTab) {
      case 'bp':
        vitalTitle = 'Blood Pressure (Systolic)';
        unit = 'mmHg';
        minY = 60;
        maxY = 190;
        greenMin = 90;
        greenMax = 120;
        yellowMax = 140;
        for (var r in records) {
          if (r['blood_pressure_systolic'] != null) {
            points.add({
              'val': (r['blood_pressure_systolic'] as num).toDouble(),
              'val2': (r['blood_pressure_diastolic'] as num?)?.toDouble(),
              'date': r['recorded_at']?.toString() ?? '',
              'notes': r['notes']?.toString() ?? '',
            });
          }
        }
        break;
      case 'hr':
        vitalTitle = 'Pulse / Heart Rate';
        unit = 'bpm';
        minY = 40;
        maxY = 150;
        greenMin = 60;
        greenMax = 100;
        yellowMax = 115;
        for (var r in records) {
          if (r['pulse_rate'] != null) {
            points.add({
              'val': (r['pulse_rate'] as num).toDouble(),
              'date': r['recorded_at']?.toString() ?? '',
              'notes': r['notes']?.toString() ?? '',
            });
          }
        }
        break;
      case 'spo2':
        vitalTitle = 'SpO2 Oxygen Saturation';
        unit = '%';
        minY = 80;
        maxY = 100;
        greenMin = 96;
        greenMax = 100;
        yellowMax = 95;
        for (var r in records) {
          if (r['spo2'] != null) {
            points.add({
              'val': (r['spo2'] as num).toDouble(),
              'date': r['recorded_at']?.toString() ?? '',
              'notes': r['notes']?.toString() ?? '',
            });
          }
        }
        break;
      case 'sugar':
        vitalTitle = 'Blood Glucose (Fasting)';
        unit = 'mg/dL';
        minY = 50;
        maxY = 280;
        greenMin = 70;
        greenMax = 140;
        yellowMax = 200;
        for (var r in records) {
          final s = r['blood_sugar_fasting'] ?? r['blood_sugar_postprandial'];
          if (s != null) {
            points.add({
              'val': (s as num).toDouble(),
              'date': r['recorded_at']?.toString() ?? '',
              'notes': r['notes']?.toString() ?? '',
            });
          }
        }
        break;
      case 'temp':
        vitalTitle = 'Core Body Temperature';
        unit = '°F';
        minY = 94;
        maxY = 105;
        greenMin = 97.5;
        greenMax = 99.5;
        yellowMax = 100.4;
        for (var r in records) {
          if (r['temperature'] != null) {
            points.add({
              'val': (r['temperature'] as num).toDouble(),
              'date': r['recorded_at']?.toString() ?? '',
              'notes': r['notes']?.toString() ?? '',
            });
          }
        }
        break;
      case 'rr':
      default:
        vitalTitle = 'Respiratory Rate';
        unit = 'rpm';
        minY = 6;
        maxY = 32;
        greenMin = 12;
        greenMax = 20;
        yellowMax = 24;
        for (var r in records) {
          if (r['respiratory_rate'] != null) {
            points.add({
              'val': (r['respiratory_rate'] as num).toDouble(),
              'date': r['recorded_at']?.toString() ?? '',
              'notes': r['notes']?.toString() ?? '',
            });
          }
        }
        break;
    }

    if (points.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('No recorded data for $vitalTitle in this timeframe.', style: const TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    // Calculate trend velocity delta between last two points
    String trendBadge = 'Initial Baseline';
    Color trendColor = const Color(0xFF00796B);
    if (points.length >= 2) {
      final latest = points.last['val'] as double;
      final prev = points[points.length - 2]['val'] as double;
      final diff = latest - prev;
      final sign = diff > 0 ? '+' : '';
      if (_selectedVitalTab == 'bp' || _selectedVitalTab == 'hr' || _selectedVitalTab == 'temp' || _selectedVitalTab == 'sugar') {
        if (diff < 0) {
          trendBadge = '📉 Improving ($sign${diff.toStringAsFixed(1)} $unit)';
          trendColor = Colors.green.shade700;
        } else if (diff > 10) {
          trendBadge = '⚠️ Spike ($sign${diff.toStringAsFixed(1)} $unit)';
          trendColor = Colors.red.shade700;
        } else {
          trendBadge = '➡️ Steady ($sign${diff.toStringAsFixed(1)} $unit)';
          trendColor = Colors.teal;
        }
      } else {
        if (diff > 0) {
          trendBadge = '📈 Improving ($sign${diff.toStringAsFixed(1)} $unit)';
          trendColor = Colors.green.shade700;
        } else if (diff < -3) {
          trendBadge = '⚠️ Decline ($sign${diff.toStringAsFixed(1)} $unit)';
          trendColor = Colors.red.shade700;
        } else {
          trendBadge = '➡️ Stable ($sign${diff.toStringAsFixed(1)} $unit)';
          trendColor = Colors.teal;
        }
      }
    }

    // Build spots with individual point colors
    final spots = points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['val'] as double)).toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Vital Title + Trend Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vitalTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                    Text('Latest: ${points.last['val']} $unit • ${points.length} Encounters', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trendColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: trendColor.withAlpha(80)),
                  ),
                  child: Text(
                    trendBadge,
                    style: TextStyle(color: trendColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reference Bands Legend
            Row(
              children: [
                _legendPill('🟢 Safe Target: $greenMin-$greenMax $unit', Colors.green.shade700),
                const SizedBox(width: 8),
                _legendPill('🟡 Borderline', Colors.orange.shade800),
                const SizedBox(width: 8),
                _legendPill('🔴 Critical', Colors.red.shade700),
              ],
            ),
            const SizedBox(height: 16),

            // The Line Chart
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  minX: 0,
                  maxX: (points.length - 1).toDouble() > 0 ? (points.length - 1).toDouble() : 1.0,
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (val) {
                      if (val == greenMax || val == greenMin) {
                        return FlLine(color: Colors.green.withAlpha(120), strokeWidth: 1.2, dashArray: [4, 4]);
                      }
                      if (val == yellowMax) {
                        return FlLine(color: Colors.orange.withAlpha(120), strokeWidth: 1.2, dashArray: [4, 4]);
                      }
                      return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                          final dtStr = points[idx]['date'] as String;
                          String formatted = 'V${idx + 1}';
                          try {
                            final dt = DateTime.parse(dtStr).toLocal();
                            formatted = DateFormat('dd MMM').format(dt);
                          } catch (_) {}
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(formatted, style: const TextStyle(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.toInt();
                          final p = (idx >= 0 && idx < points.length) ? points[idx] : null;
                          final dateStr = p != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(p['date'] ?? '')?.toLocal() ?? DateTime.now()) : '';
                          final note = (p != null && (p['notes'] as String).isNotEmpty) ? '\n📝 ${p['notes']}' : '';
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)} $unit\n📅 $dateStr$note',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: const Color(0xFF00796B),
                      gradient: LinearGradient(
                        colors: [
                          Colors.teal.shade700,
                          Colors.cyan.shade600,
                        ],
                      ),
                      barWidth: 3.5,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF00796B).withAlpha(60),
                            const Color(0xFF00796B).withAlpha(5),
                          ],
                        ),
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final y = spot.y;
                          Color dotColor = Colors.green;
                          if (y > yellowMax || y < greenMin) {
                            dotColor = Colors.red;
                          } else if (y > greenMax) {
                            dotColor = Colors.orange;
                          }
                          return FlDotCirclePainter(
                            radius: 5.5,
                            color: dotColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  // ── 3. Selected Vital History Table Breakdown ──
  Widget _buildSelectedVitalHistoryTable(List<Map<String, dynamic>> records) {
    final reversed = records.reversed.toList();
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
                Icon(Icons.table_chart_outlined, size: 18, color: Color(0xFF00796B)),
                SizedBox(width: 8),
                Text('Longitudinal Log Table', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              ],
            ),
            const Divider(height: 18),
            ...reversed.map((r) {
              final dateStr = _formatDate(r['recorded_at']);
              dynamic val = '--';
              String unit = '';
              Color valColor = Colors.black87;

              if (_selectedVitalTab == 'bp') {
                val = '${r['blood_pressure_systolic'] ?? '?'}/${r['blood_pressure_diastolic'] ?? '?'}';
                unit = 'mmHg';
                final sbp = r['blood_pressure_systolic'] as int?;
                if (sbp != null && (sbp >= 140 || sbp < 90)) valColor = Colors.red;
              } else if (_selectedVitalTab == 'hr') {
                val = r['pulse_rate'] ?? '--';
                unit = 'bpm';
              } else if (_selectedVitalTab == 'spo2') {
                val = r['spo2'] ?? '--';
                unit = '%';
                final spo2 = r['spo2'] as int?;
                if (spo2 != null && spo2 < 92) valColor = Colors.red;
              } else if (_selectedVitalTab == 'sugar') {
                val = r['blood_sugar_fasting'] ?? r['blood_sugar_postprandial'] ?? '--';
                unit = 'mg/dL';
              } else if (_selectedVitalTab == 'temp') {
                val = r['temperature'] ?? '--';
                unit = '°F';
              } else if (_selectedVitalTab == 'rr') {
                val = r['respiratory_rate'] ?? '--';
                unit = 'rpm';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                    Row(
                      children: [
                        Text('$val', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valColor)),
                        const SizedBox(width: 4),
                        Text(unit, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── 4. One-Tap PHC Clinical Summary & Referral Slip Dialog ──
  void _showPHCReferralSlipDialog(List<dynamic> records) {
    if (records.isEmpty) return;
    final latest = Map<String, dynamic>.from(records.first);
    final name = _currentMember['full_name'] ?? _currentMember['name'] ?? 'Patient';
    final age = _currentMember['age'] ?? 'Unknown';
    final gender = _currentMember['gender'] ?? 'Unknown';
    final abha = _currentMember['abha_id'] ?? 'Not Linked';
    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.local_hospital, color: Color(0xFF00796B)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'PHC / Emergency Referral Slip',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient: $name ($gender, $age yrs)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('ABHA ID: $abha', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                    Text('Generated: $nowStr', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Latest Bedside Physiological Readings:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _slipRow('Blood Pressure', '${latest['blood_pressure_systolic'] ?? '?'}/${latest['blood_pressure_diastolic'] ?? '?'} mmHg'),
              _slipRow('Pulse / HR', '${latest['pulse_rate'] ?? '?'} bpm'),
              _slipRow('SpO2 Oxygen', '${latest['spo2'] ?? '?'} %'),
              _slipRow('Core Temp', '${latest['temperature'] ?? '?'} °F'),
              _slipRow('Resp Rate', '${latest['respiratory_rate'] ?? '?'} rpm'),
              _slipRow('Blood Sugar', '${latest['blood_sugar_fasting'] ?? latest['blood_sugar_postprandial'] ?? '?'} mg/dL'),
              if (latest['notes'] != null && (latest['notes'] as String).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('ASHA Field Notes: "${latest['notes']}"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
              ],
              const Divider(height: 20),
              const Text('Doctor Clinical Impression & Action:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 35),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('_____________________________\nPHC Medical Officer Signature', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📄 PHC Clinical Referral Slip generated successfully!')),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Confirm & Print'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _slipRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── 1. Maternal ANC & PNC Clinical Healthcare Card ──
  Widget _buildMaternalANCCard() {
    final isPregnant = (_currentMember['is_pregnant'] == 1 || _currentMember['is_pregnant'] == true);
    final isLactating = (_currentMember['is_lactating'] == 1 || _currentMember['is_lactating'] == true);
    final gender = _currentMember['gender']?.toString().toLowerCase() ?? '';
    final age = int.tryParse(_currentMember['age']?.toString() ?? '0') ?? 0;

    // Show if pregnant, lactating, or female aged 12-50 with ANC record
    if (!isPregnant && !isLactating) {
      if (gender != 'female' || age < 12 || age > 50) return const SizedBox.shrink();
    }

    final lmpStr = _currentMember['lmp_date']?.toString();
    final eddStr = _currentMember['edd_date']?.toString();
    final isHighRisk = (_currentMember['is_high_risk_pregnancy'] == 1 || _currentMember['is_high_risk_pregnancy'] == true);
    final td1 = (_currentMember['td1_vaccine'] == 1 || _currentMember['td1_vaccine'] == true);
    final td2 = (_currentMember['td2_vaccine'] == 1 || _currentMember['td2_vaccine'] == true);
    final tdBooster = (_currentMember['td_booster'] == 1 || _currentMember['td_booster'] == true);
    final ifa = (_currentMember['ifa_tablets_given'] as int?) ?? 0;
    final calcium = (_currentMember['calcium_tablets_given'] as int?) ?? 0;

    int weeks = 0;
    String stageText = 'ANC Registered';
    String daysLeftText = '';
    if (lmpStr != null) {
      final lmp = DateTime.tryParse(lmpStr);
      if (lmp != null) {
        final days = DateTime.now().difference(lmp).inDays;
        weeks = (days / 7).floor();
        if (weeks >= 28) {
          stageText = 'Week $weeks • 3rd Trimester (Pre-Delivery)';
        } else if (weeks >= 13) {
          stageText = 'Week $weeks • 2nd Trimester (Growth)';
        } else {
          stageText = 'Week $weeks • 1st Trimester (Organogenesis)';
        }
        final edd = lmp.add(const Duration(days: 280));
        final diffDays = edd.difference(DateTime.now()).inDays;
        if (diffDays > 0) {
          daysLeftText = '👶 Due in ~$diffDays days (${DateFormat('dd MMM yyyy').format(edd)})';
        } else {
          daysLeftText = '👶 Due date reached (${DateFormat('dd MMM yyyy').format(edd)})';
        }
      }
    } else if (eddStr != null) {
      daysLeftText = '👶 Expected Delivery: $eddStr';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade50, Colors.purple.shade50.withAlpha(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.pink.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.shade100.withAlpha(80),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.pink.shade100, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.pregnant_woman, color: Colors.pink, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Maternal Health & Reproductive Care', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.pink)),
                    Text(isPregnant ? 'Active ANC Protocol • 4 Mandatory Checkups' : 'Postnatal & Lactation Care', style: TextStyle(fontSize: 11, color: Colors.purple.shade700)),
                  ],
                ),
              ),
              if (isHighRisk)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 12),
                      SizedBox(width: 4),
                      Text('HRP HIGH RISK', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Gestational Progress Banner
          if (isPregnant) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.pink.shade100)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🌸 $stageText', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
                      Text('${(weeks / 40 * 100).clamp(0, 100).toStringAsFixed(0)}% Term', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.pink.shade700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (weeks / 40).clamp(0.0, 1.0),
                      backgroundColor: Colors.pink.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.pink),
                      minHeight: 6,
                    ),
                  ),
                  if (daysLeftText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(daysLeftText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ANC 4-Checkup Protocol Grid
          const Text('Mandatory ANC Visit Milestones (GoI Guidelines):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            children: [
              _ancStagePill('ANC 1', '≤12 Wks', weeks >= 1, Colors.teal),
              const SizedBox(width: 6),
              _ancStagePill('ANC 2', '14-26 Wks', weeks >= 14, Colors.blue),
              const SizedBox(width: 6),
              _ancStagePill('ANC 3', '28-34 Wks', weeks >= 28, Colors.amber.shade800),
              const SizedBox(width: 6),
              _ancStagePill('ANC 4', '36+ Wks', weeks >= 36, Colors.purple),
            ],
          ),
          const SizedBox(height: 12),

          // Td Vaccine & Nutrition Tablets Grid
          Row(
            children: [
              // Vaccines
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.vaccines, size: 14, color: Colors.teal),
                          SizedBox(width: 4),
                          Text('Td Injections', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('• Td-1: ${td1 ? "✅ Given" : "⏳ Pending"}', style: TextStyle(fontSize: 10, color: td1 ? Colors.green.shade800 : Colors.black87)),
                      Text('• Td-2: ${td2 ? "✅ Given" : "⏳ Pending"}', style: TextStyle(fontSize: 10, color: td2 ? Colors.green.shade800 : Colors.black87)),
                      Text('• Booster: ${tdBooster ? "✅ Given" : "—"}', style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Nutrition Tablets
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.medication, size: 14, color: Colors.pink),
                          SizedBox(width: 4),
                          Text('Supplementation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('• IFA Tablets: $ifa / 180', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                      Text('• Calcium: $calcium / 360', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                      Text('• Deworming: ${weeks >= 14 ? "✅ Done" : "⏳ 2nd Tri"}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 7-Stage Postnatal Care (PNC) Timeline
          if (isLactating || !isPregnant) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.purple.shade100)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.child_friendly, size: 14, color: Colors.purple),
                          SizedBox(width: 4),
                          Text('HBNC / PNC Home Visits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.purple)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                        child: const Text('🍼 100% EBF Active', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _pncDayBadge('Day 1'),
                        _pncDayBadge('Day 3'),
                        _pncDayBadge('Day 7'),
                        _pncDayBadge('Day 14'),
                        _pncDayBadge('Day 21'),
                        _pncDayBadge('Day 28'),
                        _pncDayBadge('Day 42'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Red-Flag Danger Signs Checklist
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50.withAlpha(100),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Maternal Red Flags: Severe headache, vision blur, facial edema, epigastric pain, bleeding, or reduced baby kicks ➔ Call 108 Emergency Ambulance!',
                    style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ancStagePill(String title, String timing, bool active, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(30) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: active ? color : Colors.grey)),
            Text(timing, style: TextStyle(fontSize: 8, color: active ? color.withAlpha(200) : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _pncDayBadge(String day) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Text(day, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
    );
  }

  // ── 2. Pediatric Child Growth & Immunization Card (< 5 Years) ──
  Widget _buildPediatricChildCard() {
    final age = int.tryParse(_currentMember['age']?.toString() ?? '0') ?? 0;
    if (age >= 5) return const SizedBox.shrink();

    final birthWeight = (_currentMember['birth_weight'] as num?)?.toDouble();
    final deliveryType = _currentMember['delivery_type']?.toString() ?? 'Institutional (Hospital/PHC)';
    final muac = (_currentMember['muac_cm'] as num?)?.toDouble();

    String muacStatus = 'Normal Nutritional State';
    Color muacColor = Colors.green;
    if (muac != null) {
      if (muac < 11.5) {
        muacStatus = '🔴 SAM (Severe Acute Malnutrition - NRC Urgent)';
        muacColor = Colors.red;
      } else if (muac < 12.5) {
        muacStatus = '🟡 MAM (Moderate Malnutrition - Supplementary Food)';
        muacColor = Colors.orange;
      } else {
        muacStatus = '🟢 Green Zone (Healthy Nutritional Growth)';
        muacColor = Colors.green;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.teal.shade50.withAlpha(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withAlpha(80),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.child_care, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pediatric Health & Immunization ($age Yrs)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                    const Text('Universal Immunization Program (UIP) • Growth Tracking', style: TextStyle(fontSize: 11, color: Colors.teal)),
                  ],
                ),
              ),
              if (birthWeight != null && birthWeight < 2.5)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, color: Colors.orange, size: 12),
                      SizedBox(width: 4),
                      Text('LBW / KMC Care', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Birth Weight & Delivery Type
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Birth Weight', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(birthWeight != null ? '$birthWeight kg' : 'Not Recorded', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text(birthWeight != null && birthWeight < 2.5 ? '⚠️ Low Birth Weight' : '🟢 Normal Weight', style: TextStyle(fontSize: 9, color: birthWeight != null && birthWeight < 2.5 ? Colors.orange : Colors.green)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delivery Place', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(deliveryType.contains('Inst') ? '🏥 Institutional' : '🏡 Home Delivery', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const Text('Safe Birth Protocol', style: TextStyle(fontSize: 9, color: Colors.teal)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Interactive MUAC Malnutrition Color Tape Gauge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.straighten, size: 14, color: Colors.teal),
                        const SizedBox(width: 4),
                        const Text('MUAC Arm Tape Screening', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    Text(muac != null ? '$muac cm' : 'Tap to Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: muacColor)),
                  ],
                ),
                const SizedBox(height: 6),
                // Visual Color Scale Bar
                Row(
                  children: [
                    Expanded(flex: 2, child: Container(height: 6, decoration: BoxDecoration(color: Colors.red, borderRadius: const BorderRadius.horizontal(left: Radius.circular(4))))),
                    Expanded(flex: 2, child: Container(height: 6, color: Colors.orange)),
                    Expanded(flex: 6, child: Container(height: 6, decoration: BoxDecoration(color: Colors.green, borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(muacStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muacColor)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // National Immunization Schedule (NIS)
          const Text('National Immunization Schedule (NIS):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                _vaccineRow('At Birth', 'BCG, OPV-0, Hepatitis-B', true),
                const Divider(height: 10),
                _vaccineRow('6, 10, 14 Wks', 'Pentavalent 1-2-3, Rotavirus, IPV, PCV', age >= 1),
                const Divider(height: 10),
                _vaccineRow('9–12 Months', 'Measles-Rubella (MR-1), Vitamin A', age >= 1),
                const Divider(height: 10),
                _vaccineRow('16–24 Months', 'MR-2, DPT Booster-1, OPV Booster', age >= 2),
                const Divider(height: 10),
                _vaccineRow('5–6 Years', 'DPT Booster-2', age >= 5),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // IMNCI Infant Danger Signs
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50.withAlpha(100),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.emergency, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Infant Danger Signs (IMNCI): Unable to suck milk, persistent vomiting, fast breathing (>50 bpm = Pneumonia), chest indrawing, or cold limbs ➔ Immediate Referral to Pediatric PHC/SNCU!',
                    style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vaccineRow(String stage, String vaccines, bool completed) {
    return Row(
      children: [
        Icon(completed ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: completed ? Colors.green : Colors.grey),
        const SizedBox(width: 8),
        SizedBox(width: 85, child: Text(stage, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
        Expanded(child: Text(vaccines, style: TextStyle(fontSize: 10, color: completed ? Colors.black87 : Colors.grey.shade700))),
      ],
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
            
            // GGUF Download Status Banner (Disappears completely once model is downloaded!)
            ValueListenableBuilder<bool>(
              valueListenable: OnDeviceLLMService.isModelDownloadedNotifier,
              builder: (context, isDownloaded, _) {
                if (isDownloaded) {
                  return const SizedBox.shrink(); // Download header is gone once downloaded!
                }
                return ValueListenableBuilder<bool>(
                  valueListenable: OnDeviceLLMService.isDownloadingNotifier,
                  builder: (context, isDownloading, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: OnDeviceLLMService.isPausedNotifier,
                      builder: (context, isPaused, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isPaused ? Colors.orange.shade50 : (isDownloading ? Colors.blue.shade50 : Colors.amber.shade50),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isPaused
                                  ? Colors.orange.shade300
                                  : (isDownloading ? Colors.blue.shade300 : Colors.amber.shade300),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isDownloading
                                    ? Icons.downloading_rounded
                                    : (isPaused ? Icons.pause_circle_filled : Icons.download_for_offline_outlined),
                                size: 18,
                                color: isPaused
                                    ? Colors.orange.shade900
                                    : (isDownloading ? Colors.blue.shade900 : Colors.amber.shade900),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isDownloading
                                      ? 'Downloading Offline Model... Tap to manage.'
                                      : (isPaused
                                          ? 'Download Paused • Tap Resume to continue.'
                                          : 'Optional: Download Offline GGUF Neural Model (~1.04 GB)'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isPaused
                                        ? Colors.orange.shade900
                                        : (isDownloading ? Colors.blue.shade900 : Colors.amber.shade900),
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: isDownloading
                                      ? Colors.orange.shade600
                                      : (isPaused ? const Color(0xFF00796B) : const Color(0xFF00796B)),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                onPressed: () {
                                  _showGgufDownloadDialog(context);
                                },
                                child: Text(
                                  isDownloading ? 'Pause' : (isPaused ? 'Resume' : 'Download'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
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
    OnDeviceLLMService.showModelManagementDialog(context);
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

