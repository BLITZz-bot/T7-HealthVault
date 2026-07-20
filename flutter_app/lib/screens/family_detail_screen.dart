import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
      _membersFuture = ApiService.getMembers(widget.token).then((allMembers) {
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Add Family Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 12),
                TextField(controller: ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Age')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: gender,
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
                  final ok = await ApiService.addMember(
                    widget.token,
                    widget.family['id'].toString(),
                    nameCtrl.text,
                    age,
                    gender,
                    relCtrl.text,
                  );
                  if (mounted) Navigator.pop(ctx);
                  if (ok) {
                    _refreshMembers();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member added successfully!')));
                  }
                }
              },
              child: const Text('Save Member'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Family of ${widget.family['family_head_name']}'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.teal.shade50,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('House No: ${widget.family['house_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Contact: ${widget.family['contact_number'] ?? 'N/A'}'),
              ],
            ),
          ),
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
                  return const Center(child: Text('No members added yet.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade100,
                          child: Icon(
                            member['gender'] == 'male' ? Icons.male : (member['gender'] == 'female' ? Icons.female : Icons.person),
                            color: Colors.teal.shade800,
                          ),
                        ),
                        title: Text(member['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Age: ${member['age']} | Rel: ${member['relationship_to_head']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.medical_services, color: Colors.indigo),
                          tooltip: 'Health Records',
                          onPressed: () {
                            // TODO: Add Medical Records later
                          },
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
        backgroundColor: const Color(0xFF00897B),
      ),
    );
  }
}
