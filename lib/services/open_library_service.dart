import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/open_library_book.dart';

class OpenLibraryService {
  OpenLibraryService._();

  static final OpenLibraryService instance = OpenLibraryService._();

  static const _baseUrl = 'openlibrary.org';
  static const _headers = {
    'User-Agent': 'BookShelf Flutter App (student-project@example.com)',
  };

  Future<List<OpenLibraryBook>> searchBooks({
    required String query,
    int limit = 10,
    String? sort,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    final queryParameters = {
      'q': trimmedQuery,
      'limit': '$limit',
      'fields':
          'key,title,author_name,cover_i,first_publish_year,edition_count,ratings_average',
    };
    if (sort != null) {
      queryParameters['sort'] = sort;
    }

    final uri = Uri.https(_baseUrl, '/search.json', queryParameters);

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Open Library error ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = body['docs'];
    if (docs is! List) return [];

    return docs
        .whereType<Map<String, dynamic>>()
        .map(OpenLibraryBook.fromJson)
        .toList();
  }

  Future<List<OpenLibraryBook>> getTrendingBooks() {
    return searchBooks(query: 'fiction', limit: 10, sort: 'rating');
  }

  Future<List<OpenLibraryBook>> getRecommendations() {
    return searchBooks(query: 'classic literature', limit: 10);
  }

  /// Fetch satu buku dari Open Library berdasarkan work key.
  /// [workKey] bisa dalam format '/works/OL27516W' atau 'OL27516W'.
  Future<OpenLibraryBook?> fetchBookById(String workKey) async {
    // Normalkan ke bare ID (OL27516W)
    final bareId = workKey.replaceFirst(RegExp(r'^/works/'), '');

    final uri = Uri.https(_baseUrl, '/search.json', {
      'q': 'key:/works/$bareId',
      'limit': '1',
      'fields': 'key,title,author_name,cover_i,first_publish_year,edition_count,ratings_average',
    });

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = body['docs'];
    if (docs is! List || docs.isEmpty) return null;

    return OpenLibraryBook.fromJson(docs.first as Map<String, dynamic>);
  }

  Future<String?> getBookDescription(String workKey) async {
    // workKey dari search hasil adalah format "/works/OL27516W"
    final path = workKey.startsWith('/works/')
      ? '$workKey.json'
      : '/works/$workKey.json';
    final uri = Uri.https(_baseUrl, path);

    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final description = body['description'];

    if (description is String) {
      return description;
    } else if (description is Map<String, dynamic>) {
      return description['value'] as String?;
    }

    return null;
  }
}