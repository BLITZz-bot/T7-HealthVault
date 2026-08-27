/// Master Administrative Hierarchy for National Health Mission
enum JurisdictionLevel {
  national,
  state,
  district,
  block,
  phc,
  subCenter,
  village;

  String get displayName {
    switch (this) {
      case JurisdictionLevel.national:
        return 'National';
      case JurisdictionLevel.state:
        return 'State';
      case JurisdictionLevel.district:
        return 'District';
      case JurisdictionLevel.block:
        return 'Block / Taluk';
      case JurisdictionLevel.phc:
        return 'Primary Health Centre (PHC)';
      case JurisdictionLevel.subCenter:
        return 'Health Sub-Centre';
      case JurisdictionLevel.village:
        return 'Village / Ward';
    }
  }
}

/// Strongly-typed Node for Master Jurisdiction Tree
class JurisdictionNode {
  final int? id;
  final String name;
  final String code;
  final JurisdictionLevel level;
  final int? parentId;
  final int population;
  final bool isActive;

  const JurisdictionNode({
    this.id,
    required this.name,
    required this.code,
    required this.level,
    this.parentId,
    this.population = 0,
    this.isActive = true,
  });

  factory JurisdictionNode.fromMap(Map<String, dynamic> map) {
    final lvlStr = (map['level'] as String? ?? 'village').toLowerCase();
    JurisdictionLevel lvl = JurisdictionLevel.village;
    if (lvlStr.contains('state')) lvl = JurisdictionLevel.state;
    if (lvlStr.contains('district')) lvl = JurisdictionLevel.district;
    if (lvlStr.contains('block')) lvl = JurisdictionLevel.block;
    if (lvlStr.contains('phc')) lvl = JurisdictionLevel.phc;
    if (lvlStr.contains('sub')) lvl = JurisdictionLevel.subCenter;

    return JurisdictionNode(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Unknown',
      code: map['code'] as String? ?? '',
      level: lvl,
      parentId: map['parent_id'] as int?,
      population: map['population'] as int? ?? 0,
      isActive: (map['is_active'] == 1 || map['is_active'] == true || map['is_active'] == null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'code': code,
      'level': level.name,
      'parent_id': parentId,
      'population': population,
      'is_active': isActive ? 1 : 0,
    };
  }
}
