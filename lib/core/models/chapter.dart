class Chapter {
  final int? id;
  final int mangaId;
  final String url;
  final String name;
  final double chapterNumber;
  final String dateUpload;
  bool isRead;
  int lastPageRead;
  bool isDownloaded;

  Chapter({
    this.id,
    required this.mangaId,
    required this.url,
    required this.name,
    required this.chapterNumber,
    required this.dateUpload,
    this.isRead = false,
    this.lastPageRead = 0,
    this.isDownloaded = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'manga_id': mangaId,
      'url': url,
      'name': name,
      'chapter_number': chapterNumber,
      'date_upload': dateUpload,
      'is_read': isRead ? 1 : 0,
      'last_page_read': lastPageRead,
      'is_downloaded': isDownloaded ? 1 : 0,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'],
      mangaId: map['manga_id'] ?? 0,
      url: map['url'] ?? '',
      name: map['name'] ?? '',
      chapterNumber: (map['chapter_number'] as num?)?.toDouble() ?? 0.0,
      dateUpload: map['date_upload'] ?? '',
      isRead: (map['is_read'] ?? 0) == 1,
      lastPageRead: map['last_page_read'] ?? 0,
      isDownloaded: (map['is_downloaded'] ?? 0) == 1,
    );
  }
}
