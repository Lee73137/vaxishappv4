class FCMMessageRecord {
  const FCMMessageRecord({
    this.id,
    this.messageId,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.receivedAt,
    this.isRead = false,
  });

  final int? id;
  final String? messageId;
  final String title;
  final String body;
  final String? imageUrl;
  final DateTime receivedAt;
  final bool isRead;

  factory FCMMessageRecord.fromMap(Map<String, dynamic> map) {
    return FCMMessageRecord(
      id: map['id'] as int?,
      messageId: map['messageId'] as String?,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      imageUrl: map['imageUrl'] as String?,
      receivedAt: DateTime.tryParse(map['receivedAt'] as String? ?? '') ?? DateTime.now(),
      isRead: ((map['isRead'] as int?) ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'receivedAt': receivedAt.toIso8601String(),
      'isRead': isRead ? 1 : 0,
    };
  }
}
