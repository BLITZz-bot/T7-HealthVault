import 'package:flutter/material.dart';
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.person_add, color: Color(0xFF00796B)),
              const SizedBox(width: 8),
              Text(LanguageService.tr('add_new_member')),
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
                  pickedImageBase64 == null ? 'Photo (Max 5MB)' : 'Photo Selected',
                  style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: LanguageService.tr('member_name'))),
                const SizedBox(height: 12),
                TextField(controller: ageCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: LanguageService.tr('age'))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: gender,
                  decoration: InputDecoration(labelText: LanguageService.tr('gender')),
                  items: [
                    DropdownMenuItem(value: 'male', child: Text(LanguageService.tr('male'))),
                    DropdownMenuItem(value: 'female', child: Text(LanguageService.tr('female'))),
                    DropdownMenuItem(value: 'other', child: Text(LanguageService.tr('other'))),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => gender = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: relCtrl, decoration: InputDecoration(labelText: LanguageService.tr('relationship_to_head'))),
              ],
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
                  );
                  if (!mounted || !context.mounted) return;
                  Navigator.pop(ctx);
                  if (ok && context.mounted) {
                    _refreshMembers();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.tr('save_member'))));
                  }
                }
              },
              child: Text(LanguageService.tr('save_member')),
            )
          ],
        ),
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
