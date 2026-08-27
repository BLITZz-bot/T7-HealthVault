import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';
import '../services/image_utils.dart';
import '../services/language_service.dart';
import '../widgets/language_switcher_widget.dart';
import '../widgets/qwen_ai_chat_modal.dart';
import 'member_detail_screen.dart';

class FamilyDetailScreen extends StatefulWidget {
  final Map<String, dynamic> family;
  final String token;

  const FamilyDetailScreen({super.key, required this.family, required this.token});

  @override
  State<FamilyDetailScreen> createState() => _FamilyDetailScreenState();
}

class _FamilyDetailScreenState extends State<FamilyDetailScreen> {
  late Future<List<dynamic>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _refreshMembers();
  }

  void _refreshMembers() {
    setState(() {
      _membersFuture = LocalDbService.getMembers(widget.token).then((allMembers) {
        // Filter locally by family id
        return allMembers.where((m) => m['family'].toString() == widget.family['id'].toString()).toList();
      });
    });
  }

  void _showAddMemberDialog() {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    String gender = 'male';
    String? pickedImageBase64;
    final abhaCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final birthWeightCtrl = TextEditingController();
    final muacCtrl = TextEditingController();
    final chronicNotesCtrl = TextEditingController();

    bool isPregnant = false;
    DateTime? lmpDate;
    String? eddDateStr;
    String? gestationalAgeStr;
    bool isHighRisk = false;
    bool isLactating = false;
    bool td1 = false;
    bool td2 = false;
    bool tdBooster = false;
    int ifaCount = 0;
    int calciumCount = 0;
    String deliveryType = 'Institutional (Hospital/PHC)';
    bool hasChronic = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final int parsedAge = int.tryParse(ageCtrl.text) ?? 0;
          final bool isFemaleReproductive = gender == 'female' && (parsedAge == 0 || (parsedAge >= 12 && parsedAge <= 55));
          final bool isChild = parsedAge > 0 && parsedAge < 5;

          // Recompute EDD and Gestational Age whenever LMP is selected
          void updateLMP(DateTime selected) {
            lmpDate = selected;
            final edd = selected.add(const Duration(days: 280)); // 40 weeks / Naegele's rule
            eddDateStr = DateFormat('dd MMM yyyy').format(edd);
            final daysPassed = DateTime.now().difference(selected).inDays;
            final weeks = (daysPassed / 7).floor();
            String trimester = '1st Trimester';
            if (weeks >= 28) {
              trimester = '3rd Trimester';
            } else if (weeks >= 13) {
              trimester = '2nd Trimester';
            }
            gestationalAgeStr = 'Week $weeks ($trimester)';
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.person_add, color: Color(0xFF00796B)),
                const SizedBox(width: 8),
                Text(LanguageService.tr('add_new_member'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo
                    Center(
                      child: Column(
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
                            pickedImageBase64 == null ? 'Photo (Optional)' : 'Photo Selected',
                            style: TextStyle(fontSize: 11, color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Demographics
                    TextField(controller: nameCtrl, decoration: InputDecoration(labelText: '${LanguageService.tr('member_name')} *')),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: '${LanguageService.tr('age')} *'),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: gender,
                            decoration: InputDecoration(labelText: LanguageService.tr('gender')),
                            items: [
                              DropdownMenuItem(value: 'female', child: Text(LanguageService.tr('female'))),
                              DropdownMenuItem(value: 'male', child: Text(LanguageService.tr('male'))),
                              DropdownMenuItem(value: 'other', child: Text(LanguageService.tr('other'))),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => gender = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: relCtrl, decoration: InputDecoration(labelText: '${LanguageService.tr('relationship_to_head')} *')),
                    const SizedBox(height: 10),
                    TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile Number (10 digits)', prefixIcon: Icon(Icons.phone, size: 18))),
                    const SizedBox(height: 10),
                    TextField(controller: abhaCtrl, decoration: const InputDecoration(labelText: 'ABHA Health ID (14 digits)', prefixIcon: Icon(Icons.badge_outlined, size: 18))),
                    const SizedBox(height: 14),

                    // ── Maternal ANC / PNC Care (For Females) ──
                    if (isFemaleReproductive) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50.withAlpha(120),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.pink.shade200),
                        ),
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
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.pink.shade900,
                                  side: BorderSide(color: Colors.pink.shade300),
                                ),
                                icon: const Icon(Icons.calendar_month, size: 18),
                                label: Text(lmpDate == null ? 'Select LMP Date (Last Period)' : 'LMP: ${DateFormat('dd MMM yyyy').format(lmpDate!)}'),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: lmpDate ?? DateTime.now().subtract(const Duration(days: 60)),
                                    firstDate: DateTime.now().subtract(const Duration(days: 300)),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setModalState(() => updateLMP(picked));
                                  }
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
                                      Text('⏳ Gestational Stage: $gestationalAgeStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal)),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('High-Risk Pregnancy (HRP) Alert', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                                subtitle: const Text('Severe Anemia, High BP, Past C-Section, Age <18 or >35', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                value: isHighRisk,
                                activeColor: Colors.red,
                                onChanged: (val) => setModalState(() => isHighRisk = val ?? false),
                              ),
                              const SizedBox(height: 6),
                              const Text('Tetanus & Diphtheria (Td) Vaccines:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              Row(
                                children: [
                                  Expanded(
                                    child: CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: const Text('Td-1 Dose', style: TextStyle(fontSize: 11)),
                                      value: td1,
                                      onChanged: (v) => setModalState(() => td1 = v ?? false),
                                    ),
                                  ),
                                  Expanded(
                                    child: CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: const Text('Td-2 Dose', style: TextStyle(fontSize: 11)),
                                      value: td2,
                                      onChanged: (v) => setModalState(() => td2 = v ?? false),
                                    ),
                                  ),
                                  Expanded(
                                    child: CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: const Text('Td Booster', style: TextStyle(fontSize: 11)),
                                      value: tdBooster,
                                      onChanged: (v) => setModalState(() => tdBooster = v ?? false),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: '$ifaCount',
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'IFA Red Tablets (180 Target)', labelStyle: TextStyle(fontSize: 11)),
                                      onChanged: (v) => ifaCount = int.tryParse(v) ?? 0,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: '$calciumCount',
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Calcium Tablets', labelStyle: TextStyle(fontSize: 11)),
                                      onChanged: (v) => calciumCount = int.tryParse(v) ?? 0,
                                    ),
                                  ),
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

                    // ── Pediatric & Child Health (< 5 Years) ──
                    if (isChild) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withAlpha(120),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.child_care, color: Colors.blue, size: 20),
                                SizedBox(width: 6),
                                Text('Pediatric Health & Growth (< 5 Yrs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: birthWeightCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Birth Weight (kg)', hintText: 'e.g. 2.8'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: muacCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'MUAC Tape (cm)', hintText: 'e.g. 13.5'),
                                  ),
                                ),
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

                    // ── Chronic Condition (All ages) ──
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Has Known Chronic Health Condition', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Hypertension, Diabetes, Asthma, Tuberculosis, Heart Disease', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      value: hasChronic,
                      onChanged: (val) => setModalState(() => hasChronic = val ?? false),
                    ),
                    if (hasChronic)
                      TextField(
                        controller: chronicNotesCtrl,
                        decoration: const InputDecoration(labelText: 'Specific Chronic Conditions / Medications'),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(LanguageService.tr('cancel'))),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty && ageCtrl.text.isNotEmpty && relCtrl.text.isNotEmpty) {
                    final age = int.tryParse(ageCtrl.text) ?? 0;
                    final ok = await LocalDbService.addMember(
                      widget.token,
                      widget.family['id'].toString(),
                      nameCtrl.text,
                      age,
                      gender,
                      relCtrl.text,
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
                    if (ok && context.mounted) {
                      _refreshMembers();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.tr('save_member'))));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                child: Text(LanguageService.tr('save_member')),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _flagColor(String? flag) {
    switch (flag) {
      case 'critical': return Colors.red;
      case 'warning': return Colors.orange;
      default: return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final headName = widget.family['family_head_name'] ?? 'Household';
    final houseNo = widget.family['house_number'] ?? 'N/A';
    final contact = widget.family['contact_number'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      appBar: AppBar(
        title: Text('${LanguageService.tr('family_details')} • $headName'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        actions: const [
          LanguageSwitcherWidget(),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Household Hero Card ──
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF004D40), const Color(0xFF00796B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.shade300.withAlpha(60),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.home_work_rounded, color: Colors.tealAccent, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${LanguageService.tr('house_number')}: $houseNo',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.phone_rounded, size: 12, color: Colors.tealAccent.shade100),
                          const SizedBox(width: 3),
                          Text(
                            contact,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Members Section Title ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF00796B)),
                    const SizedBox(width: 6),
                    Text(
                      LanguageService.tr('members'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showAddMemberDialog,
                  icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF00796B)),
                  label: Text(
                    LanguageService.tr('add_member'),
                    style: const TextStyle(color: Color(0xFF00796B), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // ── Members List ──
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _membersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final members = snapshot.data ?? [];
                if (members.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_add_disabled_rounded, size: 54, color: Colors.teal.shade200),
                          const SizedBox(height: 12),
                          Text(
                            LanguageService.tr('no_members'),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00796B),
                              minimumSize: const Size(160, 42),
                            ),
                            onPressed: _showAddMemberDialog,
                            icon: const Icon(Icons.add),
                            label: Text(LanguageService.tr('add_member')),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final flag = member['current_flag'] as String?;
                    final lastRecorded = member['last_recorded_at'] as String?;
                    final flagC = _flagColor(flag);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: flag == 'critical'
                              ? Colors.red.shade300
                              : (flag == 'warning' ? Colors.orange.shade300 : Colors.teal.shade50.withAlpha(200)),
                          width: flag == 'critical' || flag == 'warning' ? 1.6 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: flag == 'critical'
                                ? Colors.red.shade100.withAlpha(60)
                                : Colors.black.withAlpha(5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MemberDetailScreen(
                                member: member,
                                token: widget.token,
                              ),
                            ),
                          );
                          _refreshMembers();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              // Avatar with Triage Color Border Ring
                              Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: flagC, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.teal.shade50,
                                  backgroundImage: ImageUtils.safeBase64Image(member['profile_image']?.toString()),
                                  child: ImageUtils.safeBase64Image(member['profile_image']?.toString()) != null
                                      ? null
                                      : Icon(
                                          member['gender'] == 'male' ? Icons.male : (member['gender'] == 'female' ? Icons.female : Icons.person),
                                          color: Colors.teal.shade800,
                                          size: 24,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Info Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            member['full_name'] ?? 'Member',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                                          ),
                                        ),
                                        if (flag != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: flagC.withAlpha(25),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: flagC.withAlpha(120)),
                                            ),
                                            child: Text(
                                              flag.toUpperCase(),
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: flagC),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${LanguageService.tr('age')}: ${member['age']} ${LanguageService.tr('years')} • ${member['gender']} • ${member['relationship_to_head']}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                    ),
                                    if (lastRecorded != null) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(Icons.history_rounded, size: 12, color: Colors.grey.shade400),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${LanguageService.tr('recorded_at')}: ${_formatDate(lastRecorded)}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const QwenChatFloatingButton(heroTag: 'family_qwen_chat_fab'),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_member_fab',
            onPressed: _showAddMemberDialog,
            icon: const Icon(Icons.person_add_rounded),
            label: Text(LanguageService.tr('add_member')),
            backgroundColor: const Color(0xFF00796B),
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
