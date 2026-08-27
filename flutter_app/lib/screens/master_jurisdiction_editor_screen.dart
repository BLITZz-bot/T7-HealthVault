import 'package:flutter/material.dart';
import '../services/local_db_service.dart';
import '../widgets/language_switcher_widget.dart';
import '../widgets/searchable_dropdown.dart';

class MasterJurisdictionEditorScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const MasterJurisdictionEditorScreen({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<MasterJurisdictionEditorScreen> createState() => _MasterJurisdictionEditorScreenState();
}

class _MasterJurisdictionEditorScreenState extends State<MasterJurisdictionEditorScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<List<List<dynamic>>> _masterDataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _masterDataFuture = Future.wait([
        LocalDbService.getStates(widget.token),
        LocalDbService.getDistricts(widget.token),
        LocalDbService.getAreas(widget.token),
      ]);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _firstWhereOrNull(List<dynamic> list, bool Function(dynamic) test) {
    for (var element in list) {
      if (test(element)) return element as Map<String, dynamic>;
    }
    return null;
  }

  void _showAddStateDialog() {
    final stateCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.flag, color: Color(0xFF00796B)),
          SizedBox(width: 8),
          Text('Add State'),
        ]),
        content: TextField(
          controller: stateCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'State Name', border: OutlineInputBorder()),
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
                  _loadData();
                }
              }
            },
            child: const Text('Save State'),
          ),
        ],
      ),
    );
  }

  void _showAddDistrictDialog(List<dynamic> states) {
    String? selectedStateId;
    final districtCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.location_city, color: Color(0xFF00796B)),
            SizedBox(width: 8),
            Text('Add District'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableDropdown<dynamic>(
                items: states,
                labelText: 'Select State',
                itemToString: (s) => s['name'] ?? 'State',
                onChanged: (val) => setModalState(() => selectedStateId = val?['id'].toString()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: districtCtrl,
                decoration: const InputDecoration(labelText: 'District Name', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedStateId != null && districtCtrl.text.trim().isNotEmpty) {
                  await LocalDbService.addDistrict(widget.token, selectedStateId!, districtCtrl.text.trim());
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                }
              },
              child: const Text('Save District'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAreaDialog(List<dynamic> states, List<dynamic> districts) {
    String? selectedStateId;
    String? selectedDistrictId;
    final blockCtrl = TextEditingController();
    final wardCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.add_location, color: Color(0xFF00796B)),
            SizedBox(width: 8),
            Text('Add Area / Village / Ward'),
          ]),
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
                TextField(controller: blockCtrl, decoration: const InputDecoration(labelText: 'Block / Taluk', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: wardCtrl, decoration: const InputDecoration(labelText: 'Village / Ward Name', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedDistrictId != null && wardCtrl.text.trim().isNotEmpty) {
                  await LocalDbService.addArea(widget.token, selectedDistrictId!, blockCtrl.text.trim(), wardCtrl.text.trim());
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                }
              },
              child: const Text('Save Area'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStateDialog(Map<String, dynamic> state) {
    final stateCtrl = TextEditingController(text: state['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit State Name'),
        content: TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: 'State Name', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
            onPressed: () async {
              if (stateCtrl.text.trim().isNotEmpty) {
                await LocalDbService.editState(widget.token, state['id'].toString(), stateCtrl.text.trim());
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showEditDistrictDialog(Map<String, dynamic> district) {
    final districtCtrl = TextEditingController(text: district['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit District Name'),
        content: TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: 'District Name', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
            onPressed: () async {
              if (districtCtrl.text.trim().isNotEmpty) {
                await LocalDbService.editDistrict(
                  widget.token,
                  district['id'].toString(),
                  district['state_id'].toString(),
                  districtCtrl.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showEditAreaDialog(Map<String, dynamic> area, List<dynamic> states, List<dynamic> districts) {
    final blockCtrl = TextEditingController(text: area['block']);
    final wardCtrl = TextEditingController(text: area['village_or_ward']);
    String? selectedDistrictId = area['district_id']?.toString();
    String? selectedStateId;
    if (selectedDistrictId != null) {
      final d = _firstWhereOrNull(districts, (d) => d['id'].toString() == selectedDistrictId);
      if (d != null) selectedStateId = d['state_id']?.toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Area / Village'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchableDropdown<dynamic>(
                  items: states,
                  labelText: 'Select State',
                  itemToString: (s) => s['name'] ?? 'State',
                  initialValue: _firstWhereOrNull(states, (s) => s['id'].toString() == selectedStateId),
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
                    initialValue: _firstWhereOrNull(districts, (d) => d['id'].toString() == selectedDistrictId),
                    onChanged: (val) => setModalState(() => selectedDistrictId = val?['id'].toString()),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(controller: blockCtrl, decoration: const InputDecoration(labelText: 'Block', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: wardCtrl, decoration: const InputDecoration(labelText: 'Village/Ward', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
              onPressed: () async {
                if (selectedDistrictId != null && wardCtrl.text.trim().isNotEmpty) {
                  await LocalDbService.editArea(
                    widget.token,
                    area['id'].toString(),
                    selectedDistrictId!,
                    blockCtrl.text.trim(),
                    wardCtrl.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteState(Map<String, dynamic> state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete State?'),
        content: Text('Are you sure you want to delete ${state["name"]} and all its districts/areas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await LocalDbService.deleteState(widget.token, state['id'].toString());
              if (mounted) {
                Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteDistrict(Map<String, dynamic> district) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete District?'),
        content: Text('Delete ${district["name"]} and its assigned areas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await LocalDbService.deleteDistrict(widget.token, district['id'].toString());
              if (mounted) {
                Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteArea(Map<String, dynamic> area) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Area?'),
        content: Text('Delete ${area["village_or_ward"]}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await LocalDbService.deleteArea(widget.token, area['id'].toString());
              if (mounted) {
                Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF004D40),
        toolbarHeight: 65,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Master Jurisdiction Editor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('Full Edit & Delete Access', style: TextStyle(fontSize: 11, color: Colors.tealAccent)),
          ],
        ),
        actions: const [
          LanguageSwitcherWidget(),
          SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<List<dynamic>>>(
        future: _masterDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allStates = snapshot.data?[0] ?? [];
          final allDistricts = snapshot.data?[1] ?? [];
          final allAreas = snapshot.data?[2] ?? [];

          final filteredStates = allStates
              .where((s) => s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          return Column(
            children: [
              // Search & Add Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 4)],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search states to edit/delete...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF00796B)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; }))
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00796B), side: BorderSide(color: Colors.teal.shade200)),
                            onPressed: _showAddStateDialog,
                            icon: const Icon(Icons.flag, size: 14),
                            label: const Text('+ State', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00796B), side: BorderSide(color: Colors.teal.shade200)),
                            onPressed: () => _showAddDistrictDialog(allStates),
                            icon: const Icon(Icons.location_city, size: 14),
                            label: const Text('+ District', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF00796B), side: BorderSide(color: Colors.teal.shade200)),
                            onPressed: () => _showAddAreaDialog(allStates, allDistricts),
                            icon: const Icon(Icons.add_location, size: 14),
                            label: const Text('+ Area', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // States List with Edit & Delete Controls
              Expanded(
                child: filteredStates.isEmpty
                    ? const Center(child: Text('No matching states found.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filteredStates.length,
                        itemBuilder: (context, index) {
                          final state = filteredStates[index];
                          final stateId = state['id'].toString();
                          final stateDistricts = allDistricts.where((d) => d['state_id'].toString() == stateId).toList();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              leading: const Icon(Icons.flag, color: Color(0xFF00796B)),
                              title: Text(state['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                              subtitle: Text('${stateDistricts.length} Districts', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.teal),
                                    onPressed: () => _showEditStateDialog(state),
                                    tooltip: 'Edit State',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    onPressed: () => _deleteState(state),
                                    tooltip: 'Delete State',
                                  ),
                                  const Icon(Icons.expand_more),
                                ],
                              ),
                              children: stateDistricts.map((district) {
                                final districtId = district['id'].toString();
                                final districtAreas = allAreas.where((a) => a['district_id'].toString() == districtId).toList();
                                return ExpansionTile(
                                  dense: true,
                                  title: Text(district['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text('${districtAreas.length} Areas', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.teal),
                                        onPressed: () => _showEditDistrictDialog(district),
                                        tooltip: 'Edit District',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                        onPressed: () => _deleteDistrict(district),
                                        tooltip: 'Delete District',
                                      ),
                                      const Icon(Icons.expand_more, size: 18),
                                    ],
                                  ),
                                  children: districtAreas.map((area) {
                                    return ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.only(left: 48, right: 16),
                                      title: Text(area['village_or_ward'] ?? 'Area', style: const TextStyle(fontSize: 13)),
                                      subtitle: Text('Block: ${area['block'] ?? 'N/A'}', style: const TextStyle(fontSize: 11)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.teal),
                                            onPressed: () => _showEditAreaDialog(area, allStates, allDistricts),
                                            tooltip: 'Edit Area',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                            onPressed: () => _deleteArea(area),
                                            tooltip: 'Delete Area',
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
