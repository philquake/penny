import 'transaction_type.dart';

class CategoryCreate {
  final String name;
  final TransactionType type;
  final String? icon;
  final bool isDefault;

  const CategoryCreate({
    required this.name,
    required this.type,
    this.icon,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.value,
      'icon': icon,
      'is_default': isDefault,
    };
  }
}

class Category {
  final int id;
  final int? userId;
  final String name;
  final TransactionType type;
  final String? icon;
  final bool isDefault;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.icon,
    required this.isDefault,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      name: json['name'] as String,
      type: TransactionTypeExtension.fromValue(
        json['type'] as String,
      ),
      icon: json['icon'] as String?,
      isDefault: json['is_default'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type.value,
      'icon': icon,
      'is_default': isDefault,
    };
  }
}

