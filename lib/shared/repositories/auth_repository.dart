import '../models/demo_user.dart';

/// Interface for authentication operations.
/// In-memory demo implementation; replace with Firebase in future.
abstract class AuthRepository {
  Future<DemoUser?> signUp({
    required String name,
    required String email,
    required String secretCode,
  });
  Future<DemoUser?> logIn({
    required String email,
    required String secretCode,
  });
  Future<void> logOut();
}

class MockAuthRepository implements AuthRepository {
  DemoUser? _currentUser;

  @override
  Future<DemoUser?> signUp({
    required String name,
    required String email,
    required String secretCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = DemoUser(name: name, email: email);
    return _currentUser;
  }

  @override
  Future<DemoUser?> logIn({
    required String email,
    required String secretCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Always succeed with seed user in demo
    _currentUser = const DemoUser(
      name: 'LeBron',
      email: 'lebron@example.com',
      heroIndex: 0,
      heroClassName: 'Speaker',
      level: 4,
      xp: 310,
      xpToNextLevel: 500,
      streak: 5,
      wordsFound: 24,
      lessonsCompleted: 1,
      languageId: 'newari',
      languageName: 'Newari',
      languageScript: 'नेपाल भाषा',
    );
    return _currentUser;
  }

  @override
  Future<void> logOut() async {
    _currentUser = null;
  }
}
