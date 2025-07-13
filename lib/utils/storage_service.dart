import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session.dart';

class StorageService {
  static const String _sessionsKey = 'chat_sessions';

  Future<void> saveSession(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    sessions.removeWhere((s) => s.id == session.id);
    sessions.add(session);
    final jsonList = sessions.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_sessionsKey, jsonList);
  }

  Future<List<ChatSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_sessionsKey) ?? [];
    return jsonList.map((json) => ChatSession.fromJson(jsonDecode(json))).toList();
  }

  Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    final jsonList = sessions.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_sessionsKey, jsonList);
  }
}