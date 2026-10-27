class Manga {
  final int? id;
  final String sourceId;
  final String url;
  final String title;
  final String author;
  final String description;
  final String genre;
  final String status;
  final String thumbnailUrl;
  bool inLibrary;
  String category;
  int unreadCount;

  Manga({
    this.id,
    required this.sourceId,
    required this.url,
    required this.title,
    required this.author,
    required this.description,
    required this.genre,
    required this.status,
    required this.thumbnailUrl,
    this.inLibrary = false,
    this.category = 'Default',
    this.unreadCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_id': sourceId,
      'url': url,
      'title': title,
      'author': author,
      'description': description,
      'genre': genre,
      'status': status,
      'thumbnail_url': thumbnailUrl,
      'in_library': inLibrary ? 1 : 0,
      'category': category,
    };
  }

  factory Manga.fromMap(Map<String, dynamic> map) {
    return Manga(
      id: map['id'],
      sourceId: map['source_id'] ?? '',
      url: map['url'] ?? '',
      title: map['title'] ?? '',
      author: map['author'] ?? 'Unknown',
      description: map['description'] ?? '',
      genre: map['genre'] ?? '',
      status: map['status'] ?? 'Ongoing',
      thumbnailUrl: map['thumbnail_url'] ?? '',
      inLibrary: (map['in_library'] ?? 0) == 1,
      category: map['category'] ?? 'Default',
      unreadCount: map['unread_count'] ?? 0,
    );
  }
}
