import 'package:flutter_test/flutter_test.dart';
import 'package:travel_planner_web/features/auth/presentation/screens/register_screen.dart';

void main() {
  group('Web Username Validation Tests', () {
    test('rejects null or empty username', () {
      expect(RegisterScreen.validateUsername(null), equals('Vui lòng nhập tên đăng nhập'));
      expect(RegisterScreen.validateUsername(''), equals('Vui lòng nhập tên đăng nhập'));
      expect(RegisterScreen.validateUsername('   '), equals('Vui lòng nhập tên đăng nhập'));
    });

    test('rejects username with spaces (leading, trailing, or inside)', () {
      expect(RegisterScreen.validateUsername('user name'), equals('Tên đăng nhập không được chứa khoảng trắng'));
      expect(RegisterScreen.validateUsername(' user'), equals('Tên đăng nhập không được chứa khoảng trắng'));
      expect(RegisterScreen.validateUsername('user '), equals('Tên đăng nhập không được chứa khoảng trắng'));
      expect(RegisterScreen.validateUsername('web  admin'), equals('Tên đăng nhập không được chứa khoảng trắng'));
    });

    test('rejects username shorter than 3 characters or longer than 50 characters', () {
      expect(RegisterScreen.validateUsername('a'), equals('Tên đăng nhập phải từ 3 đến 50 ký tự'));
      expect(RegisterScreen.validateUsername('ab'), equals('Tên đăng nhập phải từ 3 đến 50 ký tự'));
      expect(RegisterScreen.validateUsername('a' * 51), equals('Tên đăng nhập phải từ 3 đến 50 ký tự'));
    });

    test('rejects username containing invalid special characters', () {
      expect(RegisterScreen.validateUsername('admin@web'), equals('Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm'));
      expect(RegisterScreen.validateUsername('web#admin'), equals('Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm'));
      expect(RegisterScreen.validateUsername('admin!'), equals('Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm'));
      expect(RegisterScreen.validateUsername('admin\$vip'), equals('Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm'));
    });

    test('accepts valid usernames conforming to backend RegisterRequest pattern', () {
      expect(RegisterScreen.validateUsername('webadmin'), isNull);
      expect(RegisterScreen.validateUsername('user_123'), isNull);
      expect(RegisterScreen.validateUsername('planner.admin'), isNull);
      expect(RegisterScreen.validateUsername('Super_Admin.01'), isNull);
      expect(RegisterScreen.validateUsername('abc'), isNull);
      expect(RegisterScreen.validateUsername('a' * 50), isNull);
    });
  });
}
