import 'package:flutter/material.dart';
import '../services/local_db_service.dart';
import '../services/image_utils.dart';
import '../widgets/language_switcher_widget.dart';
import '../services/language_service.dart';
import '../services/on_device_llm_service.dart';
import '../widgets/qwen_ai_chat_modal.dart';
import 'login_screen.dart';
import 'family_detail_screen.dart';

class ASHAHomeScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const ASHAHomeScreen({super.key, required this.token, required this.user});

  @override
  State<ASHAHomeScreen> createState() => _ASHAHomeScreenState();
}

class _ASHAHomeScreenState extends State<ASHAHomeScreen> {
  late Future<List<dynamic>> _familiesFuture;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _refreshFamilies();
  }

  void _refreshFamilies() {
    setState(() {
      _familiesFuture = LocalDbService.getFamilies(widget.token);
    });
  }

  void _showAddFamilyDialog() {
    final assignedAreas = widget.user['assigned_areas'] as List<dynamic>? ?? [];
    final stateName = widget.user['state_name'] ?? 'N/A';
    final districtNames = widget.user['district_names'] as List<dynamic>? ?? [];
    final districtDisplay = districtNames.isNotEmpty ? districtNames.join(', ') : 'N/A';

    if (assignedAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.tr('no_families'))),
      );
      return;
    }

    final headNameController = TextEditingController();
    final houseNoController = TextEditingController();
    final contactController = TextEditingController();

    // Default to the first assigned area if there's only one
    String? selectedAreaId = assignedAreas.length == 1 ? assignedAreas[0]['id'].toString() : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(LanguageService.tr('add_new_family')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: headNameController, decoration: InputDecoration(labelText: LanguageService.tr('head_of_family'))),
                const SizedBox(height: 12),
                TextField(controller: houseNoController, decoration: InputDecoration(labelText: LanguageService.tr('house_number'))),
                const SizedBox(height: 12),
                TextField(controller: contactController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: LanguageService.tr('contact_number'))),
                const SizedBox(height: 16),
                
                // Static display of State and District
                Text(
                  '${LanguageService.tr('state')}: $stateName',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${LanguageService.tr('district')}: $districtDisplay',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),

                // Area selection dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedAreaId,
                  decoration: InputDecoration(labelText: LanguageService.tr('select_area')),
                  items: assignedAreas.map<DropdownMenuItem<String>>((a) {
                    return DropdownMenuItem<String>(
                      value: a['id'].toString(),
                      child: Text('${a['village_or_ward']} (Block: ${a['block']})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        selectedAreaId = val;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(LanguageService.tr('cancel'))),
            ElevatedButton(
              onPressed: () async {
                if (headNameController.text.isNotEmpty && houseNoController.text.isNotEmpty && selectedAreaId != null) {
                  final success = await LocalDbService.addFamily(
                    widget.token,
                    headNameController.text,
                    houseNoController.text,
                    contactController.text,
                    selectedAreaId!,
                  );
                  if (!mounted || !context.mounted) return;
                  Navigator.pop(context);
                  if (success && context.mounted) {
                    _refreshFamilies();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.tr('save_family'))));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageService.tr('enter_name_phone'))));
                }
              },
              child: Text(LanguageService.tr('save_family')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAIBanner() {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, currentLang, _) {
        final langInfo = LanguageService.getLanguageInfo(currentLang);
        return ValueListenableBuilder<bool>(
          valueListenable: OnDeviceLLMService.isModelDownloadedNotifier,
          builder: (context, isDownloaded, _) {
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF004D40), const Color(0xFF00796B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade200.withAlpha(100),
                    blurRadius: 8,
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
                          const Icon(Icons.psychology, color: Colors.white, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            LanguageService.tr('ai_intelligence_active'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${langInfo['native']}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDownloaded
                        ? LanguageService.tr('sepsis_news2_loaded')
                        : LanguageService.tr('sepsis_news2_ready'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (!isDownloaded) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade400,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.download_for_offline, size: 18),
                        label: Text(
                          LanguageService.tr('download_qwen3_llm'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () {
                          _showHomeGgufDownloadDialog(context);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHomeGgufDownloadDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.downloading_rounded, color: Color(0xFF00796B)),
              const SizedBox(width: 8),
              Text(LanguageService.tr('download_qwen3_llm'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LanguageService.tr('sepsis_news2_loaded'),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
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
              onPressed: () => Navigator.pop(ctx),
              child: Text(LanguageService.tr('cancel')),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
              icon: const Icon(Icons.download),
              label: Text(LanguageService.tr('start_download', defaultText: 'Start Download (~986 MB)')),
              onPressed: () async {
                final success = await OnDeviceLLMService.downloadModel();
                if (ctx.mounted && success) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(LanguageService.tr('qwen3_ai_chat'))),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _searchQuery = '';

  Widget _buildFamiliesListView() {
    return FutureBuilder<List<dynamic>>(
      future: _familiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading data: ${snapshot.error}'));
        }

        final allFamilies = snapshot.data ?? [];
        final families = allFamilies.where((f) {
          final name = (f['family_head_name'] ?? '').toString().toLowerCase();
          final house = (f['house_number'] ?? '').toString().toLowerCase();
          final q = _searchQuery.toLowerCase();
          return name.contains(q) || house.contains(q);
        }).toList();

        final totalFamilies = allFamilies.length;
        final assignedAreas = widget.user['assigned_areas'] as List<dynamic>? ?? [];

        return Column(
          children: [
            // Top AI Banner
            _buildTopAIBanner(),

            // Quick Stats Bento Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.teal.shade50.withAlpha(200)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00796B).withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.holiday_village_rounded, color: Color(0xFF00796B), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$totalFamilies',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF00382E)),
                              ),
                              Text(
                                LanguageService.tr('families'),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.teal.shade50.withAlpha(200)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on_rounded, color: Colors.blue, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${assignedAreas.length}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF00382E)),
                              ),
                              Text(
                                LanguageService.tr('assigned_areas'),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search family name or house no...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00796B), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
            ),
            
            Expanded(
              child: families.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_rounded, size: 54, color: Colors.teal.shade200),
                            const SizedBox(height: 12),
                            Text(
                              LanguageService.tr('no_families'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: families.length,
                      itemBuilder: (context, i) {
                        final family = families[i];
                        final headName = family['family_head_name'] ?? 'Family';
                        final houseNo = family['house_number'] ?? 'N/A';
                        final contact = family['contact_number'] ?? 'N/A';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.teal.shade50.withAlpha(200), width: 1.2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 12, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FamilyDetailScreen(
                                    family: family,
                                    token: widget.token,
                                  ),
                                ),
                              ).then((_) => _refreshFamilies());
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [const Color(0xFF00796B), Colors.teal.shade700],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        headName.isNotEmpty ? headName[0].toUpperCase() : 'F',
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          headName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade50,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '#$houseNo',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(Icons.phone_outlined, size: 13, color: Colors.grey.shade500),
                                            const SizedBox(width: 3),
                                            Text(
                                              contact,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildProfileView() {
    final fname = widget.user['first_name'] ?? '';
    final lname = widget.user['last_name'] ?? '';
    final fullName = '$fname $lname'.trim().isNotEmpty ? '$fname $lname'.trim() : widget.user['username'];
    final username = widget.user['username'] ?? '';
    final phone = widget.user['phone_number'] ?? 'N/A';
    final aadhaarNumber = widget.user['aadhaar_number'] ?? 'N/A';
    final profileImage = widget.user['profile_image'] as String?;
    final stateName = widget.user['state_name'] ?? 'N/A';
    final List<dynamic> districtNamesRaw = widget.user['district_names'] ?? [];
    final String districtDisplay = districtNamesRaw.isNotEmpty ? districtNamesRaw.join(', ') : 'N/A';
    final assignedAreas = widget.user['assigned_areas'] as List<dynamic>? ?? [];

    String initials = '';
    if (fname.isNotEmpty) initials += fname[0].toUpperCase();
    if (lname.isNotEmpty) initials += lname[0].toUpperCase();
    if (initials.isEmpty && username.isNotEmpty) initials += username[0].toUpperCase();
    if (initials.isEmpty) initials = 'AW';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.teal.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.shade200.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: ImageUtils.safeBase64Image(profileImage) != null
                          ? null
                          : LinearGradient(
                              colors: [Colors.teal.shade200, Colors.teal.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      image: ImageUtils.safeBase64Image(profileImage) != null
                          ? DecorationImage(
                              image: ImageUtils.safeBase64Image(profileImage)!,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: ImageUtils.safeBase64Image(profileImage) != null
                        ? null
                        : Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    LanguageService.tr('asha_role_badge'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Personal Information Card
          _buildInfoCard(
            title: LanguageService.tr('personal_details'),
            icon: Icons.person_outline,
            children: [
              _buildInfoRow(LanguageService.tr('full_name'), fullName),
              _buildInfoRow(LanguageService.tr('phone_number'), phone),
              _buildInfoRow('Aadhaar Number', aadhaarNumber),
            ],
          ),
          const SizedBox(height: 16),

          // Jurisdiction Card
          _buildInfoCard(
            title: LanguageService.tr('jurisdiction'),
            icon: Icons.map_outlined,
            children: [
              _buildInfoRow(LanguageService.tr('state'), stateName),
              _buildInfoRow(LanguageService.tr('district'), districtDisplay),
            ],
          ),
          const SizedBox(height: 16),

          // Assigned Areas Card
          _buildInfoCard(
            title: '${LanguageService.tr('assigned_areas')} (${assignedAreas.length})',
            icon: Icons.location_on_outlined,
            children: [
              if (assignedAreas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No areas assigned yet.',
                    style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: assignedAreas.map<Widget>((a) {
                    return Chip(
                      avatar: Icon(Icons.home_work_outlined, size: 14, color: Colors.teal.shade700),
                      label: Text(
                        '${a['village_or_ward']} (${a['block']})',
                        style: TextStyle(color: Colors.teal.shade900, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      backgroundColor: Colors.teal.shade50,
                      side: BorderSide(color: Colors.teal.shade100),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    );
                  }).toList(),
                ),
            ],
          ),
          // Language Settings Card
          _buildInfoCard(
            title: LanguageService.tr('language_settings'),
            icon: Icons.language,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: LanguageService.currentLanguageNotifier,
                builder: (context, currentLang, _) {
                  final info = LanguageService.getLanguageInfo(currentLang);
                  return Column(
                    children: [
                      _buildInfoRow(LanguageService.tr('active_language'), '${info['name']} (${info['native']})'),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00897B),
                            side: const BorderSide(color: Color(0xFF00897B)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.translate, size: 18),
                          label: Text(LanguageService.tr('change_language')),
                          onPressed: () {
                            LanguageSwitcherWidget.showLanguageModal(context);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF00897B), size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00897B),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 
            ? '${LanguageService.tr('asha_portal')} (${widget.user['first_name'] ?? widget.user['username']})'
            : LanguageService.tr('asha_profile')),
        actions: [
          const LanguageSwitcherWidget(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildFamiliesListView() : _buildProfileView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF00897B),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: LanguageService.tr('families'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: LanguageService.tr('profile'),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const QwenChatFloatingButton(heroTag: 'home_qwen_chat_fab'),
          if (_currentIndex == 0) ...[
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              heroTag: 'add_family_fab',
              onPressed: _showAddFamilyDialog,
              icon: const Icon(Icons.add),
              label: Text(LanguageService.tr('add_family')),
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}
