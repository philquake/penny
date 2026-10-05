class CategoryBreakdownItem {
  final int categoryId;
  final String categoryName;
  final double total;
  final String? colorHex;

  const CategoryBreakdownItem({
    required this.categoryId,
    required this.categoryName,
    required this.total,
    required this.colorHex,
  });

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdownItem(
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String,
      // Pydantic v2 serializes Decimal as a string, so don't cast to num.
      total: double.parse(json['total'].toString()),
      colorHex: json['color_hex'] as String?,
    );
  }
}