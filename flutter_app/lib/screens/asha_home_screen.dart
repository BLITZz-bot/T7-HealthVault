import 'dart:convert';
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
        const SnackBar(content: Text('No assigned areas found. Please contact admin to assign an area.')),
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
          title: const Text('Add New Family'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: headNameController, decoration: const InputDecoration(labelText: 'Head of Family Name')),
                const SizedBox(height: 12),
                TextField(controller: houseNoController, decoration: const InputDecoration(labelText: 'House Number')),
                const SizedBox(height: 12),
                TextField(controller: contactController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact Number')),
                const SizedBox(height: 16),
                
                // Static display of State and District
                Text(
                  'State: $stateName',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  'District: $districtDisplay',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),

                // Area selection dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedAreaId,
                  decoration: const InputDecoration(labelText: 'Select Area / Village'),
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
                  if (!mounted || !context.mounted) return;
                  Navigator.pop(context);
                  if (success && context.mounted) {
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
  }

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

        final families = snapshot.data ?? [];
        if (families.isEmpty) {
          return const Center(child: Text('No families registered in your area yet. Tap Add Family to register one.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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

    // Generate initials for avatar
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
          // Profile Header / Avatar with custom design
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
                      gradient: (profileImage != null && profileImage.isNotEmpty)
                          ? null
                          : LinearGradient(
                              colors: [Colors.teal.shade200, Colors.teal.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      image: (profileImage != null && profileImage.isNotEmpty)
                          ? DecorationImage(
                              image: MemoryImage(base64Decode(profileImage)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (profileImage != null && profileImage.isNotEmpty)
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
                  child: const Text(
                    'ASHA Health Worker',
                    style: TextStyle(
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
            title: 'Personal Details',
            icon: Icons.person_outline,
            children: [
              _buildInfoRow('Username', username),
              _buildInfoRow('Phone Number', phone),
              _buildInfoRow('Aadhaar Number', aadhaarNumber),
            ],
          ),
          const SizedBox(height: 16),

          // Jurisdiction Card
          _buildInfoCard(
            title: 'Jurisdiction',
            icon: Icons.map_outlined,
            children: [
              _buildInfoRow('State', stateName),
              _buildInfoRow('District', districtDisplay),
            ],
          ),
          const SizedBox(height: 16),

          // Assigned Areas Card
          _buildInfoCard(
            title: 'Assigned Areas (${assignedAreas.length})',
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
            ? 'ASHA Portal (${widget.user['first_name'] ?? widget.user['username']})'
            : 'ASHA Profile'),
        actions: [
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Families',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddFamilyDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Family'),
              backgroundColor: const Color(0xFF00897B),
            )
          : null,
    );
  }
}
