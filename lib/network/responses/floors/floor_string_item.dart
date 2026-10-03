class FloorStringItem {
  final int floorId;
  final String floorName;
  final String stringValue;
  final bool hasString;
  final String? deviceName;
  final String? updatedAt;

  FloorStringItem({
    required this.floorId,
    required this.floorName,
    required this.stringValue,
    this.hasString = true,
    this.deviceName,
    this.updatedAt,
  });

  factory FloorStringItem.fromJson(Map<String, dynamic> json) {
    return FloorStringItem(
      floorId: int.tryParse(json['floor_id']?.toString() ?? '') ?? 0,
      floorName: json['floor_name']?.toString() ?? '',
      stringValue: (json['string_value']?.toString() ?? '').trim(),
      hasString: json['has_string'] == true,
      deviceName: json['device_name']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'floor_id': floorId,
        'floor_name': floorName,
        'string_value': stringValue,
        'has_string': hasString,
        'device_name': deviceName,
        'updated_at': updatedAt,
      };
}