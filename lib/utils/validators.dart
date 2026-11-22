class AppValidators {
  AppValidators._();

  static String? required(String? value, {String message = 'هذا الحقل مطلوب'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'البريد الإلكتروني مطلوب';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'البريد الإلكتروني غير صحيح';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final regex = RegExp(r'^\+?[0-9]{8,15}$');
    if (!regex.hasMatch(value.trim().replaceAll(' ', ''))) {
      return 'رقم الهاتف غير صحيح';
    }
    return null;
  }

  static String? nationalId(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    if (value.trim().length != 14) return 'الرقم القومي يجب أن يكون 14 رقم';
    if (!RegExp(r'^[0-9]{14}$').hasMatch(value.trim())) {
      return 'الرقم القومي يجب أن يكون أرقام فقط';
    }
    return null;
  }

  static String? number(String? value, {String message = 'يجب أن يكون رقم'}) {
    if (value == null || value.trim().isEmpty) return null;
    if (double.tryParse(value.trim()) == null) return message;
    return null;
  }

  static String? positiveNumber(
    String? value, {
    String message = 'يجب أن يكون رقم موجب',
  }) {
    if (value == null || value.trim().isEmpty) return null;
    final n = double.tryParse(value.trim());
    if (n == null || n < 0) return message;
    return null;
  }
}
