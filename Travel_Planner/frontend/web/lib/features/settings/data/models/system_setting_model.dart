/// Allowlist model representing a dynamic business configuration entry.
class SystemSettingModel {
  final String settingKey;
  final String settingValue;
  final String settingGroup;
  final String? description;
  final String valueType;
  final DateTime? updatedAt;
  final String? updatedBy;

  const SystemSettingModel({
    required this.settingKey,
    required this.settingValue,
    required this.settingGroup,
    this.description,
    required this.valueType,
    this.updatedAt,
    this.updatedBy,
  });

  bool get boolValue => settingValue.toLowerCase() == 'true';

  factory SystemSettingModel.fromJson(Map<String, dynamic> json) {
    return SystemSettingModel(
      settingKey: json['settingKey']?.toString() ?? '',
      settingValue: json['settingValue']?.toString() ?? '',
      settingGroup: json['settingGroup']?.toString() ?? 'GENERAL',
      description: json['description']?.toString(),
      valueType: json['valueType']?.toString() ?? 'STRING',
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      updatedBy: json['updatedBy']?.toString(),
    );
  }
}
