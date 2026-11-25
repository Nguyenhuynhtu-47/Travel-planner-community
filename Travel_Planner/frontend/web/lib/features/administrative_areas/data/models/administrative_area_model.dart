/// Model representing an Administrative Area unit (Province or Commune/Ward/Special Zone).
class AdministrativeAreaNodeModel {
  final int areaId;
  final String code;
  final String name;
  final String? normalizedName;
  final String areaType;
  final String status;
  final String? parentCode;
  final String? parentName;
  final String? effectiveFrom;

  const AdministrativeAreaNodeModel({
    required this.areaId,
    required this.code,
    required this.name,
    this.normalizedName,
    required this.areaType,
    required this.status,
    this.parentCode,
    this.parentName,
    this.effectiveFrom,
  });

  bool get isProvince =>
      areaType.toUpperCase() == 'PROVINCE' || parentCode == null;

  String get areaTypeLabel {
    switch (areaType.toUpperCase()) {
      case 'PROVINCE':
        return 'Tỉnh / Thành phố';
      case 'WARD':
        return 'Phường';
      case 'COMMUNE':
        return 'Xã';
      case 'SPECIAL_ZONE':
        return 'Đặc khu';
      default:
        return areaType;
    }
  }

  factory AdministrativeAreaNodeModel.fromJson(Map<String, dynamic> json) {
    return AdministrativeAreaNodeModel(
      areaId: (json['areaId'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      normalizedName: json['normalizedName']?.toString(),
      areaType: json['areaType']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      parentCode: json['parentCode']?.toString(),
      parentName: json['parentName']?.toString(),
      effectiveFrom: json['effectiveFrom']?.toString(),
    );
  }
}

/// Summary model used in search results and resolution responses.
class AdministrativeAreaSummaryModel {
  final int areaId;
  final String code;
  final String name;
  final String areaType;
  final int? parentAreaId;
  final String? parentCode;
  final String? parentName;
  final String? trustClassification;

  const AdministrativeAreaSummaryModel({
    required this.areaId,
    required this.code,
    required this.name,
    required this.areaType,
    this.parentAreaId,
    this.parentCode,
    this.parentName,
    this.trustClassification,
  });

  bool get isQuarantined =>
      trustClassification?.toUpperCase() == 'UNVERIFIED_AND_QUARANTINED';

  String get displayLabel {
    if (parentName != null && parentName!.isNotEmpty) {
      return '$name ($code) - $parentName';
    }
    return '$name ($code)';
  }

  factory AdministrativeAreaSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdministrativeAreaSummaryModel(
      areaId: (json['areaId'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      areaType: json['areaType']?.toString() ?? '',
      parentAreaId: (json['parentAreaId'] as num?)?.toInt(),
      parentCode: json['parentCode']?.toString(),
      parentName: json['parentName']?.toString(),
      trustClassification: json['trustClassification']?.toString(),
    );
  }
}

/// Coverage statistics for Place - AdministrativeArea linking (ID 5.7).
class AdministrativeAreaStatsModel {
  final int totalPlaces;
  final int linkedPlaces;
  final int unlinkedPlaces;
  final double coveragePercentage;

  const AdministrativeAreaStatsModel({
    required this.totalPlaces,
    required this.linkedPlaces,
    required this.unlinkedPlaces,
    required this.coveragePercentage,
  });

  factory AdministrativeAreaStatsModel.fromJson(Map<String, dynamic> json) {
    return AdministrativeAreaStatsModel(
      totalPlaces: (json['totalPlaces'] as num?)?.toInt() ?? 0,
      linkedPlaces: (json['linkedPlaces'] as num?)?.toInt() ?? 0,
      unlinkedPlaces: (json['unlinkedPlaces'] as num?)?.toInt() ?? 0,
      coveragePercentage:
          (json['coveragePercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Resolution result for a single Place (ID 5.8 & 5.9).
class PlaceResolutionResultModel {
  final int placeId;
  final String placeName;
  final String placeAddress;
  final AdministrativeAreaSummaryModel? resolvedArea;
  final String confidence;
  final String? matchMethod;
  final String? explanation;
  final bool eligibleForAutoLink;
  final bool currentlyLinked;
  final List<AdministrativeAreaSummaryModel> candidateAreas;
  final List<String> warnings;

  const PlaceResolutionResultModel({
    required this.placeId,
    required this.placeName,
    required this.placeAddress,
    this.resolvedArea,
    required this.confidence,
    this.matchMethod,
    this.explanation,
    required this.eligibleForAutoLink,
    required this.currentlyLinked,
    this.candidateAreas = const [],
    this.warnings = const [],
  });

  factory PlaceResolutionResultModel.fromJson(Map<String, dynamic> json) {
    return PlaceResolutionResultModel(
      placeId: (json['placeId'] as num?)?.toInt() ?? 0,
      placeName: json['placeName']?.toString() ?? '',
      placeAddress: json['placeAddress']?.toString() ?? '',
      resolvedArea: json['resolvedArea'] is Map<String, dynamic>
          ? AdministrativeAreaSummaryModel.fromJson(
              json['resolvedArea'] as Map<String, dynamic>)
          : null,
      confidence: json['confidence']?.toString() ?? 'NO_MATCH',
      matchMethod: json['matchMethod']?.toString(),
      explanation: json['explanation']?.toString(),
      eligibleForAutoLink: json['eligibleForAutoLink'] == true,
      currentlyLinked: json['currentlyLinked'] == true,
      candidateAreas: json['candidateAreas'] is List
          ? (json['candidateAreas'] as List)
              .whereType<Map<String, dynamic>>()
              .map(AdministrativeAreaSummaryModel.fromJson)
              .toList()
          : const [],
      warnings: json['warnings'] is List
          ? (json['warnings'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}

/// Response from POST /api/admin/places/administrative-area/batch-resolve.
class BatchLinkingReportModel {
  final int totalPlacesExamined;
  final int linkedCount;
  final int skippedCount;
  final int quarantinedCount;
  final int ambiguousCount;
  final int noMatchCount;
  final bool dryRun;
  final List<PlaceResolutionResultModel> results;

  const BatchLinkingReportModel({
    required this.totalPlacesExamined,
    required this.linkedCount,
    required this.skippedCount,
    required this.quarantinedCount,
    required this.ambiguousCount,
    required this.noMatchCount,
    required this.dryRun,
    required this.results,
  });

  factory BatchLinkingReportModel.fromJson(Map<String, dynamic> json) {
    return BatchLinkingReportModel(
      totalPlacesExamined:
          (json['totalPlacesExamined'] as num?)?.toInt() ?? 0,
      linkedCount: (json['linkedCount'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skippedCount'] as num?)?.toInt() ?? 0,
      quarantinedCount: (json['quarantinedCount'] as num?)?.toInt() ?? 0,
      ambiguousCount: (json['ambiguousCount'] as num?)?.toInt() ?? 0,
      noMatchCount: (json['noMatchCount'] as num?)?.toInt() ?? 0,
      dryRun: json['dryRun'] == true,
      results: json['results'] is List
          ? (json['results'] as List)
              .whereType<Map<String, dynamic>>()
              .map(PlaceResolutionResultModel.fromJson)
              .toList()
          : const [],
    );
  }
}
