import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

/// 💓 Supabase Otomatik Canlı Tutma & Heartbeat Servisi
///
/// Supabase ücretsiz katmanı 7 gün boyunca API isteği almazsa veritabanını uyku moduna alır.
/// Bu servis, uygulama açıldığında ve periyodik aralıklarla veritabanına hafif bir istek atarak
/// veritabanının daima aktif ve uyanık kalmasını garanti eder.
class HeartbeatService {
  static const String _keyLastPing = 'supabase_last_heartbeat_ping';
  static const Duration _minInterval = Duration(hours: 12); // Günde en fazla 2 kez ping atar

  /// Arka planda hafif ping isteği gönderir (UI'yi asla bekletmez veya bloklamaz)
  static Future<bool> pingIfNeeded() async {
    try {
      final client = SupabaseService.client;
      if (client == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final lastPingMillis = prefs.getInt(_keyLastPing) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Son ping üzerinden 12 saat geçmemişse tekrar gönderme (kotayı ve pili korur)
      if (now - lastPingMillis < _minInterval.inMilliseconds) {
        return false;
      }

      // Veritabanını uyanık tutmak için en hafif sorgu: 1 satırlık ID okuma
      await client.from('partnerships').select('id').limit(1);

      // Başarılı ping zamanını kaydet
      await prefs.setInt(_keyLastPing, now);
      if (kDebugMode) {
        debugPrint('💓 [Supabase Heartbeat] Veritabanı uyanık tutma pingi başarıyla iletildi.');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [Supabase Heartbeat] Ping iletimi atlandı: $e');
      }
      return false;
    }
  }

  /// Doğrudan anlık zorunlu ping gönderir
  static Future<bool> forcePing() async {
    try {
      final client = SupabaseService.client;
      if (client == null) return false;
      await client.from('partnerships').select('id').limit(1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastPing, DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (_) {
      return false;
    }
  }
}
