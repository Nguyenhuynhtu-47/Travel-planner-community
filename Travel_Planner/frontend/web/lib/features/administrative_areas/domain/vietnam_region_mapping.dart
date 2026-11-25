/// Ba miền địa lý dùng để lọc các đơn vị hành chính cấp tỉnh.
enum VietnamRegion {
  all('Tất cả khu vực'),
  north('Miền Bắc'),
  central('Miền Trung'),
  south('Miền Nam');

  final String label;
  const VietnamRegion(this.label);
}

/// Bảng ánh xạ tập trung 34 mã đơn vị hành chính cấp tỉnh theo dữ liệu Backend
/// (`data/administrative/provinces.json`) sang 3 miền Bắc - Trung - Nam.
const Map<String, VietnamRegion> kProvinceCodeToRegion = {
  // Miền Bắc (15 đơn vị)
  '01': VietnamRegion.north, // Thành phố Hà Nội
  '04': VietnamRegion.north, // Tỉnh Cao Bằng
  '08': VietnamRegion.north, // Tỉnh Tuyên Quang
  '11': VietnamRegion.north, // Tỉnh Điện Biên
  '12': VietnamRegion.north, // Tỉnh Lai Châu
  '14': VietnamRegion.north, // Tỉnh Sơn La
  '15': VietnamRegion.north, // Tỉnh Lào Cai
  '19': VietnamRegion.north, // Tỉnh Thái Nguyên
  '20': VietnamRegion.north, // Tỉnh Lạng Sơn
  '22': VietnamRegion.north, // Thành phố Quảng Ninh
  '24': VietnamRegion.north, // Thành phố Bắc Ninh
  '25': VietnamRegion.north, // Tỉnh Phú Thọ
  '31': VietnamRegion.north, // Thành phố Hải Phòng
  '33': VietnamRegion.north, // Tỉnh Hưng Yên
  '37': VietnamRegion.north, // Tỉnh Ninh Bình

  // Miền Trung (11 đơn vị)
  '38': VietnamRegion.central, // Tỉnh Thanh Hoá
  '40': VietnamRegion.central, // Tỉnh Nghệ An
  '42': VietnamRegion.central, // Tỉnh Hà Tĩnh
  '44': VietnamRegion.central, // Tỉnh Quảng Trị
  '46': VietnamRegion.central, // Thành phố Huế
  '48': VietnamRegion.central, // Thành phố Đà Nẵng
  '51': VietnamRegion.central, // Tỉnh Quảng Ngãi
  '52': VietnamRegion.central, // Tỉnh Gia Lai
  '56': VietnamRegion.central, // Tỉnh Khánh Hoà
  '66': VietnamRegion.central, // Tỉnh Đắk Lắk
  '68': VietnamRegion.central, // Tỉnh Lâm Đồng

  // Miền Nam (8 đơn vị)
  '75': VietnamRegion.south, // Thành phố Đồng Nai
  '79': VietnamRegion.south, // Thành phố Hồ Chí Minh
  '80': VietnamRegion.south, // Tỉnh Tây Ninh
  '82': VietnamRegion.south, // Tỉnh Đồng Tháp
  '86': VietnamRegion.south, // Tỉnh Vĩnh Long
  '91': VietnamRegion.south, // Tỉnh An Giang
  '92': VietnamRegion.south, // Thành phố Cần Thơ
  '96': VietnamRegion.south, // Tỉnh Cà Mau
};

/// Trả về miền của mã đơn vị cấp tỉnh, hoặc `null` nếu mã chưa có trong bảng ánh xạ.
VietnamRegion? resolveProvinceRegion(String code) {
  return kProvinceCodeToRegion[code.trim()];
}

/// Kiểm tra một mã đơn vị cấp tỉnh có khớp bộ lọc miền đang chọn hay không.
/// Mã chưa có trong bảng ánh xạ chỉ hiển thị ở `VietnamRegion.all`, không tự ý gán sai miền.
bool matchesProvinceRegionFilter(String code, VietnamRegion filter) {
  if (filter == VietnamRegion.all) return true;
  return resolveProvinceRegion(code) == filter;
}
