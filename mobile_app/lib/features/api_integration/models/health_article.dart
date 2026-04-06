/// Model class for health articles fetched from JSONPlaceholder API.
/// Demonstrates JSON → Dart object conversion (fromJson factory pattern).
class HealthArticle {
  final int id;
  final int userId;
  final String title;
  final String body;

  HealthArticle({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  /// Factory constructor to parse a JSON map into a HealthArticle object.
  /// This is the standard Flutter pattern for deserializing API responses.
  factory HealthArticle.fromJson(Map<String, dynamic> json) {
    return HealthArticle(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }

  /// Convert this object back to a JSON map (useful for debugging/logging).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
    };
  }

  @override
  String toString() => 'HealthArticle(id: $id, title: $title)';
}
