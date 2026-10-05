import 'transaction_type.dart';

class CategoryCreate {
  final String name;
  final TransactionType type;
  final String? icon;
  final bool isDefault;
  final String? color;

  const CategoryCreate({
    required this.name,
    required this.type,
    this.icon,
    this.isDefault = false,
    this.color,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.value,
      'icon': icon,
      'is_default': isDefault,
      'color': color,
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
  final String? color;
  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.icon,
    required this.isDefault,
    required this.color,
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
      color: json['color'] as String?,
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

class CategoryUpdate {
  final String? name;
  final String? color;
  const CategoryUpdate({this.name, this.color});

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (color != null) 'color': color,
      };
}
