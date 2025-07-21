import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isEdited;
  final String? parentMessageId;
  final List<String>? imageUrls;
  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isEdited = false,
    this.parentMessageId,
    this.imageUrls,
  });


  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'imageUrl': imageUrls,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'isEdited': isEdited,
        'parentMessageId': parentMessageId,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? const Uuid().v4(),
        text: json['text'],
        imageUrls: json['imageUrl'],
        isUser: json['isUser'],
        timestamp: DateTime.parse(json['timestamp']),
        isEdited: json['isEdited'] ?? false,
        parentMessageId: json['parentMessageId'],
      );
}