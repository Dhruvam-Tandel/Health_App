import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/health_article.dart';

/// Service class that handles all REST API communication.
/// Demonstrates:
///  - HTTP GET request using the `http` package
///  - JSON parsing with `dart:convert`
///  - Proper error handling for network failures
///  - Async/await pattern for asynchronous API calls
class HealthApiService {
  // ── API Configuration ─────────────────────────────────────────────────────
  static const String _baseUrl = 'https://jsonplaceholder.typicode.com';
  static const String _postsEndpoint = '/posts';

  /// Full API URL: https://jsonplaceholder.typicode.com/posts
  String get apiUrl => '$_baseUrl$_postsEndpoint';

  // ── GET Request: Fetch All Articles ───────────────────────────────────────
  /// Makes a GET request to the API and returns a list of HealthArticle objects.
  ///
  /// Steps:
  /// 1. Send HTTP GET request to the API endpoint
  /// 2. Check for successful response (status code 200)
  /// 3. Decode the JSON response body
  /// 4. Map each JSON object to a HealthArticle model
  /// 5. Return the list of parsed articles
  ///
  /// Throws an [Exception] if the request fails or returns a non-200 status.
  Future<List<HealthArticle>> fetchArticles() async {
    try {
      // Step 1: Make the GET request
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // Step 2: Check the response status code
      if (response.statusCode == 200) {
        // Step 3: Decode JSON
        final List<dynamic> jsonData = jsonDecode(response.body);

        // Step 4 & 5: Parse and return
        return jsonData
            .map((json) => HealthArticle.fromJson(json))
            .toList();
      } else {
        throw Exception(
          'Failed to load articles. Status Code: ${response.statusCode}',
        );
      }
    } on http.ClientException catch (e) {
      // Network-level error (no internet, DNS failure, etc.)
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      // Any other unexpected error
      throw Exception('Something went wrong: $e');
    }
  }

  // ── GET Request: Fetch Single Article by ID ───────────────────────────────
  /// Fetches a single article by its ID.
  Future<HealthArticle> fetchArticleById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/$id'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return HealthArticle.fromJson(jsonData);
      } else {
        throw Exception('Article not found. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch article: $e');
    }
  }

  // ── GET Request: Fetch Articles by User/Author ────────────────────────────
  /// Fetches articles filtered by userId (query parameter).
  Future<List<HealthArticle>> fetchArticlesByUser(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl?userId=$userId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        return jsonData
            .map((json) => HealthArticle.fromJson(json))
            .toList();
      } else {
        throw Exception(
          'Failed to filter articles. Status Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to fetch filtered articles: $e');
    }
  }
}
