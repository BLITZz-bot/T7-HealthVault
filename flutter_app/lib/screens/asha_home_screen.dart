import 'package:flutter/material.dart';
import '../services/local_db_service.dart';
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
    Future.wait([
      LocalDbService.getStates(widget.token),
      LocalDbService.getDistricts(widget.token),
      LocalDbService.getAreas(widget.token),
    ]).then((results) {
      if (!mounted) return;
      final states = results[0];
      final districts = results[1];
      final areas = results[2];

      if (states.isEmpty || districts.isEmpty || areas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('States, Districts, or Areas are missing. Please contact admin.')),
        );
        return;
      }

      final headNameController = TextEditingController();
      final houseNoController = TextEditingController();
      final contactController = TextEditingController();

      String? selectedStateId;
      String? selectedDistrictId;
      String? selectedAreaId;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: const Text('Add New Family'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: headNameController, decoration: const InputDecoration(labelText: 'Head of Family Name')),
                  const SizedBox(height: 12),
                  TextField(controller: houseNoController, decoration: const InputDecoration(labelText: 'House Number')),
                  const SizedBox(height: 12),
                  TextField(controller: contactController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact Number')),
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
                          selectedAreaId = null;
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
                            selectedAreaId = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (selectedDistrictId != null) ...[
                    DropdownButtonFormField<String>(
                      value: selectedAreaId,
                      decoration: const InputDecoration(labelText: 'Select Area / Village'),
                      items: areas
                          .where((a) => a['district'].toString() == selectedDistrictId)
                          .map<DropdownMenuItem<String>>((a) => DropdownMenuItem<String>(
                                value: a['id'].toString(),
                                child: Text('${a['village_or_ward']} (Block: ${a['block']})'),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedAreaId = val);
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
                    if (mounted) Navigator.pop(context);
                    if (success) {
                      _refreshFamilies();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Family Added Successfully!')));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields.')));
                  }
                },
                child: const Text('Save Family'),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
     // 1. Extract the user details safely
    final fname = widget.user['first_name'] ?? '';
    final lname = widget.user['last_name'] ?? '';
    final name = '$fname $lname'.trim().isNotEmpty ? '$fname $lname'.trim() : widget.user['username'];
    final phone = widget.user['phone_number'] ?? 'N/A';
    
    // 2. Extract State and Area details
    final stateName = widget.user['state_name'] ?? 'N/A';
    final List<dynamic> areaNamesRaw = widget.user['area_names'] ?? [];
    final String areaDisplay = areaNamesRaw.isNotEmpty ? areaNamesRaw.join(', ') : 'No Area Assigned';
    return Scaffold(
      appBar: AppBar(
        title: Text('ASHA Portal (${widget.user['first_name'] ?? widget.user['username']})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Assigned Jurisdiction Header Card
                    // Assigned Jurisdiction Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.teal.shade100.withOpacity(0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Worker Name and Phone Row
                Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF00897B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Worker: $name | Phone: $phone',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.teal.shade900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // State and Assigned Areas Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF00897B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'State: $stateName\nAreas: $areaDisplay',
                        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.teal.shade900),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),


          // Families List
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _familiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading data: ${snapshot.error}'));
                }

                final families = snapshot.data ?? [];
                if (families.isEmpty) {
                  return const Center(child: Text('No families registered in your area yet. Tap + to add one.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: families.length,
                  itemBuilder: (context, i) {
                    final family = families[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: const Icon(Icons.home, color: Color(0xFF00897B)),
                        ),
                        title: Text(family['family_head_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('House No: ${family['house_number']} • Contact: ${family['contact_number'] ?? 'N/A'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FamilyDetailScreen(
                                family: family,
                                token: widget.token,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFamilyDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Family'),
        backgroundColor: const Color(0xFF00897B),
      ),
    );
  }
}
