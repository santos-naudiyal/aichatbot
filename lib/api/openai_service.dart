
import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import '../models/chat_message.dart';
import '../utils/connectivity_service.dart';

class ImageResponse {
  final String text;
  final String? imageUrl;

  ImageResponse({required this.text, this.imageUrl});
}

class OpenAIService {
  final String apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_DEFAULT_API_KEY'; // Load from .env
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _imageApiUrl = 'https://api.openai.com/v1/images/generations';

Future<ImageResponse> generateResponse(List<ChatMessage> messages, {required bool isImagePrompt}) async {
  final apiKey = dotenv.env['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('Error: Invalid or missing OPENAI_API_KEY');
    throw Exception('Invalid OpenAI API key');
  }

  final prompt = messages.last.text;

 if (isImagePrompt) {
       try {
         print('Sending DALL·E API request for prompt: $prompt');
         final response = await http.post(
           Uri.parse('https://api.openai.com/v1/images/generations'),
           headers: {
             'Authorization': 'Bearer $apiKey',
             'Content-Type': 'application/json',
           },
           body: jsonEncode({
             'prompt': prompt,
             'n': 1,
             'size': '512x512',
             'model': 'dall-e-3',
           }),
         );
         print('DALL·E API response status: ${response.statusCode}');
         print('DALL·E API response body: ${response.body}');
         if (response.statusCode == 200) {
           final data = jsonDecode(response.body);
           final imageUrl = data['data']?[0]['url'];
           if (imageUrl == null) {
             print('Error: No image URL in response: ${response.body}');
             throw Exception('No image URL returned by API');
           }
           return ImageResponse(
             text: 'Image generated successfully',
             imageUrl: imageUrl,
           );
         } else {
           final errorData = jsonDecode(response.body);
           print('Error: DALL·E API failed with status ${response.statusCode}: ${errorData['error']['message']}');
           throw Exception('API error: ${errorData['error']['message']}');
         }
       } catch (e) {
         print('Error in image generation: $e');
         throw Exception('Image generation failed: $e');
       }
     

  } else {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': messages.map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              }).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ImageResponse(
          text: data['choices'][0]['message']['content'],
          imageUrl: null,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Text generation error: ${errorData['error']['message']}');
      }
    } catch (e) {
      throw Exception('Text generation failed: $e');
    }
  }
}

  Future<String> _generateTextResponse(List<ChatMessage> conversation) async {
    try {
      final messages = [
        {
          'role': 'system',
          'content': '''
You are a highly knowledgeable and conversational AI assistant. Provide detailed, accurate, and complete responses, especially for complex tasks like generating full code for an e-commerce app. Ensure responses are logical, well-structured, and include all necessary components (e.g., frontend, backend, database). For code, use markdown code blocks (```dart, ```html, etc.) with explanatory comments. If the response is large, break it into logical sections and ensure completion. If asked to continue, pick up where you left off.
'''
        },
        ...conversation.map((msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.text,
            }),
      ];

      final response = await retry(
        () => http
            .post(
              Uri.parse(_apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                'model': 'gpt-4o',
                'messages': messages,
                'max_tokens': 4000,
                'temperature': 0.7,
                'top_p': 0.9,
              }),
            )
            .timeout(const Duration(seconds: 20)),
        retryIf: (e) => e is http.ClientException || e is TimeoutException,
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 2),
        onRetry: (e) => print('Retrying due to: $e'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String content = data['choices'][0]['message']['content'].trim();

        // Check for incomplete response
        if (content.endsWith('...') || content.contains('[CONTINUE]')) {
          final continuation = await _continueResponse(messages);
          return content + continuation;
        }
        return content;
      } else if (response.statusCode == 429) {
        return 'Error: Rate limit exceeded. Please wait and try again.';
      } else {
        return 'Error: Failed to get response (Status: ${response.statusCode}, Body: ${response.body}). Please try again.';
      }
    } on http.ClientException catch (e) {
      if (e.toString().contains('SocketException')) {
        return 'Error: Unable to connect to the server. Please check your internet connection.';
      }
      return 'Error: Network issue ($e). Please try again.';
    } on TimeoutException {
      return 'Error: Request timed out. Please check your connection and try again.';
    } catch (e, stackTrace) {
      print('Error: $e\nStackTrace: $stackTrace');
      return 'Error: An unexpected issue occurred ($e). Please try again.';
    }
  }

  Future<ImageResponse> _generateImageResponse(List<ChatMessage> conversation) async {
    try {
      final prompt = conversation.last.text;
      final response = await retry(
        () => http
            .post(
              Uri.parse(_imageApiUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                'prompt': prompt,
                'n': 1,
                'size': '512x512',
                'response_format': 'url',
              }),
            )
            .timeout(const Duration(seconds: 20)),
        retryIf: (e) => e is http.ClientException || e is TimeoutException,
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 2),
        onRetry: (e) => print('Retrying image generation due to: $e'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['data']?[0]?['url'];
        if (imageUrl == null) {
          return ImageResponse(
            text: 'Error: No image URL returned from API.',
          );
        }
        return ImageResponse(
          text: 'Generated image for your prompt:\n\n![Generated Image]($imageUrl)',
          imageUrl: imageUrl,
        );
      } else if (response.statusCode == 429) {
        return ImageResponse(
          text: 'Error: Rate limit exceeded for image generation. Please wait and try again.',
        );
      } else {
        return ImageResponse(
          text: 'Error: Failed to generate image (Status: ${response.statusCode}, Body: ${response.body}). Please try again.',
        );
      }
    } on http.ClientException catch (e) {
      if (e.toString().contains('SocketException')) {
        return ImageResponse(
          text: 'Error: Unable to connect to the server for image generation. Please check your internet.',
        );
      }
      return ImageResponse(
        text: 'Error: Network issue during image generation ($e). Please try again.',
      );
    } on TimeoutException {
      return ImageResponse(
        text: 'Error: Image generation timed out. Please try again.',
      );
    } catch (e, stackTrace) {
      print('Image generation error: $e\nStackTrace: $stackTrace');
      return ImageResponse(
        text: 'Error: Failed to generate image ($e). Please try again.',
      );
    }
  }

  Future<String> _continueResponse(List<Map<String, String>> previousMessages) async {
    try {
      final continuationMessages = [
        ...previousMessages,
        {
          'role': 'user',
          'content': 'Continue the previous response where it left off, ensuring the response is complete and detailed.',
        },
      ];

      final response = await retry(
        () => http
            .post(
              Uri.parse(_apiUrl), // Fixed from _textApiUrl
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode({
                'model': 'gpt-4o',
                'messages': continuationMessages,
                'max_tokens': 4000,
                'temperature': 0.7,
                'top_p': 0.9,
              }),
            )
            .timeout(const Duration(seconds: 20)),
        retryIf: (e) => e is http.ClientException || e is TimeoutException,
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 2),
        onRetry: (e) => print('Retrying continuation due to: $e'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content']?.trim() ?? '';
      } else if (response.statusCode == 429) {
        return '\nError: Rate limit exceeded for continuation. Please wait and try again.';
      }
      return '\nError: Failed to continue response (Status: ${response.statusCode}). Please try again.';
    } catch (e, stackTrace) {
      print('Continuation error: $e\nStackTrace: $stackTrace');
      return '\nError: Unable to continue response ($e). Please try again.';
    }
  }
}