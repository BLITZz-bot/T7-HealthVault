import 'package:flutter/material.dart';
import '../services/local_db_service.dart';
import '../services/app_update_service.dart';
import '../widgets/language_switcher_widget.dart';
import '../widgets/searchable_dropdown.dart';
import 'master_jurisdiction_editor_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const AdminSettingsScreen({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _isSeeding = false;
  bool _isClearing = false;
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    setState(() {
      _statsFuture = LocalDbService.getSystemStats();
    });
  }

  Future<void> _handleSeedIndiaData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Import India Jurisdictions'),
          ],
        ),
        content: const Text(
          'This will populate your database with all 36 Indian States/UTs and ~700+ Districts.\n\nExisting states and districts will be preserved without duplicates.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download_done_rounded, size: 18),
            label: const Text('Import All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSeeding = true);
    try {
      final result = await LocalDbService.seedIndiaData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Success! Added ${result['states']} States and ${result['districts']} Districts.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF004D40),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error seeding data: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSeeding = false);
        _loadStats();
      }
    }
  }

  void _showAddStateDialog() {
    final stateCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.flag, color: Color(0xFF00796B)),
            SizedBox(width: 8),
            Text('Add State'),
          ],
        ),
        content: TextField(
          controller: stateCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'State / UT Name',
            hintText: 'e.g. Karnataka',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
            onPressed: () async {
              if (stateCtrl.text.trim().isNotEmpty) {
                await LocalDbService.addState(widget.token, stateCtrl.text.trim());
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadStats();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added State: ${stateCtrl.text.trim()}')),
                  );
                }
              }
            },
            child: const Text('Save State'),
          ),
        ],
      ),
    );
  }

  void _showAddDistrictDialog() {
    Future.wait([LocalDbService.getStates(widget.token)]).then((results) {
      if (!mounted) return;
      final states = results[0];
      if (states.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add or import States first.')),
        );
        return;
      }

      String? selectedStateId;
      final districtCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.location_city, color: Color(0xFF00796B)),
                SizedBox(width: 8),
                Text('Add District'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdown<dynamic>(
                    items: states,
                    labelText: 'Select State',
                    itemToString: (s) => s['name'] ?? 'State',
                    onChanged: (val) => setModalState(() => selectedStateId = val?['id'].toString()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: districtCtrl,
                    decoration: const InputDecoration(
                      labelText: 'District Name',
                      hintText: 'e.g. Mysuru',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedStateId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a State first.')));
                    return;
                  }
                  if (districtCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a District Name.')));
                    return;
                  }
                  await LocalDbService.addDistrict(widget.token, selectedStateId!, districtCtrl.text.trim());
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadStats();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added District: ${districtCtrl.text.trim()}')),
                    );
                  }
                },
                child: const Text('Save District'),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showAddAreaDialog() {
    Future.wait([
      LocalDbService.getStates(widget.token),
      LocalDbService.getDistricts(widget.token),
    ]).then((results) {
      if (!mounted) return;
      final states = results[0];
      final districts = results[1];

      if (states.isEmpty || districts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add or import States and Districts first.')),
        );
        return;
      }

      String? selectedStateId;
      String? selectedDistrictId;
      final blockCtrl = TextEditingController();
      final wardCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_location, color: Color(0xFF00796B)),
                SizedBox(width: 8),
                Text('Add Area / Village / Ward'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchableDropdown<dynamic>(
                    items: states,
                    labelText: 'Select State',
                    itemToString: (s) => s['name'] ?? 'State',
                    onChanged: (val) => setModalState(() {
                      selectedStateId = val?['id'].toString();
                      selectedDistrictId = null;
                    }),
                  ),
                  if (selectedStateId != null) ...[
                    const SizedBox(height: 12),
                    SearchableDropdown<dynamic>(
                      items: districts.where((d) => d['state_id'].toString() == selectedStateId).toList(),
                      labelText: 'Select District',
                      itemToString: (d) => d['name'] ?? 'District',
                      onChanged: (val) => setModalState(() => selectedDistrictId = val?['id'].toString()),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: blockCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Block / Taluk Name',
                      hintText: 'e.g. Block A',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: wardCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Village / Ward Name',
                      hintText: 'e.g. Ward 4 / Rampur',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedDistrictId == null || wardCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a district and enter village/ward name.')),
                    );
                    return;
                  }
                  await LocalDbService.addArea(
                    widget.token,
                    selectedDistrictId!,
                    blockCtrl.text.trim(),
                    wardCtrl.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadStats();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added Area: ${wardCtrl.text.trim()}')),
                    );
                  }
                },
                child: const Text('Save Area'),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _handleClearJurisdictions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('Reset Master Data?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove all States, Districts, and Areas from the database?\n\n(Worker and family health records will remain intact).',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Jurisdictions'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isClearing = true);
    try {
      await LocalDbService.clearAllJurisdictions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Jurisdiction data cleared successfully.'),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting data: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
        _loadStats();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.user['username'] ?? 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF004D40),
        toolbarHeight: 65,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
            Text(
              'Master Data & System Preferences',
              style: TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: const [
          LanguageSwitcherWidget(),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00796B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF004D40).withAlpha(40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withAlpha(40),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.tealAccent, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administrator: $username',
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withAlpha(50),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Superuser • Offline Vault Mode',
                            style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Master Data / Jurisdictions Section
            _buildSectionHeader(
              icon: Icons.public_rounded,
              title: 'India Jurisdictions Master Data',
              subtitle: 'Import all 36 Indian states & districts or add custom locations',
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Auto-Import Card
                  FutureBuilder<Map<String, int>>(
                    future: _statsFuture,
                    builder: (context, snapshot) {
                      final statesCount = snapshot.data?['states'] ?? 0;
                      final isFullyImported = statesCount >= 36;
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isFullyImported ? Colors.green.shade50 : Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isFullyImported ? Icons.check_circle_rounded : Icons.bolt_rounded,
                                    color: isFullyImported ? Colors.green.shade700 : const Color(0xFF00796B),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Auto-Import India Data',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          if (isFullyImported) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '36/36 Loaded',
                                                style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isFullyImported
                                            ? 'All 36 States/UTs and ~700+ Districts are loaded in the database.'
                                            : 'Directly loads all 36 States/UTs and ~700+ Districts without manual entry.',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: _isSeeding
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8.0),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2.5),
                                        ),
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFullyImported ? Colors.grey.shade100 : const Color(0xFF00796B),
                                        foregroundColor: isFullyImported ? Colors.teal.shade800 : Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      onPressed: _handleSeedIndiaData,
                                      icon: Icon(isFullyImported ? Icons.sync_rounded : Icons.download_rounded, size: 18),
                                      label: Text(
                                        isFullyImported ? 'Re-sync All 36 States & Districts' : '📥 Import Master Data (~700+ Districts)',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),

                  // Manual Add Section Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Manual Jurisdiction Additions',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  ),

                  // Manual Add Buttons Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF004D40),
                              side: BorderSide(color: Colors.teal.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _showAddStateDialog,
                            icon: const Icon(Icons.flag_outlined, size: 16),
                            label: const Text('+ State', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF004D40),
                              side: BorderSide(color: Colors.teal.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _showAddDistrictDialog,
                            icon: const Icon(Icons.location_city_outlined, size: 16),
                            label: const Text('+ District', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF004D40),
                              side: BorderSide(color: Colors.teal.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _showAddAreaDialog,
                            icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                            label: const Text('+ Area', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Manage & Edit All Jurisdictions Tile
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MasterJurisdictionEditorScreen(
                            token: widget.token,
                            user: widget.user,
                          ),
                        ),
                      );
                      setState(() {
                        _statsFuture = LocalDbService.getSystemStats();
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFF00796B), size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Manage & Edit Jurisdictions',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF263238)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Open full editor to rename or delete states, districts & areas.',
                                  style: TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black38),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // Reset Master Data Tile
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade400, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Clear Jurisdictions Data',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.redAccent),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Remove all loaded states, districts, and areas.',
                                style: TextStyle(fontSize: 11, color: Colors.black45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isClearing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: BorderSide(color: Colors.red.shade200),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                onPressed: _handleClearJurisdictions,
                                child: const Text('Reset', style: TextStyle(fontSize: 12)),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Live Database Statistics Section
            _buildSectionHeader(
              icon: Icons.analytics_outlined,
              title: 'Vault Statistics',
              subtitle: 'Current records stored in the encrypted local database',
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, int>>(
              future: _statsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                }
                final stats = snapshot.data ?? {};
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            'States / UTs',
                            '${stats['states'] ?? 0}',
                            Icons.flag_rounded,
                            Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatTile(
                            'Districts',
                            '${stats['districts'] ?? 0}',
                            Icons.location_city_rounded,
                            Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatTile(
                            'Areas / Wards',
                            '${stats['areas'] ?? 0}',
                            Icons.place_rounded,
                            Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            'ASHA Staff',
                            '${stats['workers'] ?? 0}',
                            Icons.badge_rounded,
                            Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatTile(
                            'Families',
                            '${stats['families'] ?? 0}',
                            Icons.family_restroom_rounded,
                            Colors.amber.shade800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatTile(
                            'Members',
                            '${stats['members'] ?? 0}',
                            Icons.people_alt_rounded,
                            Colors.teal.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // System Information Section
            _buildSectionHeader(
              icon: Icons.info_outline_rounded,
              title: 'System Information',
              subtitle: 'Offline security architecture and app details',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Platform', 'T7 HealthVault v1.0.0'),
                  const Divider(height: 20),
                  _buildInfoRow('Database Engine', 'SQLite (Encrypted Local Storage)'),
                  const Divider(height: 20),
                  _buildInfoRow('Network Mode', '100% Offline-First (No Internet Required)'),
                  const Divider(height: 20),
                  _buildInfoRow('Language Support', '22 Official Indian Languages Built-in'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // App Updates Section
            _buildSectionHeader(
              icon: Icons.system_update_rounded,
              title: 'App Updates & Releases',
              subtitle: 'Check for the latest APK releases directly from GitHub',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF00796B), size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Version: v${AppUpdateService.currentVersion}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Auto-built via GitHub Releases CI/CD',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => AppUpdateService.checkAndPromptUpdate(context),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF004D40).withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF004D40)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
          ),
        ),
      ],
    );
  }
}
