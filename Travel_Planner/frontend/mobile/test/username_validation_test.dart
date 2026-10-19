import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';

void main() {
  group('Mobile Username Validation Tests', () {
    test('rejects null or empty username', () {
      expect(RegisterScreen.validateUsername(null), equals('Vui lòng nhập tên đăng nhập'));
      expect(RegisterScreen.validateUsername(''), equals('Vui lòng nhập tên đăng nhập'));
      expect(RegisterScreen.validateUsername('   '), equals('Vui lòng nhập tên đăng nhập'));
    });

    test('rejects username with spaces (leading, trailing, or inside)', () {
      expect(RegisterScreen.validateUsername('user name'), equals('Tên đăng nhập không được chứa khoảng trắng'));
      expect(RegisterScreen.validateUsername(' user'), equals('Tên đăng nhập không được chứa khoảng trắng'));
      expect(RegisterScreen.validateUsername('user '), equals('Tên đăng nhập không được chứa khoảng trắng'));
      expect(RegisterScreen.validateUsername('user  travel'), equals('Tên đăng nhập không được chứa khoảng trắng'));
    });

    test('rejects username shorter than 3 characters or longer than 50 characters', () {
      expect(RegisterScreen.validateUsername('a'), equals('Tên đăng nhập phải từ 3 đến 50 ký tự'));
      expect(RegisterScreen.validateUsername('ab'), equals('Tên đăng nhập phải từ 3 đến 50 ký tự'));
      expect(RegisterScreen.validateUsername('a' * 51), equals('Tên đăng nhập phải từ 3 đến 50 ký tự'));
    });

    test('rejects username containing invalid special characters', () {
      expect(RegisterScreen.validateUsername('user@travel'), equals('Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm'));
      expect(RegisterScreen.validateUsername('user#123'), equals('Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm'));
      expect(RegisterScreen.validateUsername('user!'), equals('Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm'));
      expect(RegisterScreen.validateUsername('user\$money'), equals('Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm'));
      expect(RegisterScreen.validateUsername('nguyễn_văn_a'), equals('Tên đăng nhập chỉ được chứa chữ cái, số, dấu gạch dưới và dấu chấm'));
    });

    test('accepts valid usernames conforming to backend RegisterRequest pattern', () {
      expect(RegisterScreen.validateUsername('hoanganh'), isNull);
      expect(RegisterScreen.validateUsername('user_123'), isNull);
      expect(RegisterScreen.validateUsername('travel.planner'), isNull);
      expect(RegisterScreen.validateUsername('Admin_01.pro'), isNull);
      expect(RegisterScreen.validateUsername('abc'), isNull);
      expect(RegisterScreen.validateUsername('a' * 50), isNull);
    });
  });
}
