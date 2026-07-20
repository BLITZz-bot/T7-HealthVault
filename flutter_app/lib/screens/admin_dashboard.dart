import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

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

  late Future<List<dynamic>> _workersFuture;
  late Future<List<dynamic>> _areasFuture;
  late Future<List<dynamic>> _districtsFuture;
  late Future<List<dynamic>> _statesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _workersFuture = ApiService.getASHAWorkers(widget.token);
      _areasFuture = ApiService.getAreas(widget.token);
      _districtsFuture = ApiService.getDistricts(widget.token);
      _statesFuture = ApiService.getStates(widget.token);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // FIX: Use .then() not async/await before showDialog — avoids Windows !_debugDuringDeviceUpdate crash
  void _showAddWorkerDialog() {
    Future.wait([
      ApiService.getStates(widget.token),
      ApiService.getDistricts(widget.token),
      ApiService.getAreas(widget.token),
    ]).then((results) {
      if (!mounted) return;
      final states = results[0];
      final districts = results[1];
      final areas = results[2];

      if (states.isEmpty || districts.isEmpty || areas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least 1 State and 1 Area first.')),
        );
        return;
      }
  
  

      final usernameCtrl = TextEditingController();
      final firstNameCtrl = TextEditingController();
      final lastNameCtrl = TextEditingController();
      final phoneCtrl = TextEditingController();
      final aadhaarCtrl = TextEditingController();

      // FIX: UUIDs from Django are strings, not ints
      String? selectedStateId;
      String? selectedDistrictId;
      List<String> selectedAreaIds = [];

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.person_add, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text('Register ASHA Worker'),
            ]),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username (login name)')),
                  const SizedBox(height: 8),
                  TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name')),
                  const SizedBox(height: 8),
                  TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name')),
                  const SizedBox(height: 8),
                  TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
                  const SizedBox(height: 8),
                  TextField(controller: aadhaarCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '12-digit Aadhaar Number')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStateId,
                    decoration: const InputDecoration(labelText: 'Select State'),
                    items: states.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(
                      value: s['id'].toString(),
                      child: Text(s['name'] ?? 'State'),
                    )).toList(),
                    onChanged: (val) { 
                      if (val != null) {
                        setModalState(() {
                          selectedStateId = val;
                          selectedDistrictId = null;
                          selectedAreaIds.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedStateId != null) ...[
                    DropdownButtonFormField<String>(
                      value: selectedDistrictId,
                      decoration: const InputDecoration(labelText: 'Select District'),
                      items: districts
                          .where((d) => d['state'].toString() == selectedStateId)
                          .map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(
                                value: d['id'].toString(),
                                child: Text(d['name'] ?? 'District'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedDistrictId = val;
                            selectedAreaIds.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (selectedDistrictId == null)
                    const Text('Please select a state and district first to see areas.', style: TextStyle(color: Colors.orange, fontSize: 13))
                  else
                    InkWell(
                      onTap: () async {
                        final stateAreas = areas.where((a) => a['state'].toString() == selectedStateId && a['district'].toString() == selectedDistrictId).toList();
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return StatefulBuilder(
                              builder: (context, setMultiSelectState) {
                                return AlertDialog(
                                  title: const Text('Select Areas'),
                                  content: SizedBox(
                                    width: 300,
                                    height: 300,
                                    child: ListView(
                                      children: stateAreas.map((a) {
                                        final areaId = a['id'].toString();
                                        return CheckboxListTile(
                                          title: Text('${a["village_or_ward"] ?? "Ward"} (${a["district_name"] ?? "District"})'),
                                          value: selectedAreaIds.contains(areaId),
                                          onChanged: (bool? checked) {
                                            setMultiSelectState(() {
                                              if (checked == true) {
                                                selectedAreaIds.add(areaId);
                                              } else {
                                                selectedAreaIds.remove(areaId);
                                              }
                                            });
                                            setModalState(() {});
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Done'),
                                    )
                                  ],
                                );
                              }
                            );
                          }
                        );
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Assigned Jurisdiction Areas', border: OutlineInputBorder()),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(selectedAreaIds.isEmpty ? 'Select Areas' : '${selectedAreaIds.length} Area(s) Selected'),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () async {
                  if (usernameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty && selectedStateId != null) {
                    final ok = await ApiService.addASHAWorker(
                      token: widget.token,
                      username: usernameCtrl.text.trim(),
                      firstName: firstNameCtrl.text.trim(),
                      lastName: lastNameCtrl.text.trim(),
                      phoneNumber: phoneCtrl.text.trim(),
                      aadhaarNumber: aadhaarCtrl.text.trim(),
                      stateId: selectedStateId!,
                      areaIds: selectedAreaIds,
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'ASHA Worker Registered!' : 'Failed. Check all fields.'),
                      backgroundColor: ok ? Colors.green : Colors.redAccent,
                    ));
                    if (ok) _refreshData();
                  }
                },
                child: const Text('Save Worker'),
              ),
            ],
          ),
        ),
      );
    });
  }

    void _showEditWorkerDialog(Map<String, dynamic> worker) {
    Future.wait([
      ApiService.getStates(widget.token),
      ApiService.getDistricts(widget.token),
      ApiService.getAreas(widget.token),
    ]).then((results) {
      if (!mounted) return;
      final states = results[0];
      final districts = results[1];
      final areas = results[2];

      if (states.isEmpty || districts.isEmpty || areas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('States or Areas are missing.')),
        );
        return;
      }

      // Pre-fill text controllers with existing data
      final usernameCtrl = TextEditingController(text: worker['username']);
      final firstNameCtrl = TextEditingController(text: worker['first_name']);
      final lastNameCtrl = TextEditingController(text: worker['last_name']);
      final phoneCtrl = TextEditingController(text: worker['phone_number']);
      final aadhaarCtrl = TextEditingController(text: worker['aadhaar_number']);

      // Find the state and area IDs from the worker object (fallback to first available if not found)
      String? selectedStateId = worker['state'] != null ? worker['state'].toString() : null;
      List<String> selectedAreaIds = List<String>.from(worker['assigned_areas']?.map((id) => id.toString()) ?? []);
      String? selectedDistrictId;
      if (selectedAreaIds.isNotEmpty) {
        final firstAreaId = selectedAreaIds.first;
        final firstArea = areas.firstWhere((a) => a['id'].toString() == firstAreaId, orElse: () => null);
        if (firstArea != null) {
          selectedDistrictId = firstArea['district']?.toString();
        }
      }
      String userId = worker['id'].toString();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.edit, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text('Edit ASHA Worker'),
            ]),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Username (login name)')),
                  const SizedBox(height: 8),
                  TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name')),
                  const SizedBox(height: 8),
                  TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name')),
                  const SizedBox(height: 8),
                  TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
                  const SizedBox(height: 8),
                  TextField(controller: aadhaarCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '12-digit Aadhaar Number')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStateId,
                    decoration: const InputDecoration(labelText: 'Select State'),
                    items: states.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(
                      value: s['id'].toString(),
                      child: Text(s['name'] ?? 'State'),
                    )).toList(),
                    onChanged: (val) { 
                      if (val != null) {
                        setModalState(() {
                          selectedStateId = val;
                          selectedDistrictId = null;
                          selectedAreaIds.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedStateId != null) ...[
                    DropdownButtonFormField<String>(
                      value: selectedDistrictId,
                      decoration: const InputDecoration(labelText: 'Select District'),
                      items: districts
                          .where((d) => d['state'].toString() == selectedStateId)
                          .map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(
                                value: d['id'].toString(),
                                child: Text(d['name'] ?? 'District'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedDistrictId = val;
                            selectedAreaIds.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (selectedDistrictId == null)
                    const Text('Please select a state and district first to see areas.', style: TextStyle(color: Colors.orange, fontSize: 13))
                  else
                    InkWell(
                      onTap: () async {
                        final stateAreas = areas.where((a) => a['state'].toString() == selectedStateId && a['district'].toString() == selectedDistrictId).toList();
                        await showDialog(
                          context: context,
                          builder: (context) {
                            return StatefulBuilder(
                              builder: (context, setMultiSelectState) {
                                return AlertDialog(
                                  title: const Text('Select Areas'),
                                  content: SizedBox(
                                    width: 300,
                                    height: 300,
                                    child: ListView(
                                      children: stateAreas.map((a) {
                                        final areaId = a['id'].toString();
                                        return CheckboxListTile(
                                          title: Text('${a["village_or_ward"] ?? "Ward"} (${a["district_name"] ?? "District"})'),
                                          value: selectedAreaIds.contains(areaId),
                                          onChanged: (bool? checked) {
                                            setMultiSelectState(() {
                                              if (checked == true) {
                                                selectedAreaIds.add(areaId);
                                              } else {
                                                selectedAreaIds.remove(areaId);
                                              }
                                            });
                                            setModalState(() {});
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Done'),
                                    )
                                  ],
                                );
                              }
                            );
                          }
                        );
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Assigned Jurisdiction Areas', border: OutlineInputBorder()),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(selectedAreaIds.isEmpty ? 'Select Areas' : '${selectedAreaIds.length} Area(s) Selected'),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () async {
                  if (usernameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty && selectedStateId != null) {
                    final ok = await ApiService.editASHAWorker(
                      token: widget.token,
                      userId: userId, // Pass the userId here
                      username: usernameCtrl.text.trim(),
                      firstName: firstNameCtrl.text.trim(),
                      lastName: lastNameCtrl.text.trim(),
                      phoneNumber: phoneCtrl.text.trim(),
                      aadhaarNumber: aadhaarCtrl.text.trim(),
                      stateId: selectedStateId!,
                      areaIds: selectedAreaIds,
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'ASHA Worker Updated!' : 'Failed to update worker.'),
                      backgroundColor: ok ? Colors.green : Colors.redAccent,
                    ));
                    if (ok) _refreshData(); // Refresh the list if successful
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      );
    });
  }


  void _showAddAreaDialog() {
    Future.wait([
      ApiService.getStates(widget.token),
      ApiService.getDistricts(widget.token),
    ]).then((results) {
      if (!mounted) return;
      final states = results[0];
      final districts = results[1];

      if (states.isEmpty) { _showAddStateDialog(); return; }

      String selectedStateId = states.first['id'].toString();
      String? selectedDistrictId;

      final blockCtrl = TextEditingController();
      final wardCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.add_location_alt, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text('Add New Jurisdiction Area'),
            ]),
            content: SizedBox(
              width: 400,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: selectedStateId,
                  decoration: const InputDecoration(labelText: 'Select State'),
                  items: states.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(
                    value: s['id'].toString(),
                    child: Text(s['name'] ?? 'State'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        selectedStateId = val;
                        selectedDistrictId = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDistrictId,
                  decoration: const InputDecoration(labelText: 'Select District'),
                  items: districts
                      .where((d) => d['state'].toString() == selectedStateId)
                      .map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(
                            value: d['id'].toString(),
                            child: Text(d['name'] ?? 'District'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedDistrictId = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: blockCtrl, decoration: const InputDecoration(labelText: 'Block Name')),
                const SizedBox(height: 8),
                TextField(controller: wardCtrl, decoration: const InputDecoration(labelText: 'Village / Ward Name')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedDistrictId != null && wardCtrl.text.isNotEmpty) {
                    final ok = await ApiService.addArea(
                      widget.token, selectedDistrictId!,
                      blockCtrl.text.trim(), wardCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'Area Created!' : 'Failed to create area.'),
                      backgroundColor: ok ? Colors.green : Colors.redAccent,
                    ));
                    if (ok) _refreshData();
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

  void _showAddStateDialog() {
    final stateCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New State'),
        content: SizedBox(
          width: 350,
          child: TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: 'State Name (e.g. Karnataka)')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (stateCtrl.text.isNotEmpty) {
                final ok = await ApiService.addState(widget.token, stateCtrl.text.trim());
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'State Created!' : 'Failed. State may already exist.'),
                  backgroundColor: ok ? Colors.green : Colors.redAccent,
                ));
                if (ok) _refreshData();
              }
            },
            child: const Text('Save State'),
          ),
        ],
      ),
    );
  }

  void _showEditStateDialog(Map<String, dynamic> state) {
    final stateCtrl = TextEditingController(text: state['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit State'),
        content: SizedBox(
          width: 350,
          child: TextField(controller: stateCtrl, decoration: const InputDecoration(labelText: 'State Name')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (stateCtrl.text.isNotEmpty) {
                final ok = await ApiService.editState(widget.token, state['id'].toString(), stateCtrl.text.trim());
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'State Updated!' : 'Failed to update state.'),
                  backgroundColor: ok ? Colors.green : Colors.redAccent,
                ));
                if (ok) _refreshData();
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showAddDistrictDialog(String stateId) {
    final districtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add New District'),
        content: SizedBox(
          width: 350,
          child: TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: 'District Name')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (districtCtrl.text.isNotEmpty) {
                final ok = await ApiService.addDistrict(widget.token, stateId, districtCtrl.text.trim());
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'District Created!' : 'Failed to create district.'),
                  backgroundColor: ok ? Colors.green : Colors.redAccent,
                ));
                if (ok) _refreshData();
              }
            },
            child: const Text('Save District'),
          ),
        ],
      ),
    );
  }

  void _showAddDistrictTopLevelDialog() {
    Future.wait([
      ApiService.getStates(widget.token),
    ]).then((results) {
      if (!mounted) return;
      final states = results[0];

      if (states.isEmpty) { _showAddStateDialog(); return; }

      String selectedStateId = states.first['id'].toString();
      final districtCtrl = TextEditingController();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.location_city, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text('Add New District'),
            ]),
            content: SizedBox(
              width: 350,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: selectedStateId,
                  decoration: const InputDecoration(labelText: 'Select State'),
                  items: states.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(
                    value: s['id'].toString(),
                    child: Text(s['name'] ?? 'State'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedStateId = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: 'District Name')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () async {
                  if (districtCtrl.text.isNotEmpty) {
                    final ok = await ApiService.addDistrict(
                      widget.token, selectedStateId, districtCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'District Created!' : 'Failed to create district.'),
                      backgroundColor: ok ? Colors.green : Colors.redAccent,
                    ));
                    if (ok) _refreshData();
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

  void _showEditDistrictDialog(Map<String, dynamic> district) {
    final districtCtrl = TextEditingController(text: district['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit District'),
        content: SizedBox(
          width: 350,
          child: TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: 'District Name')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (districtCtrl.text.isNotEmpty) {
                final ok = await ApiService.editDistrict(widget.token, district['id'].toString(), district['state'].toString(), districtCtrl.text.trim());
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'District Updated!' : 'Failed to update district.'),
                  backgroundColor: ok ? Colors.green : Colors.redAccent,
                ));
                if (ok) _refreshData();
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showEditAreaDialog(Map<String, dynamic> area) {
    Future.wait([
      ApiService.getStates(widget.token),
      ApiService.getDistricts(widget.token),
    ]).then((results) {
      if (!mounted) return;
      final states = results[0];
      final districts = results[1];

      if (states.isEmpty) { 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No states available')));
        return; 
      }

      final blockCtrl = TextEditingController(text: area['block']);
      final wardCtrl = TextEditingController(text: area['village_or_ward']);
      String selectedStateId = area['state']?.toString() ?? states.first['id'].toString();
      String? selectedDistrictId = area['district']?.toString();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.edit_location_alt, color: Color(0xFF00796B)),
              SizedBox(width: 8),
              Text('Edit Jurisdiction Area'),
            ]),
            content: SizedBox(
              width: 400,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: selectedStateId,
                  decoration: const InputDecoration(labelText: 'Select State'),
                  items: states.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(
                    value: s['id'].toString(),
                    child: Text(s['name'] ?? 'State'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        selectedStateId = val;
                        selectedDistrictId = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDistrictId,
                  decoration: const InputDecoration(labelText: 'Select District'),
                  items: districts
                      .where((d) => d['state'].toString() == selectedStateId)
                      .map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(
                            value: d['id'].toString(),
                            child: Text(d['name'] ?? 'District'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedDistrictId = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: blockCtrl, decoration: const InputDecoration(labelText: 'Block Name')),
                const SizedBox(height: 8),
                TextField(controller: wardCtrl, decoration: const InputDecoration(labelText: 'Village / Ward Name')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedDistrictId != null && wardCtrl.text.isNotEmpty) {
                    final ok = await ApiService.editArea(
                      widget.token, area['id'].toString(), selectedDistrictId!,
                      blockCtrl.text.trim(), wardCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ok ? 'Area Updated!' : 'Failed to update area.'),
                      backgroundColor: ok ? Colors.green : Colors.redAccent,
                    ));
                    if (ok) _refreshData();
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _deleteState(Map<String, dynamic> state) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete State?'),
      content: Text('Are you sure you want to delete ${state["name"]}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            final ok = await ApiService.deleteState(widget.token, state['id'].toString());
            if (!mounted) return;
            Navigator.pop(ctx);
            if (ok) _refreshData();
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        )
      ]
    ));
  }

  void _deleteDistrict(Map<String, dynamic> district) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete District?'),
      content: Text('Are you sure you want to delete ${district["name"]}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            final ok = await ApiService.deleteDistrict(widget.token, district['id'].toString());
            if (!mounted) return;
            Navigator.pop(ctx);
            if (ok) _refreshData();
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        )
      ]
    ));
  }

  void _deleteArea(Map<String, dynamic> area) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Area?'),
      content: Text('Are you sure you want to delete ${area["village_or_ward"]}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            final ok = await ApiService.deleteArea(widget.token, area['id'].toString());
            if (!mounted) return;
            Navigator.pop(ctx);
            if (ok) _refreshData();
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        )
      ]
    ));
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.user['username'] ?? 'Admin';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('T7 HealthVault Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Logged in as: $username', style: const TextStyle(fontSize: 11, color: Colors.tealAccent)),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Logout', icon: const Icon(Icons.logout), onPressed: _handleLogout),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BFA5),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined), text: 'Workers'),
            Tab(icon: Icon(Icons.map_outlined), text: 'Master Data'),
            Tab(icon: Icon(Icons.insights_outlined), text: 'Analytics'),
          ],
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
          ]));
        }

        final workers = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00796B)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.people_alt, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ASHA Worker Directory', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${workers.length} worker(s) registered', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Registered Field Workers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showAddWorkerDialog,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Worker'),
              ),
            ]),
            const SizedBox(height: 14),
            if (workers.isEmpty)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: const Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(children: [
                    Icon(Icons.person_off_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No ASHA Workers registered yet.', style: TextStyle(fontSize: 15, color: Colors.grey)),
                    SizedBox(height: 4),
                    Text('Tap "Add Worker" above to register one.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ]),
                ),
              )
            else
              ...workers.map((w) => _buildWorkerCard(w)),
          ],
        );
      },
    );
  }

  void _deleteWorker(Map<String, dynamic> worker) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Worker?'),
      content: Text('Are you sure you want to delete ${worker["username"]}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            final ok = await ApiService.deleteASHAWorker(widget.token, worker['id'].toString());
            if (!mounted) return;
            Navigator.pop(ctx);
            if (ok) _refreshData();
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        )
      ]
    ));
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker) {
    final uname = worker['username'] ?? 'User';
    final fname = worker['first_name'] ?? '';
    final lname = worker['last_name'] ?? '';
    final name = '$fname $lname'.trim();
    final displayName = name.isNotEmpty ? name : uname;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';
    final phone = worker['phone_number'] ?? 'N/A';
    final aadhaar = worker['aadhaar_number'] ?? 'N/A';
    final List<dynamic> areaNamesRaw = worker['area_names'] ?? [];
    final String areaDisplay = areaNamesRaw.isNotEmpty ? areaNamesRaw.join(', ') : 'N/A';
    final stateName = worker['state_name'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.teal.shade100,
              child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF004D40))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('@$uname', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            Chip(
              backgroundColor: Colors.green.shade50,
              side: BorderSide.none,
              label: Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.teal, size: 20),
                  onPressed: () => _showEditWorkerDialog(worker),
                ),
                IconButton(
                  tooltip: 'Delete Worker',
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _deleteWorker(worker),
                ),
              ],
            ),
          ]),
          const Divider(height: 20),
          Wrap(spacing: 16, runSpacing: 6, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.phone, size: 15, color: Colors.teal),
              const SizedBox(width: 4),
              Text(phone, style: const TextStyle(fontSize: 13)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.credit_card, size: 15, color: Colors.teal),
              const SizedBox(width: 4),
              Text('Aadhaar: $aadhaar', style: const TextStyle(fontSize: 13)),
            ]),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.location_on, size: 14, color: Color(0xFF00796B)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                '$areaDisplay — $stateName',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF004D40)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildMasterDataTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_statesFuture, _districtsFuture, _areasFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final states = snapshot.data?[0] ?? [];
        final districts = snapshot.data?[1] ?? [];
        final areas = snapshot.data?[2] ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Master Jurisdictions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Row(children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(color: Color(0xFF00796B)),
                    foregroundColor: const Color(0xFF00796B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showAddStateDialog,
                  icon: const Icon(Icons.flag, size: 15),
                  label: const Text('+ State'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(color: Color(0xFF00796B)),
                    foregroundColor: const Color(0xFF00796B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showAddDistrictTopLevelDialog,
                  icon: const Icon(Icons.location_city, size: 15),
                  label: const Text('+ District'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showAddAreaDialog,
                  icon: const Icon(Icons.add_location, size: 15),
                  label: const Text('+ Area'),
                ),
              ]),
            ]),
            const SizedBox(height: 16),

            Builder(
              builder: (context) {
                final stateNames = {for (var s in states) s['id'].toString(): s['name']};
                final districtMap = {for (var d in districts) d['id'].toString(): d};
                
                Map<String, Map<String, List<dynamic>>> hierarchy = {};
                
                for (var s in states) {
                  hierarchy[s['name']] = {};
                }

                for (var d in districts) {
                  String stateId = d['state'].toString();
                  final stateObj = states.firstWhere((s) => s['id'].toString() == stateId, orElse: () => null);
                  if (stateObj != null) {
                    hierarchy[stateObj['name']]![d['name']] = [];
                  }
                }

                for (var area in areas) {
                  String districtId = area['district'].toString();
                  var districtData = districtMap[districtId];
                  if (districtData != null) {
                    String stateId = districtData['state'].toString();
                    final stateObj = states.firstWhere((s) => s['id'].toString() == stateId, orElse: () => null);
                    if (stateObj != null) {
                      hierarchy[stateObj['name']]![districtData['name']]!.add(area);
                    }
                  }
                }

                if (hierarchy.isEmpty) {
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: const Padding(
                      padding: EdgeInsets.all(36),
                      child: Column(children: [
                        Icon(Icons.location_off, size: 48, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('No States or Areas yet.', style: TextStyle(color: Colors.grey)),
                        Text('Tap "+ State" then "+ Area" to get started.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    ),
                  );
                }

                return Column(
                  children: hierarchy.entries.map((stateEntry) {
                    String stateName = stateEntry.key;
                    Map<String, List<dynamic>> stateDistricts = stateEntry.value;
                    
                    final stateObj = states.firstWhere(
                      (s) => s['name'] == stateName,
                      orElse: () => null,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: const Icon(Icons.flag, color: Colors.teal),
                        title: Text(stateName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (stateObj != null) ...[
                              IconButton(
                                tooltip: 'Edit State',
                                icon: const Icon(Icons.edit, size: 20, color: Colors.teal),
                                onPressed: () => _showEditStateDialog(stateObj),
                              ),
                              IconButton(
                                tooltip: 'Delete State',
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () => _deleteState(stateObj),
                              ),
                            ]
                          ],
                        ),
                        children: stateDistricts.isEmpty 
                            ? [const Padding(padding: EdgeInsets.all(16), child: Text('No districts added yet', style: TextStyle(color: Colors.grey)))]
                            : stateDistricts.entries.map((districtEntry) {
                          String districtName = districtEntry.key;
                          List<dynamic> districtAreas = districtEntry.value;
                          
                          final districtObj = districts.firstWhere(
                            (d) => d['name'] == districtName && d['state'].toString() == stateObj?['id']?.toString(),
                            orElse: () => null,
                          );
                          
                          return Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: ExpansionTile(
                              leading: const Icon(Icons.location_city, color: Colors.teal),
                              title: Row(
                                children: [
                                  Expanded(child: Text(districtName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  if (districtObj != null) ...[
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.teal, size: 18),
                                      onPressed: () => _showEditDistrictDialog(districtObj),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete District',
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                      onPressed: () => _deleteDistrict(districtObj),
                                    ),
                                  ]
                                ],
                              ),
                              children: districtAreas.isEmpty
                                ? [const Padding(padding: EdgeInsets.only(left: 54.0, bottom: 16.0), child: Align(alignment: Alignment.centerLeft, child: Text('No areas added yet', style: TextStyle(color: Colors.grey))))]
                                : districtAreas.map((area) {
                                return ListTile(
                                  contentPadding: const EdgeInsets.only(left: 54.0, right: 16.0),
                                  leading: const Icon(Icons.map_outlined, size: 20, color: Colors.grey),
                                  title: Text(area['village_or_ward'] ?? 'Unnamed Area'),
                                  subtitle: Text('Block: ${area['block'] ?? '-'}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.teal, size: 20),
                                        onPressed: () => _showEditAreaDialog(area),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete Area',
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () => _deleteArea(area),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                );
              }
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return FutureBuilder<List<dynamic>>(
      future: _workersFuture,
      builder: (context, workersSnap) {
        return FutureBuilder<List<dynamic>>(
          future: _areasFuture,
          builder: (context, areasSnap) {
            final workersCount = (workersSnap.data ?? []).length;
            final areasCount = (areasSnap.data ?? []).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('System Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12, mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildKpiTile('ASHA Workers', '$workersCount', Icons.badge_outlined, Colors.teal),
                    _buildKpiTile('Jurisdiction Areas', '$areasCount', Icons.location_city, Colors.indigo),
                    _buildKpiTile('DB Status', 'Online', Icons.storage, Colors.green),
                    _buildKpiTile('API Status', 'Active', Icons.api, Colors.blue),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.monitor_heart, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Vitals Monitoring', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                      Divider(height: 24),
                      Text('• Blood Sugar (Fasting / PP): Active'),
                      SizedBox(height: 6),
                      Text('• Blood Pressure (Systolic / Diastolic): Active'),
                      SizedBox(height: 6),
                      Text('• Temperature & Pulse Monitoring: Active'),
                    ]),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKpiTile(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 28),
        const Spacer(),
        Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}
