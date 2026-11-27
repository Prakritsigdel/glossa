import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:glossa_app/shared/models/course_models.dart';
import 'package:glossa_app/shared/models/demo_user.dart';
import 'package:glossa_app/shared/models/leaderboard_entry.dart';

import 'dart:convert';

class BackendApi {
  BackendApi({http.Client? client, FlutterSecureStorage? storage})
    : _client = client ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  int _sessionGeneration = 0;
  Future<void> _credentialMutation = Future<void>.value();

  Future<T> _serializeCredentialMutation<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _credentialMutation = _credentialMutation.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  /// Explicit override via --dart-define=API_BASE_URL=...
  /// Takes priority over all automatic detection.
  static const _configuredUrl = String.fromEnvironment('API_BASE_URL');
  static String? _resolvedUrl;

  /// Detect the correct base URL based on the runtime platform.
  ///
  /// Priority:
  ///   1. --dart-define=API_BASE_URL=... (explicit override)
  ///   2. Dynamically resolved working URL (cached after probe)
  ///   3. Android -> defaults to http://127.0.0.1:8000 (physical device with adb reverse)
  ///      with automatic fallback to http://10.0.2.2:8000 (emulator).
  ///   4. Desktop (Windows/macOS/Linux) -> http://127.0.0.1:8000.
  static String get baseUrl {
    if (_configuredUrl.isNotEmpty) return _configuredUrl;
    if (_resolvedUrl != null) return _resolvedUrl!;
    return 'http://127.0.0.1:8000';
  }

  /// Manually override or reset the resolved URL (useful for testing or fallback).
  static void setResolvedUrl(String? url) {
    _resolvedUrl = url;
  }

  /// Human-readable description of the current backend target.
  static String get backendTarget => baseUrl;

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
    final requestGeneration = _sessionGeneration;
    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1$path',
    );
    if (kDebugMode) debugPrint('[BackendApi] $method $uri');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final savedToken = authenticated ? await token : null;
    if (authenticated && requestGeneration != _sessionGeneration) {
      throw const BackendException(
        'The account session changed. Please retry.',
      );
    }
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
    } on SocketException catch (e) {
      if (authenticated && requestGeneration != _sessionGeneration) {
        throw const BackendException(
          'The account session changed. Please retry.',
        );
      }
      if (kDebugMode) debugPrint('[BackendApi] SocketException: ${e.message}');
      // On Android, if default 127.0.0.1:8000 failed and no URL was explicitly configured,
      // probe 10.0.2.2:8000 (emulator loopback) as automatic fallback.
      if (_configuredUrl.isEmpty &&
          _resolvedUrl == null &&
          defaultTargetPlatform == TargetPlatform.android &&
          baseUrl == 'http://127.0.0.1:8000') {
        try {
          final probe = await _client
              .get(Uri.parse('http://10.0.2.2:8000/health'))
              .timeout(const Duration(seconds: 2));
          if (probe.statusCode == 200) {
            _resolvedUrl = 'http://10.0.2.2:8000';
            if (kDebugMode) {
              debugPrint('[BackendApi] Resolved emulator URL: $_resolvedUrl');
            }
            return await _request(
              method,
              path,
              body: body,
              authenticated: authenticated,
            );
          }
        } catch (_) {}
      }
      throw const BackendException(
        'Unable to connect to the Glossa server. Check that the backend is '
        'running and your device can reach it.',
      );
    } on TimeoutException {
      if (authenticated && requestGeneration != _sessionGeneration) {
        throw const BackendException(
          'The account session changed. Please retry.',
        );
      }
      // Same check for TimeoutException on Android
      if (_configuredUrl.isEmpty &&
          _resolvedUrl == null &&
          defaultTargetPlatform == TargetPlatform.android &&
          baseUrl == 'http://127.0.0.1:8000') {
        try {
          final probe = await _client
              .get(Uri.parse('http://10.0.2.2:8000/health'))
              .timeout(const Duration(seconds: 2));
          if (probe.statusCode == 200) {
            _resolvedUrl = 'http://10.0.2.2:8000';
            if (kDebugMode) {
              debugPrint('[BackendApi] Resolved emulator URL: $_resolvedUrl');
            }
            return await _request(
              method,
              path,
              body: body,
              authenticated: authenticated,
            );
          }
        } catch (_) {}
      }
      throw const BackendException(
        'The server did not respond in time. Make sure the backend is running '
        'with `docker compose up --build` or `start_backend.bat`.',
      );
    } on HttpException catch (e) {
      if (kDebugMode) debugPrint('[BackendApi] HttpException: ${e.message}');
      throw const BackendException(
        'Unable to connect to the Glossa server. Check your network '
        'connection and try again.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[BackendApi] Unexpected error: $e');
      throw const BackendException(
        'A network error occurred. Please check your connection and try again.',
      );
    }
    if (authenticated && requestGeneration != _sessionGeneration) {
      throw const BackendException(
        'The account session changed. Please retry.',
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
    final generation = _sessionGeneration;
    final data = await _request('POST', path, body: body, authenticated: false);
    await _serializeCredentialMutation(() async {
      if (generation != _sessionGeneration) {
        throw const BackendException(
          'Authentication was superseded by another account change.',
        );
      }
      await _storage.write(
        key: 'glossa_access_token',
        value: data['access_token'] as String,
      );
    });
    if (generation != _sessionGeneration) {
      throw const BackendException(
        'Authentication was superseded by another account change.',
      );
    }
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

  Future<void> logout() {
    ++_sessionGeneration;
    return _serializeCredentialMutation(
      () => _storage.delete(key: 'glossa_access_token'),
    );
  }

  Future<DemoUser> me() async => _user(await _request('GET', '/me'));

  Future<DemoUser> updateProfile({String? name, int? heroIndex}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (heroIndex != null) body['hero_index'] = heroIndex;
    return _user(await _request('PATCH', '/me', body: body));
  }

  // ─── Multi-language course endpoints ────────────────────────

  Future<DemoUser> updateActiveCourse(String courseId) async {
    final data = await _request(
      'PUT',
      '/users/me/active-course',
      body: {'active_course_id': courseId},
    );
    return _user(data['user'] as Map<String, dynamic>? ?? data);
  }

  Future<List<Lesson>> lessons({String? courseId}) async {
    final path = courseId != null ? '/lessons?course_id=$courseId' : '/lessons';
    final result = await _request('GET', path);
    return (result['data'] as List)
        .map((item) => _lesson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch exercises for a lesson from the public endpoint.
  ///
  /// The backend intentionally excludes correct-answer configuration
  /// (pairs, answer_id, correct_answer_config) from public responses.
  /// Correctness is determined server-side via [checkAnswer] and
  /// [submitAttempt].
  Future<List<Exercise>> exercises(String lessonId) async {
    final result = await _request('GET', '/lessons/$lessonId/exercises');
    return (result['data'] as List)
        .map((item) => _exercise(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> startLessonRun(String lessonId) =>
      _request('POST', '/lessons/$lessonId/start');

  Future<Map<String, dynamic>> reviewQueue(String lessonId, String runId) =>
      _request('GET', '/lessons/$lessonId/runs/$runId/review-queue');

  /// Check a single exercise answer via the per-exercise endpoint.
  ///
  /// Returns true if the answer is correct. Network errors are rethrown
  /// so the UI can display them and offer retry — they are never silently
  /// treated as incorrect.
  Future<bool> checkAnswer(String lessonId, Map<String, dynamic> answer) async {
    final result = await answerExercise(lessonId, answer);
    return result['correct'] as bool;
  }

  Future<Map<String, dynamic>> answerExercise(
    String lessonId,
    Map<String, dynamic> answer,
  ) async {
    return _request('POST', '/lessons/$lessonId/answer', body: answer);
  }

  /// Submit a complete lesson attempt.
  ///
  /// [answers] is a list of per-exercise answer maps matching
  /// [ExerciseAnswerIn]: exercise_id, selected_option_id, selected_pairs,
  /// selected_tile_ids.
  /// [idempotencyKey] scopes the submission to this user+lesson+request
  /// so duplicate network retries do not award double XP.
  Future<Map<String, dynamic>> submitAttempt(
    String lessonId, {
    required List<Map<String, dynamic>> answers,
    String? idempotencyKey,
  }) async {
    final body = answers.isEmpty && idempotencyKey != null
        ? <String, dynamic>{'run_id': idempotencyKey}
        : <String, dynamic>{'answers': answers};
    if (answers.isNotEmpty && idempotencyKey != null) {
      body['idempotency_key'] = idempotencyKey;
    }
    return _request('POST', '/lessons/$lessonId/attempts', body: body);
  }

  /// Fetch the town map: all lessons for a course with availability status.
  Future<List<Map<String, dynamic>>> townMap(String courseId) async {
    final result = await _request('GET', '/courses/$courseId/town-map');
    final rows = result['data'] as List;
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<LeaderboardEntry>> leaderboard(String filter) async {
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
    id: row['id'].toString(),
    name: row['name'] as String,
    email: row['email'] as String,
    heroIndex: row['hero_index'] as int,
    heroClassName: row['hero_class_name'] as String,
    level: row['level'] as int,
    xp: row['xp'] as int,
    xpToNextLevel: row['xp_to_next_level'] as int,
    xpInLevel: (row['xp_in_level'] as num?)?.toInt() ?? 0,
    streak: row['streak'] as int,
    wordsFound: row['words_found'] as int,
    lessonsCompleted: row['lessons_completed'] as int,
    activeCourseId: row['active_course_id'] as String?,
    heroStats: (row['hero_stats'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    ),
  );

  Lesson _lesson(Map<String, dynamic> row) => Lesson(
    id: row['id'] as String,
    unitId: row['unit_id'] != null ? (row['unit_id'] as num).toInt() : null,
    sequence: row['sequence'] != null ? (row['sequence'] as num).toInt() : null,
    unitTitle: row['unit_title'] as String?,
    title: row['title'] as String,
    subtitle: row['subtitle'] as String,
    exerciseType: _exerciseType(row['exercise_type'] as String),
    status: _lessonStatus(row['status'] as String),
    xpReward: (row['xp_reward'] as num?)?.toInt() ?? 20,
    wordCount: (row['word_count'] as num?)?.toInt() ?? 4,
    requiredLevel: (row['required_level'] as num?)?.toInt() ?? 1,
    isPublished: (row['is_published'] as bool?) ?? true,
    isCheckpoint: (row['is_checkpoint'] as bool?) ?? false,
    isCapstone: (row['is_capstone'] as bool?) ?? false,
    availability: row['availability'] as String? ?? 'locked',
    plannedExerciseCount: (row['planned_exercise_count'] as num?)?.toInt() ?? 0,
    populatedExerciseCount:
        (row['populated_exercise_count'] as num?)?.toInt() ?? 0,
  );

  Exercise _exercise(Map<String, dynamic> row) {
    // The backend serializes ExerciseOut.exercise_type; keep "type" as a
    // fallback so payloads from older responses still parse.
    final type = _exerciseType((row['exercise_type'] ?? row['type']) as String);
    final optionsRaw = row['options'] as List? ?? [];
    final options = optionsRaw.map((raw) {
      final option = raw as Map<String, dynamic>;
      return AnswerOption(
        id: option['id'] as String,
        text: option['text'] as String,
        imageKey: option['image_key'] as String?,
        isDevanagari: option['is_devanagari'] ?? false,
        romanization: option['romanization'] as String?,
      );
    }).toList();

    final wordTilesRaw = row['word_tiles'] as List? ?? [];
    final wordTiles = wordTilesRaw.map((raw) {
      final tile = raw as Map<String, dynamic>;
      return AnswerOption(
        id: tile['id'] as String,
        text: tile['text'] as String,
        imageKey: tile['image_key'] as String?,
        isDevanagari: tile['is_devanagari'] ?? false,
        romanization: tile['romanization'] as String?,
      );
    }).toList();

    final dialogueRaw = row['dialogue_structure'] as List?;
    final dialogueStructure = dialogueRaw
        ?.map((raw) => raw as Map<String, dynamic>)
        .toList();

    return Exercise(
      id: row['id'] as String,
      type: type,
      instruction: row['instruction'] as String,
      xp: (row['xp'] as num?)?.toInt() ?? 0,
      prompt: row['prompt'] as String?,
      promptHint: row['prompt_hint'] as String?,
      imageKey: row['image_key'] as String?,
      audioKey: row['audio_key'] as String?,
      options: options,
      newariScript: row['newari_script'] as String?,
      romanization: row['romanization'] as String?,
      wordTiles: wordTiles,
      dialogueStructure: dialogueStructure,
      illustrationId: row['illustration_id'] as String?,
      vocabularyReference: row['vocabulary_reference'] != null
          ? (row['vocabulary_reference'] as Map<String, dynamic>)
          : null,
      layout: row['layout'] as Map<String, dynamic>?,
      variant: row['variant'] as String?,
      plannedType: row['planned_type'] as String?,
      phraseTargetEn: row['phrase_target_en'] as String?,
    );
  }

  ExerciseType _exerciseType(String value) => switch (value) {
    'matchWords' => ExerciseType.matchWords,
    'fillBlank' => ExerciseType.fillBlank,
    'pictureToWord' => ExerciseType.pictureToWord,
    'wordToPicture' => ExerciseType.wordToPicture,
    _ => throw FormatException('Unsupported exercise type: $value'),
  };

  LessonStatus _lessonStatus(String value) => switch (value) {
    'cleared' || 'completed' => LessonStatus.completed,
    'locked' => LessonStatus.locked,
    'unavailable' => LessonStatus.unavailable,
    _ => LessonStatus.available,
  };
}

class BackendException implements Exception {
  const BackendException(this.message);
  final String message;
  @override
  String toString() => message;
}
