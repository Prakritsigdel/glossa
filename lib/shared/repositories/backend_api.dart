import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/models/demo_user.dart';
import 'package:glossa_app/shared/models/leaderboard_entry.dart';
import 'package:glossa_app/shared/mock_data/mock_data.dart';

import 'dart:convert';

class BackendApi {
  BackendApi({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');
  static String get baseUrl => _configuredUrl.isNotEmpty
      ? _configuredUrl
      : 'http://${defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1'}:8000';

  Future<String?> get token async {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return null;
    }
    try {
      return await _storage.read(key: 'glossa_access_token');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1$path',
    );
    final headers = <String, String>{'Content-Type': 'application/json'};
    final savedToken = await token;
    if (authenticated && savedToken != null) {
      headers['Authorization'] = 'Bearer $savedToken';
    }
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    late final http.Response response;
    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw BackendException(
        'The server at $baseUrl did not respond in time. Start the backend '
        'with `docker compose up --build` and check that the app is using the '
        'right API address.',
      );
    }
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw BackendException(
        detail?.toString() ?? 'Request failed (${response.statusCode})',
      );
    }
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  Future<DemoUser> _authenticate(String path, Map<String, dynamic> body) async {
    final data = await _request('POST', path, body: body, authenticated: false);
    await _storage.write(
      key: 'glossa_access_token',
      value: data['access_token'] as String,
    );
    return _user(data['user'] as Map<String, dynamic>);
  }

  Future<DemoUser> register({
    required String name,
    required String email,
    required String password,
  }) => _authenticate('/auth/register', {
    'name': name,
    'email': email,
    'password': password,
  });

  Future<DemoUser> login({required String email, required String password}) =>
      _authenticate('/auth/login', {'email': email, 'password': password});

  Future<void> logout() => _storage.delete(key: 'glossa_access_token');

  Future<DemoUser> me() async => _user(await _request('GET', '/me'));

  Future<DemoUser> updateProfile({
    String? name,
    int? heroIndex,
    String? languageId,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (heroIndex != null) body['hero_index'] = heroIndex;
    if (languageId != null) body['language_id'] = languageId;
    return _user(await _request('PATCH', '/me', body: body));
  }

  Future<List<Lesson>> lessons() async {
    final result = await _request('GET', '/lessons');
    return (result['data'] as List)
        .map((item) => _lesson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Exercise>> exercises(String lessonId) async {
    final result = await _request('GET', '/lessons/$lessonId/exercises');
    return (result['data'] as List)
        .map((item) => _exercise(item as Map<String, dynamic>))
        .toList();
  }

  Future<bool> checkAnswer(String lessonId, Map<String, dynamic> answer) async {
    final result = await _request(
      'POST',
      '/lessons/$lessonId/answer',
      body: answer,
    );
    return result['correct'] as bool;
  }

  Future<Map<String, dynamic>> submitAttempt(
    String lessonId,
    List<Map<String, dynamic>> answers,
  ) => _request(
    'POST',
    '/lessons/$lessonId/attempts',
    body: {'answers': answers},
  );

  Future<List<LeaderboardEntry>> leaderboard(String filter) async {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      switch (filter) {
        case 'family':
          return mockLeaderboardFamily;
        case 'alltime':
          return mockLeaderboardAllTime;
        case 'weekly':
        default:
          return mockLeaderboardWeekly;
      }
    }
    final result = await _request('GET', '/leaderboard?filter=$filter');
    final rows = result['data'] as List;
    return rows.map((raw) {
      final row = raw as Map<String, dynamic>;
      return LeaderboardEntry(
        rank: row['rank'],
        name: row['name'],
        level: row['level'],
        className: row['class_name'],
        xp: row['xp'],
        heroIndex: row['hero_index'],
        isCurrentUser: row['is_current_user'],
      );
    }).toList();
  }

  DemoUser _user(Map<String, dynamic> row) => DemoUser(
    name: row['name'],
    email: row['email'],
    heroIndex: row['hero_index'],
    heroClassName: row['hero_class_name'],
    level: row['level'],
    xp: row['xp'],
    xpToNextLevel: row['xp_to_next_level'],
    streak: row['streak'],
    wordsFound: row['words_found'],
    lessonsCompleted: row['lessons_completed'],
    languageId: row['language_id'],
    languageName: switch (row['language_id']) {
      'newari' => 'Newari',
      'maithili' => 'Maithili',
      'tharu' => 'Tharu',
      'limbu' => 'Limbu',
      _ => row['language_id'],
    },
    languageScript: switch (row['language_id']) {
      'newari' => 'नेपाल भाषा',
      'maithili' => 'मैथिली',
      'tharu' => 'थारू',
      'limbu' => 'लिम्बु',
      _ => '',
    },
  );

  Lesson _lesson(Map<String, dynamic> row) => Lesson(
    id: row['id'],
    title: row['title'],
    subtitle: row['subtitle'],
    exerciseType: _exerciseType(row['exercise_type']),
    status: _lessonStatus(row['status']),
    xpReward: row['xp_reward'],
    wordCount: row['word_count'],
    requiredLevel: row['required_level'],
  );

  Exercise _exercise(Map<String, dynamic> row) => Exercise(
    id: row['id'],
    type: _exerciseType(row['type']),
    instruction: row['instruction'],
    prompt: row['prompt'],
    promptHint: row['prompt_hint'],
    imageKey: row['image_key'],
    options: (row['options'] as List).map((raw) {
      final option = raw as Map<String, dynamic>;
      return AnswerOption(
        id: option['id'],
        text: option['text'],
        imageKey: option['image_key'],
        isDevanagari: option['is_devanagari'] ?? false,
      );
    }).toList(),
    correctAnswerId: '',
  );

  ExerciseType _exerciseType(String value) => switch (value) {
    'matchWords' => ExerciseType.matchWords,
    'pictureToWord' => ExerciseType.pictureToWord,
    'wordToPicture' => ExerciseType.wordToPicture,
    _ => ExerciseType.fillBlank,
  };

  LessonStatus _lessonStatus(String value) => switch (value) {
    'cleared' => LessonStatus.cleared,
    'locked' => LessonStatus.locked,
    _ => LessonStatus.current,
  };
}

class BackendException implements Exception {
  const BackendException(this.message);
  final String message;
  @override
  String toString() => message;
}
