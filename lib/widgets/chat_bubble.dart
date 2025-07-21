import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:photo_view/photo_view.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(ChatMessage)? onReply;
  final Function(String, BuildContext)? downloadImage; // New callback

  const ChatBubble({
    super.key,
    required this.message,
    this.onReply,
    this.downloadImage, // Add callback to constructor
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return FadeInRight(
      duration: const Duration(milliseconds: 300),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: isUser ? Colors.blue : Colors.grey[300],
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.imageUrls != null && message.imageUrls!.isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(backgroundColor: Colors.black),
                          body: PhotoView(
                            imageProvider: CachedNetworkImageProvider(message.imageUrls!.first),
                          ),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: CachedNetworkImage(
                      imageUrl: message.imageUrls!.first,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(
                    Icons.download,
                    color: isUser ? Colors.white70 : Colors.blue,
                    size: 24,
                  ),
                  onPressed: downloadImage != null
                      ? () => downloadImage!(message.imageUrls!.first, context)
                      : null,
                  tooltip: 'Download Image',
                ),
              ],
              if (message.text.isNotEmpty)
                MarkdownBody(
                  data: message.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')} ${message.isEdited ? '(Edited)' : ''}',
                style: TextStyle(
                  color: isUser ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              if (!isUser && onReply != null)
                TextButton(
                  onPressed: () => onReply!(message),
                  child: const Text('Reply', style: TextStyle(color: Colors.blue)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}