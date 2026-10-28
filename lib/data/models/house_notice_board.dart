/// Ev Panosu, Acil Durum Bilgileri ve Ev İçi Kurallar Modeli
class HouseNoticeBoard {
  final String householdId;
  final String wifiSsid;
  final String wifiPassword;
  final String? buildingDoorCode;
  final String? trashSchedule;
  final String? boilerValveLocation;
  final String? mainWaterValveLocation;
  final String? electricalPanelLocation;
  final String? spareKeyLocation;
  final String? landlordName;
  final String? landlordPhone;
  final String? landlordIban;
  final List<String> customRules;
  final DateTime updatedAt;

  const HouseNoticeBoard({
    required this.householdId,
    this.wifiSsid = '',
    this.wifiPassword = '',
    this.buildingDoorCode,
    this.trashSchedule,
    this.boilerValveLocation,
    this.mainWaterValveLocation,
    this.electricalPanelLocation,
    this.spareKeyLocation,
    this.landlordName,
    this.landlordPhone,
    this.landlordIban,
    this.customRules = const [],
    required this.updatedAt,
  });

  factory HouseNoticeBoard.initial(String householdId) {
    return HouseNoticeBoard(
      householdId: householdId,
      wifiSsid: '',
      wifiPassword: '',
      buildingDoorCode: null,
      trashSchedule: null,
      boilerValveLocation: null,
      mainWaterValveLocation: null,
      electricalPanelLocation: null,
      spareKeyLocation: null,
      landlordName: null,
      landlordPhone: null,
      landlordIban: null,
      customRules: const [
        'Gece 23:30 dan sonra ortak alanda sessizlik',
        'Mutfak tezgahı ve lavabo kullandıktan sonra temiz bırakılır',
        'Kapıda ayakkabı bırakılmaz, ayakkabılığa yerleştirilir',
      ],
      updatedAt: DateTime.now(),
    );
  }

  HouseNoticeBoard copyWith({
    String? householdId,
    String? wifiSsid,
    String? wifiPassword,
    String? buildingDoorCode,
    String? trashSchedule,
    String? boilerValveLocation,
    String? mainWaterValveLocation,
    String? electricalPanelLocation,
    String? spareKeyLocation,
    String? landlordName,
    String? landlordPhone,
    String? landlordIban,
    List<String>? customRules,
    DateTime? updatedAt,
  }) {
    return HouseNoticeBoard(
      householdId: householdId ?? this.householdId,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      wifiPassword: wifiPassword ?? this.wifiPassword,
      buildingDoorCode: buildingDoorCode ?? this.buildingDoorCode,
      trashSchedule: trashSchedule ?? this.trashSchedule,
      boilerValveLocation: boilerValveLocation ?? this.boilerValveLocation,
      mainWaterValveLocation:
          mainWaterValveLocation ?? this.mainWaterValveLocation,
      electricalPanelLocation:
          electricalPanelLocation ?? this.electricalPanelLocation,
      spareKeyLocation: spareKeyLocation ?? this.spareKeyLocation,
      landlordName: landlordName ?? this.landlordName,
      landlordPhone: landlordPhone ?? this.landlordPhone,
      landlordIban: landlordIban ?? this.landlordIban,
      customRules: customRules ?? this.customRules,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'household_id': householdId,
      'wifi_ssid': wifiSsid,
      'wifi_password': wifiPassword,
      'building_door_code': buildingDoorCode,
      'trash_schedule': trashSchedule,
      'boiler_valve_location': boilerValveLocation,
      'main_water_valve_location': mainWaterValveLocation,
      'electrical_panel_location': electricalPanelLocation,
      'spare_key_location': spareKeyLocation,
      'landlord_name': landlordName,
      'landlord_phone': landlordPhone,
      'landlord_iban': landlordIban,
      'custom_rules': customRules,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HouseNoticeBoard.fromJson(Map<String, dynamic> json) {
    return HouseNoticeBoard(
      householdId: json['household_id'] as String? ?? '',
      wifiSsid: json['wifi_ssid'] as String? ?? '',
      wifiPassword: json['wifi_password'] as String? ?? '',
      buildingDoorCode: json['building_door_code'] as String?,
      trashSchedule: json['trash_schedule'] as String?,
      boilerValveLocation: json['boiler_valve_location'] as String?,
      mainWaterValveLocation: json['main_water_valve_location'] as String?,
      electricalPanelLocation: json['electrical_panel_location'] as String?,
      spareKeyLocation: json['spare_key_location'] as String?,
      landlordName: json['landlord_name'] as String?,
      landlordPhone: json['landlord_phone'] as String?,
      landlordIban: json['landlord_iban'] as String?,
      customRules: (json['custom_rules'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
