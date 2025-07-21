import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import '../models/chat_message.dart';
import '../utils/connectivity_service.dart';

class ImageResponse {
  final String text;
  final List<String>? imageUrls;

  ImageResponse({required this.text, this.imageUrls});
}

class OpenAIService {
  final String apiKey =
      dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_DEFAULT_API_KEY';
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _imageApiUrl =
      'https://api.openai.com/v1/images/generations';

  // Enhanced prompt engineering for ultra-realistic, professional images
  String _enhancePrompt(String prompt) {
    return '''
Create a stunning, ultra-photorealistic, professional-grade image with exceptional detail and quality.

CORE REQUIREMENTS:
- 8K resolution quality, ultra-sharp details
- Professional photography/cinematography standards
- Perfect lighting: natural, dramatic, or studio-quality as appropriate
- Accurate proportions, anatomy, and physics
- Rich textures, materials, and surfaces
- Precise color grading and contrast
- Authentic depth of field and bokeh effects
- Zero artifacts, distortions, or unrealistic elements

SCENE DESCRIPTION:
$prompt

TECHNICAL SPECIFICATIONS:
- Photorealistic rendering with ray-traced lighting
- Advanced shadow mapping and global illumination
- High dynamic range (HDR) color space
- Professional camera settings simulation
- Accurate material properties (metal, glass, fabric, skin, etc.)
- Environmental consistency and atmospheric perspective
- Sharp focus where needed, natural blur for depth
- Award-winning composition and framing

STYLE GUIDELINES:
- Avoid cartoon, anime, or illustration styles unless explicitly requested
- Maintain realistic proportions and physics
- Use authentic lighting conditions
- Apply professional color correction
- Ensure all elements feel tangible and real
- Match the mood and atmosphere to the scene description
''';
  }

  // Enhanced keyword detection for better prompt understanding
  List<String> _extractKeywords(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    
    // Professional/Style keywords
    final styleKeywords = [
      'professional', 'cinematic', 'dramatic', 'elegant', 'luxury',
      'minimalist', 'modern', 'vintage', 'artistic', 'commercial',
      'editorial', 'fashion', 'portrait', 'landscape', 'macro',
      'architectural', 'interior', 'product', 'lifestyle'
    ];
    
    // Quality keywords
    final qualityKeywords = [
      'ultra-realistic', 'hyper-realistic', 'photorealistic', 'realistic',
      'high-quality', 'detailed', 'sharp', 'crisp', 'professional',
      '4k', '8k', 'hdr', 'studio quality'
    ];
    
    // Lighting keywords
    final lightingKeywords = [
      'golden hour', 'blue hour', 'sunset', 'sunrise', 'natural light',
      'studio lighting', 'dramatic lighting', 'soft lighting', 'harsh light',
      'backlit', 'rim lighting', 'ambient', 'moody'
    ];
    
    List<String> foundKeywords = [];
    for (var keyword in [...styleKeywords, ...qualityKeywords, ...lightingKeywords]) {
      if (lowerPrompt.contains(keyword)) {
        foundKeywords.add(keyword);
      }
    }
    
    return foundKeywords;
  }

  // Enhanced image generation with professional variations
  List<String> _createProfessionalVariations(String basePrompt, List<String> keywords) {
    final hasPortrait = basePrompt.toLowerCase().contains(RegExp(r'\b(person|people|human|face|portrait|man|woman|child)\b'));
    final hasLandscape = basePrompt.toLowerCase().contains(RegExp(r'\b(landscape|nature|outdoor|mountain|forest|beach|sky)\b'));
    final hasProduct = basePrompt.toLowerCase().contains(RegExp(r'\b(product|object|item|gadget|device)\b'));
    
    if (hasPortrait) {
      return [
        '$basePrompt, professional portrait photography with soft studio lighting and shallow depth of field',
        '$basePrompt, cinematic portrait with dramatic rim lighting and professional color grading',
        '$basePrompt, editorial fashion photography with perfect lighting and ultra-sharp detail'
      ];
    } else if (hasLandscape) {
      return [
        '$basePrompt, shot during golden hour with perfect natural lighting and atmospheric depth',
        '$basePrompt, captured with professional landscape photography techniques and HDR processing',
        '$basePrompt, cinematic wide-angle composition with dramatic sky and rich colors'
      ];
    } else if (hasProduct) {
      return [
        '$basePrompt, professional product photography with clean studio lighting and perfect reflections',
        '$basePrompt, commercial advertising style with dramatic lighting and premium presentation',
        '$basePrompt, editorial product shot with artistic lighting and sophisticated composition'
      ];
    } else {
      return [
        '$basePrompt, captured with professional photography equipment and perfect lighting',
        '$basePrompt, cinematic composition with dramatic lighting and ultra-realistic detail',
        '$basePrompt, award-winning photography with exceptional clarity and artistic vision'
      ];
    }
  }

  Future<ImageResponse> generateResponse(
    List<ChatMessage> messages, {
    required bool isImagePrompt,
    File? imageFile,
  }) async {

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print('Error: Invalid or missing OPENAI_API_KEY');
      throw Exception('Invalid OpenAI API key');
    }

    final prompt = messages.last.text.trim();
    final lowerPrompt = prompt.toLowerCase();
    
    // Enhanced auto-detection with more keywords
    final autoDetectImagePrompt = lowerPrompt.contains('generate an image') ||
        lowerPrompt.contains('create an image') ||
        lowerPrompt.contains('make an image') ||
        lowerPrompt.contains('draw') ||
        lowerPrompt.contains('create a picture') ||
        lowerPrompt.contains('image of') ||
        lowerPrompt.contains('photo of') ||
        lowerPrompt.contains('picture of') ||
        lowerPrompt.contains('show me') ||
        lowerPrompt.contains('visualize') ||
        lowerPrompt.contains('render') ||
        lowerPrompt.contains('design') ||
        lowerPrompt.contains('realistic') ||
        lowerPrompt.contains('ultra-realistic') ||
        lowerPrompt.contains('hyper-realistic') ||
        lowerPrompt.contains('photorealistic') ||
        lowerPrompt.contains('scene of') ||
        lowerPrompt.contains('view of') ||
        lowerPrompt.contains('shot of') ||
        lowerPrompt.contains('capture') ||
        lowerPrompt.contains('professional') ||
        lowerPrompt.contains('cinematic') ||
        lowerPrompt.contains('artistic');

    final shouldGenerateImage = isImagePrompt || autoDetectImagePrompt;

    print('Processing prompt: "$prompt"');
    print('Normalized prompt: "$lowerPrompt"');
    print('isImagePrompt: $shouldGenerateImage');

    if (isImagePrompt || shouldGenerateImage) {
      return await _generateImageResponse(messages, imageFile: imageFile);
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
            'messages': [
              {
                'role': 'system',
                'content': '''You are an exceptionally intelligent, creative, and precise AI assistant. You excel at understanding nuanced requests and providing comprehensive, accurate, and insightful responses. 

KEY PRINCIPLES:
- Analyze the user's intent deeply and respond with exceptional accuracy
- Provide detailed, well-structured, and professional responses
- When discussing visual concepts, be highly descriptive and precise
- Offer creative insights and professional-level expertise
- Maintain clarity while providing comprehensive information
- Always exceed expectations with the quality and depth of your responses'''
              },
              ...messages.map(
                (m) => {
                  'role': m.isUser ? 'user' : 'assistant',
                  'content': m.text,
                },
              ).toList(),
            ],
            'max_tokens': 4000,
            'temperature': 0.7,
            'top_p': 0.9,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return ImageResponse(
            text: data['choices'][0]['message']['content'],
            imageUrls: null,
          );
        } else {
          final errorData = jsonDecode(response.body);
          throw Exception(
            'Text generation error: ${errorData['error']['message']}',
          );
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
You are an elite AI assistant with exceptional intelligence, creativity, and precision. You excel at understanding complex requests and delivering outstanding responses that exceed expectations.

CORE CAPABILITIES:
- Deep analysis and nuanced understanding of user intent
- Professional-grade expertise across all domains
- Creative problem-solving with practical solutions
- Comprehensive yet clear communication
- Visual thinking and descriptive excellence
- Technical accuracy combined with creative insight

RESPONSE STANDARDS:
- Provide thorough, well-structured, and insightful answers
- Use professional language with appropriate technical depth
- Offer practical examples and actionable insights
- Maintain exceptional accuracy and attention to detail
- Deliver responses that demonstrate true expertise
- Always aim to provide more value than expected
''',
        },
        ...conversation.map(
          (msg) => {
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text,
          },
        ),
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

  Future<String> _continueResponse(
    List<Map<String, String>> previousMessages,
  ) async {
    try {
      final continuationMessages = [
        ...previousMessages,
        {
          'role': 'user',
          'content':
              'Continue the previous response where it left off, ensuring the response is complete, detailed, and maintains the same high quality and professional standard.',
        },
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

  Future<String> _describeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': 'You are an expert visual analyst. Provide extremely detailed, accurate, and professional descriptions of images. Focus on composition, lighting, colors, textures, mood, and technical aspects.'
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'Analyze this image with exceptional detail and professional insight. Describe everything you see including composition, lighting, colors, textures, mood, style, and any technical photographic elements.'},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                },
              ],
            },
          ],
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final description = data['choices']?[0]?['message']?['content'] as String?;
        print('Image description: $description');
        return description ?? 'No description available.';
      } else {
        print('Error describing image: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to describe image: ${response.body}');
      }
    } catch (e) {
      print('Error in _describeImage: $e');
      throw Exception('Failed to describe image: $e');
    }
  }

  Future<ImageResponse> _generateImageResponse(
    List<ChatMessage> conversation, {
    File? imageFile,
  }) async {
    try {
      final basePrompt = conversation.last.text.replaceAll('(with image)', '').trim();
      String prompt = basePrompt;
      String? imageDescription;
      
      if (imageFile != null) {
        imageDescription = await _describeImage(imageFile);
        prompt = '$basePrompt, inspired by and based on this reference: $imageDescription';
      }

      // Extract keywords for better understanding
      final keywords = _extractKeywords(basePrompt);
      print('Detected keywords: $keywords');

      final lowerPrompt = basePrompt.toLowerCase();
      bool isExplainPrompt = lowerPrompt.contains('explain this image') || 
                           lowerPrompt.contains('tell me about') ||
                           lowerPrompt.contains('describe this') ||
                           lowerPrompt.contains('what is this');
      
      // Enhanced image count logic
      int imageCount = 3; // Default professional variations
      if (lowerPrompt.contains('an image') ||
          lowerPrompt.contains('one image') ||
          lowerPrompt.contains('single image') ||
          lowerPrompt.contains('just one') ||
          isExplainPrompt) {
        imageCount = 1;
      } else if (lowerPrompt.contains('multiple images') ||
                 lowerPrompt.contains('several images') ||
                 lowerPrompt.contains('many images') ||
                 lowerPrompt.contains('different versions') ||
                 lowerPrompt.contains('variations')) {
        imageCount = 3;
      }

      // Handle explain prompts
      if (isExplainPrompt && imageFile != null && !lowerPrompt.contains('generate') && !lowerPrompt.contains('create')) {
        return ImageResponse(
          text: imageDescription ?? 'No description available for the image.',
          imageUrls: null,
        );
      }

      final List<String> imageUrls = [];
      final variations = _createProfessionalVariations(prompt, keywords);

      for (int i = 0; i < imageCount; i++) {
        final modifiedPrompt = imageCount == 1 ? prompt : variations[i % variations.length];
        final enhancedPrompt = _enhancePrompt(modifiedPrompt);
        
        final response = await retry(
          () => http
              .post(
                Uri.parse(_imageApiUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $apiKey',
                },
                body: jsonEncode({
                  'prompt': enhancedPrompt,
                  'n': 1,
                  'size': '1024x1024',
                  'model': 'dall-e-3',
                  'response_format': 'url',
                  'quality': 'hd', // High quality
                  'style': 'natural', // Natural/realistic style
                }),
              )
              .timeout(const Duration(seconds: 30)), // Longer timeout for quality
          retryIf: (e) => e is http.ClientException || e is TimeoutException,
          maxAttempts: 3,
          delayFactor: const Duration(seconds: 3),
          onRetry: (e) => print('Retrying image generation $i due to: $e'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final url = data['data']?[0]?['url'] as String?;
          if (url != null) {
            imageUrls.add(url);
            print('Successfully generated image ${i + 1}: $url');
          } else {
            print('Error: No image URL in response $i: ${response.body}');
          }
        } else {
          print('Error: DALL·E API failed for request $i with status ${response.statusCode}: ${response.body}');
        }
      }

      if (imageUrls.isEmpty) {
        return ImageResponse(
          text: 'Error: Unable to generate images. Please try refining your prompt or try again.',
        );
      }

      final qualityDescriptor = imageUrls.length > 1 ? 'professional-quality images' : 'professional-quality image';
      return ImageResponse(
        text: 'Successfully generated ${imageUrls.length} ultra-realistic, $qualityDescriptor with exceptional detail and photographic quality for your prompt.',
        imageUrls: imageUrls,
      );
    } on http.ClientException catch (e) {
      if (e.toString().contains('SocketException')) {
        return ImageResponse(
          text: 'Error: Unable to connect to the server for image generation. Please check your internet connection.',
        );
      }
      return ImageResponse(
        text: 'Error: Network issue during image generation ($e). Please try again.',
      );
    } on TimeoutException {
      return ImageResponse(
        text: 'Error: Image generation timed out. The server may be busy. Please try again.',
      );
    } catch (e, stackTrace) {
      print('Image generation error: $e\nStackTrace: $stackTrace');
      return ImageResponse(
        text: 'Error: Failed to generate images ($e). Please try again with a different prompt.',
      );
    }
  }
}
