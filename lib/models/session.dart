import 'package:chatbot/models/chat_message.dart';
import 'package:uuid/uuid.dart';

class ChatSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => {
              'text': m.text,
              'isUser': m.isUser,
              'timestamp': m.timestamp.toIso8601String(),
            }).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  static ChatSession fromJson(Map<String, dynamic> json) => ChatSession(
      id: json['id'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((m) => ChatMessage(
                id: m['id'] ?? const Uuid().v4(), // Provide id if missing
                text: m['text'],
                isUser: m['isUser'],
                timestamp: DateTime.parse(m['timestamp']),
                isEdited: m['isEdited'] ?? false,
                parentMessageId: m['parentMessageId'],
                imageUrls: m['imageUrl'],
              ))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
    );
}