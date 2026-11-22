class InventoryValidators {
  InventoryValidators._();

  static String? required(String? value, {String message = 'هذا الحقل مطلوب'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? positiveNumber(String? value,
      {String message = 'يجب أن يكون رقم موجب'}) {
    if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
    final n = double.tryParse(value.trim());
    if (n == null || n <= 0) return message;
    return null;
  }
}
