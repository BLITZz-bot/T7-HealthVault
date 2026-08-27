/// Strongly-typed Family Domain Entity for T7 HealthVault
class FamilyModel {
  final int? id;
  final String familyId;
  final String headName;
  final String? contactNumber;
  final int? villageId;
  final String? ward;
  final String? address;
  final int memberCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FamilyModel({
    this.id,
    required this.familyId,
    required this.headName,
    this.contactNumber,
    this.villageId,
    this.ward,
    this.address,
    this.memberCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory FamilyModel.fromMap(Map<String, dynamic> map) {
    return FamilyModel(
      id: map['id'] as int?,
      familyId: map['family_id'] as String? ?? '',
      headName: map['head_name'] as String? ?? map['family_head'] as String? ?? 'Unknown',
      contactNumber: map['contact_number'] as String?,
      villageId: map['village_id'] as int?,
      ward: map['ward'] as String?,
      address: map['address'] as String?,
      memberCount: map['member_count'] as int? ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'family_id': familyId,
      'head_name': headName,
      'contact_number': contactNumber,
      'village_id': villageId,
      'ward': ward,
      'address': address,
      'member_count': memberCount,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  FamilyModel copyWith({
    int? id,
    String? familyId,
    String? headName,
    String? contactNumber,
    int? villageId,
    String? ward,
    String? address,
    int? memberCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      headName: headName ?? this.headName,
      contactNumber: contactNumber ?? this.contactNumber,
      villageId: villageId ?? this.villageId,
      ward: ward ?? this.ward,
      address: address ?? this.address,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
