/// Centralized place category localization helper for Vietnamese UI.
/// Maps backend PlaceCategory enums, POI types, and category keys to user-friendly Vietnamese labels.
class PlaceCategoryHelper {
  PlaceCategoryHelper._();

  static const Map<String, String> _translations = {
    // Canonical backend PlaceCategory enum values:
    'ATTRACTION': 'Điểm tham quan',
    'RESTAURANT': 'Nhà hàng',
    'HOTEL': 'Khách sạn',
    'CAFE': 'Quán cà phê',
    'ENTERTAINMENT': 'Giải trí',
    'SHOPPING': 'Cửa hàng',
    'OTHER': 'Khác',

    // Common synonyms and sub-categories:
    'SHOP': 'Cửa hàng',
    'STORE': 'Cửa hàng',
    'LODGING': 'Khách sạn',
    'COFFEE': 'Quán cà phê',
    'BAR': 'Quán bar / Pub',
    'PUB': 'Quán bar / Pub',
    'MUSEUM': 'Bảo tàng',
    'PARK': 'Công viên',
    'NIGHTLIFE': 'Cuộc sống về đêm',
    'BEACH': 'Bãi biển',
    'NATURE': 'Thiên nhiên',
    'FOOD': 'Ẩm thực',
    'TOURIST_ATTRACTION': 'Điểm tham quan',
    'POINT_OF_INTEREST': 'Điểm tham quan',
    'ACTIVITY': 'Hoạt động',
    'SUPERMARKET': 'Siêu thị',
    'MARKET': 'Chợ',
    'CINEMA': 'Rạp chiếu phim',
    'THEATER': 'Nhà hát',
    'AIRPORT': 'Sân bay',
    'STATION': 'Nhà ga',
    'HOSPITAL': 'Bệnh viện',
    'PHARMACY': 'Hiệu thuốc',
    'BANK': 'Ngân hàng',
    'ATM': 'Cây ATM',
    'GAS_STATION': 'Trạm xăng',
    'GYM': 'Phòng gym',
    'SPA': 'Spa / Massage',
    'RESORT': 'Khu nghỉ dưỡng',
    'HOMESTAY': 'Homestay',
    'HOSTEL': 'Nhà nghỉ',
    'TEMPLE': 'Chùa / Đền',
    'CHURCH': 'Nhà thờ',
    'PAGODA': 'Chùa',
    'MONUMENT': 'Di tích',
    'ZOO': 'Vườn thú',
    'AMUSEMENT_PARK': 'Khu vui chơi',
    'SIGHTSEEING': 'Tham quan',
    'CULTURE': 'Văn hóa',
    'HISTORIC': 'Di tích lịch sử',
  };

  /// Localizes a raw category string into a user-friendly Vietnamese label.
  ///
  /// - If [category] is null or blank, returns [fallback] (defaults to 'Khác').
  /// - If already translated or contains Vietnamese accents/spaces, preserves it.
  /// - If not found in mapping dictionary, safely formats it into a human-readable title.
  static String localize(String? category, {String fallback = 'Khác'}) {
    if (category == null || category.trim().isEmpty) {
      return fallback;
    }

    final trimmed = category.trim();
    final normalized = trimmed.toUpperCase();

    if (_translations.containsKey(normalized)) {
      return _translations[normalized]!;
    }

    // Preserve strings that already contain Vietnamese diacritics or natural spacing
    if (_containsVietnameseDiacritics(trimmed)) {
      return trimmed;
    }

    // Safe fallback formatting: replace underscores/dashes and title-case
    return _formatFallback(trimmed);
  }

  static bool _containsVietnameseDiacritics(String text) {
    const vietnameseChars =
        'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
    final lower = text.toLowerCase();
    for (int i = 0; i < lower.length; i++) {
      if (vietnameseChars.contains(lower[i])) return true;
    }
    return false;
  }

  static String _formatFallback(String text) {
    final words =
        text.replaceAll('_', ' ').replaceAll('-', ' ').split(RegExp(r'\s+'));
    final formatted = words.where((w) => w.isNotEmpty).map((w) {
      if (w.length == 1) return w.toUpperCase();
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
    return formatted.isNotEmpty ? formatted : 'Khác';
  }
}
