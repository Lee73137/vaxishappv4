class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    this.staffName,
    required this.message,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentFileName,
    this.attachmentContentType,
    this.attachmentSize,
    this.isDeleted = false,
  });

  final int id;
  final String sender;
  final String? staffName;
  final String message;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentFileName;
  final String? attachmentContentType;
  final int? attachmentSize;
  final bool isDeleted;

  bool get isFromClinic => sender.toLowerCase() == 'clinic';
  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImageAttachment => (attachmentContentType ?? '').startsWith('image/');

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      sender: json['sender']?.toString() ?? '',
      staffName: json['staffname']?.toString(),
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdat']?.toString() ?? '') ?? DateTime.now(),
      attachmentUrl: json['attachmenturl']?.toString(),
      attachmentFileName: json['attachmentfilename']?.toString(),
      attachmentContentType: json['attachmentcontenttype']?.toString(),
      attachmentSize: int.tryParse(json['attachmentsize']?.toString() ?? ''),
      isDeleted: json['isdeleted'] == true,
    );
  }
}
