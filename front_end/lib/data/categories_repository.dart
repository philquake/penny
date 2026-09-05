import '../core/api_client.dart';
import '../models/category.dart';

/// Wraps GET/POST/DELETE /categories, matching app/routers/categories.py.
class CategoriesRepository {
  final ApiClient _client;
  const CategoriesRepository(this._client);

  Future<List<Category>> list() async {
    final response = await _client.dio.get('/categories');
    return (response.data as List)
        .map((json) => Category.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Category> create(CategoryCreate data) async {
    final response = await _client.dio.post('/categories', data: data.toJson());
    return Category.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _client.dio.delete('/categories/$id');
  }
}