import 'package:flutter/material.dart';
import '../widgets/language_switcher_widget.dart';

class StateJurisdictionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> state;
  final List<dynamic> districts;
  final List<dynamic> areas;

  const StateJurisdictionDetailScreen({
    super.key,
    required this.state,
    required this.districts,
    required this.areas,
  });

  @override
  State<StateJurisdictionDetailScreen> createState() => _StateJurisdictionDetailScreenState();
}

class _StateJurisdictionDetailScreenState extends State<StateJurisdictionDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateName = widget.state['name'] ?? 'State';
    final stateId = widget.state['id'].toString();

    // Filter districts belonging to this state
    final stateDistricts = widget.districts
        .where((d) => d['state_id'].toString() == stateId)
        .toList();

    // Filter based on search query (matches district name or village/block inside)
    final filteredDistricts = stateDistricts.where((d) {
      final dName = (d['name'] ?? '').toString().toLowerCase();
      final dId = d['id'].toString();
      final matchingAreas = widget.areas.where((a) {
        if (a['district_id'].toString() != dId) return false;
        final village = (a['village_or_ward'] ?? '').toString().toLowerCase();
        final block = (a['block'] ?? '').toString().toLowerCase();
        return village.contains(_searchQuery.toLowerCase()) ||
            block.contains(_searchQuery.toLowerCase());
      }).toList();

      return dName.contains(_searchQuery.toLowerCase()) || matchingAreas.isNotEmpty;
    }).toList();

    // Total areas in this state
    final totalStateAreas = widget.areas.where((a) {
      final dId = a['district_id']?.toString();
      return stateDistricts.any((d) => d['id'].toString() == dId);
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF004D40),
        toolbarHeight: 65,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stateName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
            ),
            Text(
              '${stateDistricts.length} Districts • $totalStateAreas Assigned Areas',
              style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: const [
          LanguageSwitcherWidget(),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search districts or villages in $stateName...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00796B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00796B), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${filteredDistricts.length} of ${stateDistricts.length} Districts',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Read-Only View',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Districts & Areas List
          Expanded(
            child: filteredDistricts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_city_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No districts found in $stateName'
                                : 'No districts matching "$_searchQuery"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filteredDistricts.length,
                    itemBuilder: (context, index) {
                      final district = filteredDistricts[index];
                      final districtId = district['id'].toString();
                      final districtAreas = widget.areas
                          .where((a) => a['district_id'].toString() == districtId)
                          .toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF004D40).withAlpha(12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_city_rounded, color: Color(0xFF004D40), size: 20),
                            ),
                            title: Text(
                              district['name'] ?? 'District',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF263238)),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                districtAreas.isEmpty
                                    ? 'No assigned areas'
                                    : '${districtAreas.length} Villages / Wards assigned',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: districtAreas.isEmpty ? Colors.grey.shade400 : const Color(0xFF00796B),
                                  fontWeight: districtAreas.isEmpty ? FontWeight.normal : FontWeight.w600,
                                ),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${districtAreas.length}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF004D40)),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.black54),
                                ],
                              ),
                            ),
                            children: [
                              if (districtAreas.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'ℹ️ No specific villages/wards configured for this district.',
                                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  color: const Color(0xFFF9FBFC),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                    children: districtAreas.map((area) {
                                      final village = area['village_or_ward'] ?? 'Area';
                                      final block = area['block'] ?? 'N/A';
                                      return ListTile(
                                        dense: true,
                                        contentPadding: const EdgeInsets.only(left: 48, right: 16),
                                        leading: const Icon(Icons.place_rounded, size: 16, color: Color(0xFF00796B)),
                                        title: Text(
                                          village,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        subtitle: Text(
                                          'Block / Taluk: $block',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
