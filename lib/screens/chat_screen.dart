import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:clipboard/clipboard.dart';
import 'package:uuid/uuid.dart';
import '../provider/theme_provider.dart';
import '../api/openai_service.dart';
import '../models/chat_message.dart';
import '../models/session.dart';
import '../utils/storage_service.dart';
import '../widgets/chat_bubble.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final ChatSession? initialSession;

  const ChatScreen({super.key, this.initialSession});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage; // Store selected/taken image
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StorageService storageService = StorageService();
  final OpenAIService openAIService = OpenAIService();
  final SpeechToText _speechToText = SpeechToText();
  late ChatSession _currentSession;
  bool _isBotTyping = false;
  bool _isSpeechEnabled = false;
  bool _isListening = false;
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.initialSession ??
        ChatSession(
          id: const Uuid().v4(),
          title: 'New Chat',
          messages: [],
          createdAt: DateTime.now(),
        );
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _initSpeech() async {
    try {
      bool initialized = await _speechToText.initialize(
        onStatus: (status) {
          setState(() => _isListening = status == 'listening');
        },
        onError: (error) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Voice input error: ${error.errorMsg}')),
          );
        },
      );
      setState(() => _isSpeechEnabled = initialized);
      if (!initialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice input initialization failed. Please enable microphone permissions.')),
        );
      }
    } catch (e) {
      setState(() => _isSpeechEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice input setup failed: $e')),
      );
    }
  }

  void _startListening() async {
    final permissionStatus = await Permission.microphone.status;
    if (permissionStatus.isGranted) {
      if (_isSpeechEnabled) {
        setState(() => _isListening = true);
        try {
          await _speechToText.listen(
            onResult: (result) {
              setState(() => _controller.text = result.recognizedWords);
            },
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 5),
            localeId: 'en_US',
          );
        } catch (e) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start voice input: $e')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice input unavailable. Please try again.')),
        );
      }
    } else {
      if (permissionStatus.isPermanentlyDenied) {
        showDialog(
          context: context,
          builder: (context) {
            final themeProvider = Provider.of<ThemeProvider>(context);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: themeProvider.themeMode == ThemeMode.dark ? Colors.grey[800] : Colors.white,
              title: const Text('Microphone Permission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              content: const Text('Microphone access is required for voice input. Please enable it in app settings.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    openAppSettings();
                    Navigator.pop(context);
                  },
                  child: Text('Open Settings', style: TextStyle(color: Colors.blue[700])),
                ),
              ],
            );
          },
        );
      } else {
        final newStatus = await Permission.microphone.request();
        if (newStatus.isGranted) {
          if (_isSpeechEnabled) {
            setState(() => _isListening = true);
            try {
              await _speechToText.listen(
                onResult: (result) {
                  setState(() => _controller.text = result.recognizedWords);
                },
                listenFor: const Duration(seconds: 30),
                pauseFor: const Duration(seconds: 5),
                localeId: 'en_US',
              );
            } catch (e) {
              setState(() => _isListening = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to start voice input: $e')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voice input unavailable. Please try again.')),
            );
          }
        } else {
          showDialog(
            context: context,
            builder: (context) {
              final themeProvider = Provider.of<ThemeProvider>(context);
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: themeProvider.themeMode == ThemeMode.dark ? Colors.grey[800] : Colors.white,
                title: const Text('Microphone Permission', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                content: const Text('Microphone access is required for voice input. Please grant permission to continue.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final newStatus = await Permission.microphone.request();
                      if (newStatus.isGranted) {
                        _startListening();
                      }
                    },
                    child: Text('Grant', style: TextStyle(color: Colors.blue[700])),
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

  void _stopListening() async {
    setState(() => _isListening = false);
    await _speechToText.stop();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _sendMessage({String? parentMessageId}) async {
    if (_controller.text.isEmpty && (_selectedImage == null || !await _selectedImage!.exists())) return;

    String promptText = _controller.text.trim();
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      text: _selectedImage != null ? '$promptText (with image)' : promptText,
      isUser: true,
      timestamp: DateTime.now(),
      parentMessageId: parentMessageId,
      imageUrls: _selectedImage != null ? [_selectedImage!.path] : null,
    );

    setState(() {
      _currentSession.messages.add(userMessage);
      _isBotTyping = true;
      _editingMessageId = null;
    });

    await storageService.saveSession(_currentSession);
    _scrollToBottom();

    _controller.clear();

    try {
      final prompt = promptText.toLowerCase().trim();
      final isImagePrompt = _selectedImage != null ||
          prompt.contains('generate image') ||
          prompt.contains('create image') ||
          prompt.contains('make image') ||
          prompt.contains('draw') ||
          prompt.contains('picture') ||
          prompt.contains('render') ||
          prompt.contains('art') ||
          prompt.contains('image of') ||
          prompt.contains('create an image') ||
          prompt.contains('generate an image') ||
          prompt.contains('explain this image') ||
          prompt.contains('tell me about');
      print('Processing prompt: "$promptText", image: $_selectedImage');
      print('Normalized prompt: "$prompt"');
      print('isImagePrompt: $isImagePrompt');
      final response = await openAIService.generateResponse(
        _currentSession.messages,
        isImagePrompt: isImagePrompt,
        imageFile: _selectedImage,
      );

      print('Received response: text=${response.text}, imageUrls=${response.imageUrls}');

      if (isImagePrompt && (response.imageUrls == null || response.imageUrls!.isEmpty)) {
        throw Exception('No images generated: ${response.text}');
      }

      setState(() {
        if (response.imageUrls != null && response.imageUrls!.isNotEmpty) {
          for (var url in response.imageUrls!) {
            _currentSession.messages.add(ChatMessage(
              id: const Uuid().v4(),
              text: 'Image generated successfully',
              imageUrls: [url],
              isUser: false,
              timestamp: DateTime.now(),
              parentMessageId: parentMessageId,
            ));
          }
        } else {
          _currentSession.messages.add(ChatMessage(
            id: const Uuid().v4(),
            text: response.text,
            imageUrls: null,
            isUser: false,
            timestamp: DateTime.now(),
            parentMessageId: parentMessageId,
          ));
        }
        _isBotTyping = false;
        _selectedImage = null;
      });
    } catch (e) {
      print('Error in _sendMessage: $e');
      setState(() {
        _isBotTyping = false;
        _selectedImage = null;
        _currentSession.messages.add(ChatMessage(
          id: const Uuid().v4(),
          text: 'Failed to generate response: ${e.toString().replaceFirst('Exception: ', '')}',
          imageUrls: null,
          isUser: false,
          timestamp: DateTime.now(),
          parentMessageId: parentMessageId,
        ));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process image or prompt: ${e.toString().replaceFirst('Exception: ', '')}'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _sendMessage(parentMessageId: parentMessageId),
          ),
        ),
      );
    }

    if (_currentSession.title == 'New Chat' && _currentSession.messages.isNotEmpty) {
      _currentSession = ChatSession(
        id: _currentSession.id,
        title: _currentSession.messages.first.text.length > 30
            ? '${_currentSession.messages.first.text.substring(0, 30)}...'
            : _currentSession.messages.first.text,
        messages: _currentSession.messages,
        createdAt: _currentSession.createdAt,
      );
    }

    await storageService.saveSession(_currentSession);
    _scrollToBottom();
  }

  void _updateMessage() async {
    if (_controller.text.isEmpty && (_selectedImage == null || !await _selectedImage!.exists()) || _editingMessageId == null) return;

    String promptText = _controller.text.trim();
    final updatedMessage = ChatMessage(
      id: _editingMessageId!,
      text: _selectedImage != null ? '$promptText (with image)' : promptText,
      isUser: true,
      timestamp: DateTime.now(),
      isEdited: true,
      parentMessageId: _currentSession.messages
          .firstWhere((m) => m.id == _editingMessageId)
          .parentMessageId,
      imageUrls: _selectedImage != null ? [_selectedImage!.path] : null,
    );

    setState(() {
      final index = _currentSession.messages.indexWhere((m) => m.id == _editingMessageId);
      if (index != -1) {
        _currentSession.messages[index] = updatedMessage;
      }
      _editingMessageId = null;
      _isBotTyping = true;
    });

    await storageService.saveSession(_currentSession);
    _controller.clear();

    try {
      final prompt = promptText.toLowerCase().trim();
      final isImagePrompt = _selectedImage != null ||
          prompt.contains('generate image') ||
          prompt.contains('create image') ||
          prompt.contains('make image') ||
          prompt.contains('draw') ||
          prompt.contains('picture') ||
          prompt.contains('render') ||
          prompt.contains('art') ||
          prompt.contains('image of') ||
          prompt.contains('create an image') ||
          prompt.contains('generate an image') ||
          prompt.contains('explain this image') ||
          prompt.contains('tell me about');
      print('Processing edited prompt: "$promptText", image: $_selectedImage');
      print('Normalized prompt: "$prompt"');
      print('isImagePrompt: $isImagePrompt');
      final response = await openAIService.generateResponse(
        _currentSession.messages,
        isImagePrompt: isImagePrompt,
        imageFile: _selectedImage,
      );

      print('Received response: text=${response.text}, imageUrls=${response.imageUrls}');

      if (isImagePrompt && (response.imageUrls == null || response.imageUrls!.isEmpty)) {
        throw Exception('No images generated: ${response.text}');
      }

      setState(() {
        if (response.imageUrls != null && response.imageUrls!.isNotEmpty) {
          for (var url in response.imageUrls!) {
            _currentSession.messages.add(ChatMessage(
              id: const Uuid().v4(),
              text: 'Image generated successfully',
              imageUrls: [url],
              isUser: false,
              timestamp: DateTime.now(),
              parentMessageId: updatedMessage.parentMessageId,
            ));
          }
        } else {
          _currentSession.messages.add(ChatMessage(
            id: const Uuid().v4(),
            text: response.text,
            imageUrls: null,
            isUser: false,
            timestamp: DateTime.now(),
            parentMessageId: updatedMessage.parentMessageId,
          ));
        }
        _isBotTyping = false;
        _selectedImage = null;
      });
    } catch (e) {
      print('Error in _updateMessage: $e');
      setState(() {
        _isBotTyping = false;
        _selectedImage = null;
        _currentSession.messages.add(ChatMessage(
          id: const Uuid().v4(),
          text: 'Failed to generate response: ${e.toString().replaceFirst('Exception: ', '')}',
          imageUrls: null,
          isUser: false,
          timestamp: DateTime.now(),
          parentMessageId: updatedMessage.parentMessageId,
        ));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process image or prompt: ${e.toString().replaceFirst('Exception: ', '')}'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _updateMessage,
          ),
        ),
      );
    }

    await storageService.saveSession(_currentSession);
    _scrollToBottom();
  }

  void _editMessage(ChatMessage message) {
    final editController = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: themeProvider.themeMode == ThemeMode.dark ? Colors.grey[800] : Colors.white,
          title: const Text('Edit Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          content: TextField(
            controller: editController,
            decoration: InputDecoration(
              hintText: 'Edit your message...',
              hintStyle: TextStyle(color: themeProvider.themeMode == ThemeMode.dark ? Colors.grey[400] : Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: themeProvider.themeMode == ThemeMode.dark ? Colors.grey[700] : Colors.grey[100],
            ),
            minLines: 1,
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (editController.text.isNotEmpty) {
                  setState(() {
                    _editingMessageId = message.id;
                    _controller.text = editController.text;
                  });
                  _updateMessage();
                  Navigator.pop(context);
                }
              },
              child: Text('Save', style: TextStyle(color: Colors.blue[700])),
            ),
          ],
        );
      },
    );
  }

  void _copyResponse(String text) {
    showDialog(
      context: context,
      builder: (context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final selectController = TextEditingController(text: text);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: themeProvider.themeMode == ThemeMode.dark ? Colors.grey[800] : Colors.white,
          title: const Text('Copy Response', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: TextField(
              controller: selectController,
              decoration: InputDecoration(
                hintText: 'Select or edit text to copy...',
                hintStyle: TextStyle(color: themeProvider.themeMode == ThemeMode.dark ? Colors.grey[400] : Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: themeProvider.themeMode == ThemeMode.dark ? Colors.grey[700] : Colors.grey[100],
              ),
              minLines: 3,
              maxLines: 10,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                FlutterClipboard.copy(text).then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Full response copied')),
                  );
                  Navigator.pop(context);
                });
              },
              child: Text('Copy All', style: TextStyle(color: Colors.blue[700])),
            ),
            TextButton(
              onPressed: () {
                if (selectController.selection.isValid) {
                  final selectedText = selectController.text.substring(
                    selectController.selection.start,
                    selectController.selection.end,
                  );
                  if (selectedText.isNotEmpty) {
                    FlutterClipboard.copy(selectedText).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selected text copied')),
                      );
                      Navigator.pop(context);
                    });
                  }
                }
              },
              child: Text('Copy Selected', style: TextStyle(color: Colors.blue[700])),
            ),
          ],
        );
      },
    );
  }

  void _downloadImage(String imageUrl, BuildContext context) async {
    try {
      if (!(await Permission.storage.request()).isGranted) {
        if ((await Permission.storage.status).isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable storage permission in settings')),
          );
          await openAppSettings();
          return;
        }
        throw Exception('Storage permission denied');
      }

      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Unable to access Downloads directory');
      }
      final filePath = '${directory.path}/image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image saved to Downloads: $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download image: $e')),
      );
    }
  }

 void _pickImage(ImageSource source) async {
    // Show loading indicator for better UX
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      PermissionStatus permissionStatus = PermissionStatus.denied;
      
      if (source == ImageSource.camera) {
        // Handle camera permissions
        permissionStatus = await Permission.camera.status;
        if (!permissionStatus.isGranted) {
          permissionStatus = await Permission.camera.request();
          if (!permissionStatus.isGranted) {
            if (permissionStatus.isPermanentlyDenied) {
              Navigator.of(context).pop(); // Close loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Camera access is required. Please enable it in app settings.'),
                ),
              );
              await openAppSettings();
              return;
            }
            Navigator.of(context).pop(); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Camera permission denied.')),
            );
            return;
          }
        }
      } else {
        // Handle gallery permissions
        bool permissionGranted = false;
        
        if (Platform.isAndroid) {
          // Get Android SDK version
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          final sdkInt = androidInfo.version.sdkInt;
          
          if (sdkInt >= 33) {
            // Android 13+ (API 33+) - Use granular media permissions
            permissionStatus = await Permission.photos.status;
            if (!permissionStatus.isGranted) {
              permissionStatus = await Permission.photos.request();
            }
            permissionGranted = permissionStatus.isGranted;
          } else if (sdkInt >= 30) {
            // Android 11-12 (API 30-32) - Check storage permission first
            permissionStatus = await Permission.storage.status;
            if (!permissionStatus.isGranted) {
              permissionStatus = await Permission.storage.request();
            }
            permissionGranted = permissionStatus.isGranted;
            
            // For some devices, also check photos permission as fallback
            if (!permissionGranted) {
              final photosStatus = await Permission.photos.status;
              if (!photosStatus.isGranted) {
                final requestedStatus = await Permission.photos.request();
                if (requestedStatus.isGranted) {
                  permissionGranted = true;
                  permissionStatus = requestedStatus;
                }
              } else {
                permissionGranted = true;
                permissionStatus = photosStatus;
              }
            }
          } else {
            // Android 10 and below - Use storage permission
            permissionStatus = await Permission.storage.status;
            if (!permissionStatus.isGranted) {
              permissionStatus = await Permission.storage.request();
            }
            permissionGranted = permissionStatus.isGranted;
          }
        } else if (Platform.isIOS) {
          // iOS - Use photos permission
          permissionStatus = await Permission.photos.status;
          if (!permissionStatus.isGranted) {
            permissionStatus = await Permission.photos.request();
          }
          permissionGranted = permissionStatus.isGranted;
        } else {
          // Unsupported platform
          permissionStatus = PermissionStatus.denied;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Platform not supported for gallery access.')),
          );
          return;
        }
        
        if (!permissionGranted) {
          Navigator.of(context).pop(); // Close loading
          if (permissionStatus.isPermanentlyDenied) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gallery access is required. Please enable it in app settings.'),
              ),
            );
            await openAppSettings();
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gallery permission denied.')),
          );
          return;
        }
      }

      // Pick image after permission is granted
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 75, // Slightly lower for better performance
        maxWidth: 800,    // Reduced for better performance
        maxHeight: 800,
        preferredCameraDevice: CameraDevice.rear,
      );

      // Close loading indicator
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (await file.exists()) {
          final fileSize = await file.length();
          if (fileSize > 20 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image size exceeds 20MB limit.')),
            );
            return;
          }
          
          setState(() {
            _selectedImage = file;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image selected: ${pickedFile.path.split('/').last}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected image is not accessible.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected.')),
        );
      }
    } catch (e) {
      // Close loading indicator on error
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }


@override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentSession.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: themeProvider.themeMode == ThemeMode.dark ? Colors.grey[850] : Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      drawer: Drawer(child: SessionList(storageService: storageService)),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/bg_image.png'),
            fit: BoxFit.cover,
            opacity: 0.05,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: _currentSession.messages.length + (_isBotTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isBotTyping && index == _currentSession.messages.length) {
                    return FadeIn(
                      duration: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Lottie.asset(
                          'assets/animations/loading.json',
                          width: 160,
                          height: 160,
                        ),
                      ),
                    );
                  }
                  final message = _currentSession.messages[index];
                  final isThread = message.parentMessageId != null;
                  return FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: isThread ? 20.0 : 0,
                        bottom: 12.0,
                      ),
                      child: GestureDetector(
                        onLongPress: () {
                          if (message.isUser) {
                            _editMessage(message);
                          } else {
                            _copyResponse(message.text);
                          }
                        },
                        child: ChatBubble(
                          message: message,
                          onReply: (msg) => _sendMessage(parentMessageId: msg.id),
                          downloadImage: _downloadImage,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: themeProvider.themeMode == ThemeMode.dark ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        _buildQuickReplyChip('Generate Image', 'Generate an image of '),
                        const SizedBox(width: 8),
                        _buildQuickReplyChip('Explain Code', 'Explain the following code: '),
                        const SizedBox(width: 8),
                        _buildQuickReplyChip('Summarize', 'Summarize the following: '),
                        const SizedBox(width: 8),
                        _buildQuickReplyChip('Translate', 'Translate to English: '),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.transparent,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening ? Colors.red : Colors.grey[600],
                                size: 28,
                              ),
                              onPressed: _isListening ? _stopListening : _startListening,
                              tooltip: 'Voice Input',
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.photo,
                              color: Colors.grey[600],
                              size: 28,
                            ),
                            onPressed: () => _pickImage(ImageSource.gallery),
                            tooltip: 'Pick Image from Gallery',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.camera_alt,
                              color: Colors.grey[600],
                              size: 28,
                            ),
                            onPressed: () => _pickImage(ImageSource.camera),
                            tooltip: 'Take Photo',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                hintText: _editingMessageId == null
                                    ? 'Ask anything...'
                                    : 'Editing message...',
                                hintStyle: TextStyle(
                                  color: themeProvider.themeMode == ThemeMode.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                filled: true,
                                fillColor: themeProvider.themeMode == ThemeMode.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              style: const TextStyle(fontSize: 16),
                              minLines: 1,
                              maxLines: 4,
                              onSubmitted: (_) => _editingMessageId == null
                                  ? _sendMessage()
                                  : _updateMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _editingMessageId == null ? Icons.send : Icons.check,
                              color: Colors.blue[700],
                              size: 28,
                            ),
                            onPressed: _editingMessageId == null
                                ? _sendMessage
                                : _updateMessage,
                            tooltip: _editingMessageId == null ? 'Send' : 'Save Edit',
                          ),
                        ],
                      ),
                      if (_selectedImage != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.file(
                                    _selectedImage!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, color: Colors.red),
                                  ),
                                ),
                                if (_isBotTyping)
                                  CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.cancel,
                                color: Colors.grey[600],
                                size: 24,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },
                              tooltip: 'Clear Image',
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildQuickReplyChip(String label, String prefix) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 14)),
      backgroundColor: Provider.of<ThemeProvider>(context).themeMode == ThemeMode.dark
          ? Colors.grey[700]
          : Colors.blue[100],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        _controller.text = prefix;
        FocusScope.of(context).requestFocus(FocusNode());
      },
    );
  }
}
class SessionList extends StatefulWidget {
  final StorageService storageService;

  const SessionList({super.key, required this.storageService});

  @override
  _SessionListState createState() => _SessionListState();
}

class _SessionListState extends State<SessionList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).appBarTheme.backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FadeInDown(
                duration: const Duration(milliseconds: 300),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).textTheme.bodySmall?.color),
                    filled: true,
                    fillColor: Theme.of(context).cardColor.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ChatSession>>(
                future: widget.storageService.getSessions(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final sessions = snapshot.data!
                      .where((session) => session.title.toLowerCase().contains(_searchQuery))
                      .toList();
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: sessions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return FadeInLeft(
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: const Icon(Icons.add, color: Colors.white, size: 20),
                              ),
                              title: const Text(
                                'New Conversation',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              tileColor: Theme.of(context).cardColor,
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                                );
                              },
                            ),
                          ),
                        );
                      }
                      final session = sessions[index - 1];
                      return FadeInLeft(
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                              child: Text(
                                session.title.isNotEmpty ? session.title[0].toUpperCase() : 'C',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                            title: Text(
                              session.title.isEmpty ? 'Untitled Chat' : session.title,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              session.createdAt.toString().substring(0, 16),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                              onPressed: () async {
                                await widget.storageService.deleteSession(session.id);
                                setState(() {});
                              },
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            tileColor: Theme.of(context).cardColor,
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(initialSession: session),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}