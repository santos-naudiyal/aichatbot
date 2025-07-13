import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id; // Add unique ID for threading
  final String text;
  final String? imageUrl;
  final bool isUser;
  final DateTime timestamp;
  final bool isEdited; // Track if message was edited
  final String? parentMessageId; // For threaded replies

  ChatMessage({
    required this.id,
    required this.text,
    this.imageUrl,
    required this.isUser,
    required this.timestamp,
    this.isEdited = false,
    this.parentMessageId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'imageUrl': imageUrl,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'isEdited': isEdited,
        'parentMessageId': parentMessageId,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] ?? const Uuid().v4(),
        text: json['text'],
        imageUrl: json['imageUrl'],
        isUser: json['isUser'],
        timestamp: DateTime.parse(json['timestamp']),
        isEdited: json['isEdited'] ?? false,
        parentMessageId: json['parentMessageId'],
      );
}