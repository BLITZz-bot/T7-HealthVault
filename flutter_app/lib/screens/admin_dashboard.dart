import 'package:flutter/material.dart';
import '../services/local_db_service.dart';
import '../services/image_utils.dart';
import '../services/language_service.dart';
import '../widgets/language_switcher_widget.dart';
import '../widgets/searchable_dropdown.dart';
import 'login_screen.dart';
import 'admin_settings_screen.dart';
import 'state_jurisdiction_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const AdminDashboardScreen({super.key, required this.token, required this.user});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _stateSearchController = TextEditingController();
  String _stateSearchQuery = '';

  Map<String, dynamic>? _firstWhereOrNull(List<dynamic> list, bool Function(dynamic) test) {
    for (var element in list) {
      if (test(element)) return element as Map<String, dynamic>;
    }
    return null;
  }

  late Future<List<dynamic>> _workersFuture;
  late Future<List<dynamic>> _areasFuture;
  late Future<List<List<dynamic>>> _masterDataFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
    
    // Welcome SnackBar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('welcome admin!'),
            backgroundColor: Color(0xFF004D40),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _refreshData() {
    setState(() {
      _workersFuture = LocalDbService.getASHAWorkers(widget.token);
      _areasFuture = LocalDbService.getAreas(widget.token);
      _masterDataFuture = Future.wait([
        LocalDbService.getStates(widget.token),
        LocalDbService.getDistricts(widget.token),
        LocalDbService.getAreas(widget.token),
      ]);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stateSearchController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showAddWorkerDialog() {
    Future.wait([
      LocalDbService.getStates(widget.token),
      LocalDbService.getDistricts(widget.token),
      LocalDbService.getAreas(widget.token),
    ]).then((results) {
      if (!mounted) return;
      final states = results[0];
      final districts = results[1];
      final areas = results[2];

      if (states.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a state first.')));
        return;
      }

      final usernameCtrl = TextEditingController();
      final firstNameCtrl = TextEditingController();
      final lastNameCtrl = TextEditingController();
      final phoneCtrl = TextEditingController();
      final aadhaarCtrl = TextEditingController();
      String? selectedStateId;
      String? selectedDistrictId;
      List<String> selectedAreaIds = [];
      String? pickedImageBase64;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            title: const Text('Register Worker'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () async {
                      final img = await ImageUtils.pickAndCompressImage(context);
                      if (img != null) setModalState(() => pickedImageBase64 = img);
                    },
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: ImageUtils.safeBase64Image(pickedImageBase64),
                      child: pickedImageBase64 == null ? const Icon(Icons.camera_alt) : null,
                    ),
                  ),
                  TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username')),
                  TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name')),
                  TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name')),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                  TextField(controller: aadhaarCtrl, decoration: const InputDecoration(labelText: 'Aadhaar')),
                  const SizedBox(height: 15),
                  SearchableDropdown<dynamic>(
                    items: states,
                    labelText: 'Select State',
                    itemToString: (s) => s['name'] ?? 'State',
                    onChanged: (val) {
                      setModalState(() {
                        selectedStateId = val['id'].toString();
                        selectedDistrictId = null;
                        selectedAreaIds.clear();
                      });
                    },
                  ),
                  if (selectedStateId != null) ...[
                    const SizedBox(height: 10),
                    SearchableDropdown<dynamic>(
                      items: districts.where((d) => d['state_id'].toString() == selectedStateId).toList(),
                      labelText: 'Select District',
                      itemToString: (d) => d['name'] ?? 'District',
                      onChanged: (val) {
                        setModalState(() {
                          selectedDistrictId = val['id'].toString();
                          selectedAreaIds.clear();
                        });
                      },
                    ),
                  ],
                  if (selectedDistrictId != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final districtAreas = areas.where((a) => a['district_id'].toString() == selectedDistrictId).toList();
                        await showDialog(
                          context: context,
                          builder: (context) => StatefulBuilder(builder: (context, setSubState) => AlertDialog(
                            title: const Text('Select Areas'),
                            content: SizedBox(width: 300, height: 300, child: ListView(
                              children: districtAreas.map((a) => CheckboxListTile(
                                title: Text(a['village_or_ward'] ?? 'Area'),
                                value: selectedAreaIds.contains(a['id'].toString()),
                                onChanged: (v) {
                                  setSubState(() {
                                    if (v == true) {
                                      selectedAreaIds.add(a['id'].toString());
                                    } else {
                                      selectedAreaIds.remove(a['id'].toString());
                                    }
                                  });
                                  setModalState(() {});
                                },
                              )).toList(),
                            )),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
                          )),
                        );
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Jurisdiction Areas', border: OutlineInputBorder()),
                        child: Text(selectedAreaIds.isEmpty ? 'Tap to select' : '${selectedAreaIds.length} selected'),
                      ),
                    ),
                  ]
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(onPressed: () async {
                if (usernameCtrl.text.trim().isEmpty || firstNameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Username, First Name, and Phone Number.')));
                  return;
                }
                if (selectedStateId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a State.')));
                  return;
                }
                await LocalDbService.addASHAWorker(
                  token: widget.token, username: usernameCtrl.text.trim(),
                  firstName: firstNameCtrl.text.trim(), lastName: lastNameCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim(), aadhaarNumber: aadhaarCtrl.text.trim(),
                  stateId: selectedStateId!, areaIds: selectedAreaIds, profileImage: pickedImageBase64,
                );
                if (mounted) { Navigator.pop(ctx); _refreshData(); }
              }, child: const Text('Save Worker')),
            ],
          ),
        ),
      );
    });
  }

  void _showEditWorkerDialog(Map<String, dynamic> worker) {
    Future.wait([
      LocalDbService.getStates(widget.token),
      LocalDbService.getDistricts(widget.token),
      LocalDbService.getAreas(widget.token),
    ]).then((results) {
      if (!mounted) return;
      final states = results[0];
      final districts = results[1];
      final areas = results[2];

      final usernameCtrl = TextEditingController(text: worker['username']);
      final firstNameCtrl = TextEditingController(text: worker['first_name']);
      final lastNameCtrl = TextEditingController(text: worker['last_name']);
      final phoneCtrl = TextEditingController(text: worker['phone_number']);
      final aadhaarCtrl = TextEditingController(text: worker['aadhaar_number']);
      String? selectedStateId = worker['state']?.toString();
      List<String> selectedAreaIds = List<String>.from(worker['assigned_areas']?.map((id) => id.toString()) ?? []);
      String? selectedDistrictId;
      if (selectedAreaIds.isNotEmpty) {
        final firstArea = _firstWhereOrNull(areas, (a) => a['id'].toString() == selectedAreaIds.first);
        if (firstArea != null) selectedDistrictId = firstArea['district_id']?.toString();
      }
      String userId = worker['id'].toString();
      String? pickedImageBase64 = worker['profile_image'];

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            title: const Text('Edit Worker'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () async {
                      final img = await ImageUtils.pickAndCompressImage(context);
                      if (img != null) setModalState(() => pickedImageBase64 = img);
                    },
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: ImageUtils.safeBase64Image(pickedImageBase64),
                      child: pickedImageBase64 == null ? const Icon(Icons.camera_alt) : null,
                    ),
                  ),
                  TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username')),
                  TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name')),
                  TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name')),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                  TextField(controller: aadhaarCtrl, decoration: const InputDecoration(labelText: 'Aadhaar')),
                  const SizedBox(height: 15),
                  SearchableDropdown<dynamic>(
                    items: states,
                    labelText: 'Select State',
                    itemToString: (s) => s['name'] ?? 'State',
                    initialValue: _firstWhereOrNull(states, (s) => s['id'].toString() == selectedStateId),
                    onChanged: (val) {
                      setModalState(() {
                        selectedStateId = val['id'].toString();
                        selectedDistrictId = null;
                        selectedAreaIds.clear();
                      });
                    },
                  ),
                  if (selectedStateId != null) ...[
                    const SizedBox(height: 10),
                    SearchableDropdown<dynamic>(
                      items: districts.where((d) => d['state_id'].toString() == selectedStateId).toList(),
                      labelText: 'Select District',
                      itemToString: (d) => d['name'] ?? 'District',
                      initialValue: _firstWhereOrNull(districts, (d) => d['id'].toString() == selectedDistrictId),
                      onChanged: (val) {
                        setModalState(() {
                          selectedDistrictId = val['id'].toString();
                          selectedAreaIds.clear();
                        });
                      },
                    ),
                  ],
                  if (selectedDistrictId != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final districtAreas = areas.where((a) => a['district_id'].toString() == selectedDistrictId).toList();
                        await showDialog(
                          context: context,
                          builder: (context) => StatefulBuilder(builder: (context, setSubState) => AlertDialog(
                            title: const Text('Select Areas'),
                            content: SizedBox(width: 300, height: 300, child: ListView(
                              children: districtAreas.map((a) => CheckboxListTile(
                                title: Text(a['village_or_ward'] ?? 'Area'),
                                value: selectedAreaIds.contains(a['id'].toString()),
                                onChanged: (v) {
                                  setSubState(() {
                                    if (v == true) {
                                      selectedAreaIds.add(a['id'].toString());
                                    } else {
                                      selectedAreaIds.remove(a['id'].toString());
                                    }
                                  });
                                  setModalState(() {});
                                },
                              )).toList(),
                            )),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
                          )),
                        );
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Jurisdiction Areas', border: OutlineInputBorder()),
                        child: Text(selectedAreaIds.isEmpty ? 'Tap to select' : '${selectedAreaIds.length} selected'),
                      ),
                    ),
                  ]
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(onPressed: () async {
                if (usernameCtrl.text.trim().isEmpty || firstNameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Username, First Name, and Phone Number.')));
                  return;
                }
                if (selectedStateId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a State.')));
                  return;
                }
                await LocalDbService.editASHAWorker(
                  token: widget.token, userId: userId, username: usernameCtrl.text.trim(),
                  firstName: firstNameCtrl.text.trim(), lastName: lastNameCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim(), aadhaarNumber: aadhaarCtrl.text.trim(),
                  stateId: selectedStateId!, areaIds: selectedAreaIds, profileImage: pickedImageBase64,
                );
                if (mounted) { Navigator.pop(ctx); _refreshData(); }
              }, child: const Text('Update Worker')),
            ],
          ),
        ),
      );
    });
  }

  void _deleteWorker(Map<String, dynamic> worker) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Worker?'),
      content: Text('Delete staff ${worker["username"]}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
          await LocalDbService.deleteASHAWorker(widget.token, worker['id'].toString());
          if (mounted) { Navigator.pop(ctx); _refreshData(); }
        }, child: const Text('Delete', style: TextStyle(color: Colors.white))),
      ]
    ));
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.user['username'] ?? 'Admin';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF004D40),
        toolbarHeight: 70,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.health_and_safety_rounded, color: Colors.tealAccent, size: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('T7 HealthVault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('ADMIN: $username', style: const TextStyle(fontSize: 10, color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ]),
          ])),
        ]),
        actions: [
          IconButton(
            tooltip: 'Admin Settings',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle),
              child: const Icon(Icons.settings_outlined, size: 20),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminSettingsScreen(token: widget.token, user: widget.user),
                ),
              );
              _refreshData();
            },
          ),
          const LanguageSwitcherWidget(),
          IconButton(tooltip: 'Logout', icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withAlpha(25), shape: BoxShape.circle), child: const Icon(Icons.logout_rounded, size: 20)), onPressed: _handleLogout),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF004D40), boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 4, offset: const Offset(0, 2))]),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.tealAccent,
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
              tabs: [
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.badge_outlined, size: 18), const SizedBox(width: 8), Text(LanguageService.tr('asha_worker'))])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.map_outlined, size: 18), const SizedBox(width: 8), Text(LanguageService.tr('jurisdiction'))])),
                Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.insights_outlined, size: 18), const SizedBox(width: 8), Text(LanguageService.tr('ai_insights'))])),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildASHAWorkersTab(), _buildMasterDataTab(), _buildAnalyticsTab()],
      ),
    );
  }

  Widget _buildASHAWorkersTab() {
    return FutureBuilder<List<dynamic>>(
      future: _workersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final workers = snapshot.data ?? [];
        return Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF004D40), Colors.teal.shade700])),
            child: Row(children: [
              const Expanded(child: Text('Field Staff Directory', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF004D40), minimumSize: const Size(120, 40)),
                onPressed: _showAddWorkerDialog, icon: const Icon(Icons.person_add, size: 18), label: const Text('Add New'),
              ),
            ]),
          ),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: workers.length,
            itemBuilder: (context, index) => _buildWorkerCard(workers[index]),
          )),
        ]);
      },
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker) {
    final name = '${worker['first_name']} ${worker['last_name']}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: const Color(0xFF00796B)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.teal.shade50,
                        backgroundImage: ImageUtils.safeBase64Image(worker['profile_image']),
                        child: worker['profile_image'] == null ? const Icon(Icons.person, color: Color(0xFF00796B)) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? (worker['username'] ?? 'Worker') : name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${worker['id']} • ${worker['phone_number'] ?? 'No Phone'}',
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                worker['state_name'] ?? 'N/A',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF00796B), size: 20),
                        onPressed: () => _showEditWorkerDialog(worker),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteWorker(worker),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterDataTab() {
    return FutureBuilder<List<List<dynamic>>>(
      future: _masterDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final allStates = snapshot.data?[0] ?? [];
        final districts = snapshot.data?[1] ?? [];
        final areas = snapshot.data?[2] ?? [];
        final states = allStates.where((s) => s['name'].toString().toLowerCase().contains(_stateSearchQuery.toLowerCase())).toList();

        return Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _stateSearchController,
                  onChanged: (val) => setState(() => _stateSearchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search States & Jurisdictions...',
                    prefixIcon: const Icon(Icons.search, color: Colors.teal),
                    suffixIcon: _stateSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _stateSearchController.clear();
                              setState(() => _stateSearchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${states.length} States / UTs • ${districts.length} Districts',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF00796B),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminSettingsScreen(token: widget.token, user: widget.user),
                          ),
                        );
                        _refreshData();
                      },
                      icon: const Icon(Icons.settings_outlined, size: 14),
                      label: const Text('Manage in Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: states.isEmpty ? 1 : states.length,
            itemBuilder: (context, index) {
              if (states.isEmpty) {
                if (allStates.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No jurisdictions found.',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Go to Admin Settings to import India states and districts or add custom locations.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00796B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminSettingsScreen(token: widget.token, user: widget.user),
                              ),
                            );
                            _refreshData();
                          },
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: const Text('Open Admin Settings'),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No states found matching "$_stateSearchQuery"',
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }
              }
              return _buildStateCard(states[index], districts, areas);
            },
          )),
        ]);
      },
    );
  }

  Widget _buildStateCard(Map<String, dynamic> state, List<dynamic> allDistricts, List<dynamic> allAreas) {
    final stateId = state['id'].toString();
    final stateDistricts = allDistricts.where((d) => d['state_id'].toString() == stateId).toList();
    final stateAreasCount = allAreas.where((a) {
      final dId = a['district_id']?.toString();
      return stateDistricts.any((d) => d['id'].toString() == dId);
    }).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StateJurisdictionDetailScreen(
                  state: state,
                  districts: allDistricts,
                  areas: allAreas,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flag_rounded, color: Color(0xFF00796B), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state['name'] ?? 'State',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF263238),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${stateDistricts.length} Districts',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                          ),
                          if (stateAreasCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$stateAreasCount Wards',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_workersFuture, _areasFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final workersCount = (snapshot.data?[0] ?? []).length;
        final areasCount = (snapshot.data?[1] ?? []).length;
        return ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8), child: Text('System Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF263238)))),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16,
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildKpiTileGrid('ASHA Workers', '$workersCount', Icons.badge_outlined, Colors.teal),
                _buildKpiTileGrid('Jurisdiction Areas', '$areasCount', Icons.location_city, Colors.indigo),
                _buildKpiTileGrid('DB Status', 'Online', Icons.storage, Colors.green),
                _buildKpiTileGrid('API Status', 'Active', Icons.api, Colors.blue),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.monitor_heart, color: Colors.red.shade400, size: 28), const SizedBox(width: 12), const Text('Vitals Monitoring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF263238)))]),
                const Divider(height: 32),
                _buildBulletPoint('Blood Sugar (Fasting / PP): Active'),
                _buildBulletPoint('Blood Pressure (Systolic / Diastolic): Active'),
                _buildBulletPoint('Temperature & Pulse Monitoring: Active'),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.psychology_outlined, color: Colors.teal, size: 28), const SizedBox(width: 16),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AI Insights Ready', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Sepsis prediction model loaded.', style: TextStyle(fontSize: 12, color: Colors.teal)),
                ])),
              ]),
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildKpiTileGrid(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: Colors.grey.shade100)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 32),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('• ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF455A64), fontWeight: FontWeight.w500))),
    ]));
  }
}
