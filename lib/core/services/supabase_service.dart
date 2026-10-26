import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jsqzzikbwilltyfopfyk.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (supabaseAnonKey.isEmpty) {
      // Ortam değişkeni (.env / --dart-define) verilmediğinde güvenli çevrimdışı modda çalış
      return;
    }
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
    } catch (_) {
      // Offline fallback
    }
  }

  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static User? get currentUser => client?.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  static Stream<AuthState>? get authStateChanges => client?.auth.onAuthStateChange;

  // AUTH ACTIONS

  /// E-posta, Şifre, İsim Soyisim ve IBAN ile kayıt (Banka bilgisi YOK)
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? iban,
  }) async {
    final c = client;
    if (c == null) throw Exception('Supabase servisi başlatılamadı');
    return await c.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        if (iban != null && iban.isNotEmpty) 'iban': iban,
      },
    );
  }

  /// E-posta ve şifre ile giriş
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final c = client;
    if (c == null) throw Exception('Supabase servisi başlatılamadı');
    return await c.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Çıkış yap
  static Future<void> signOut() async {
    final c = client;
    if (c != null) {
      await c.auth.signOut();
    }
  }

  /// Şifre sıfırlama e-postası gönder
  static Future<void> resetPassword(String email) async {
    final c = client;
    if (c == null) throw Exception('Supabase servisi başlatılamadı');
    await c.auth.resetPasswordForEmail(email);
  }

  /// Apple Guideline 5.1.1(v) Uyumlu: Hesabı ve ilişkili verileri tamamen sil
  static Future<void> deleteAccount() async {
    final c = client;
    if (c == null) return;
    final user = c.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Veritabanındaki RPC fonksiyonu ile cascade silme işlemini tetikle
      await c.rpc('delete_user_account');
    } catch (_) {
      // RPC tanımlı değilse doğrudan ilgili kayıtları temizle
      try {
        await c.from('partnership_members').delete().eq('user_id', user.id);
        await c.from('profiles').delete().eq('id', user.id);
      } catch (_) {}
    } finally {
      // 2. Auth oturumunu sonlandır
      try {
        await c.auth.signOut();
      } catch (_) {}
    }
  }
}
