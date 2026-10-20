-- ==============================================================================
-- 💓 SUPABASE VERİTABANI UYKU MODU ÖNLEYİCİ ZAMANLANMIŞ GÖREV (pg_cron)
-- ==============================================================================
-- Supabase ücretsiz katmanı 7 gün API isteği almayan projeleri otomatik uykuya alır.
-- Bu SQL betiği, veritabanının kendi içinde zamanlanmış bir cron görevi çalıştırarak
-- her 3 günde bir canlılık tablosunu günceller ve veritabanını daima uyanık tutar.
-- 
-- Kurulum Adımları:
-- 1. Supabase Dashboard -> Database -> Extensions kısmından "pg_cron" uzantısını etkinleştirin.
-- 2. Supabase Dashboard -> SQL Editor alanına bu kodu yapıştırıp "Run" butonuna basın.
-- ==============================================================================

-- 1. pg_cron uzantısını aktif et
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Canlılık takip tablosu oluştur
CREATE TABLE IF NOT EXISTS public._system_heartbeat (
    id INT PRIMARY KEY DEFAULT 1,
    ping_count BIGINT DEFAULT 1,
    last_ping TIMESTAMPTZ DEFAULT NOW(),
    source TEXT DEFAULT 'pg_cron_internal'
);

-- Başlangıç kaydını ekle
INSERT INTO public._system_heartbeat (id, ping_count, last_ping, source)
VALUES (1, 1, NOW(), 'initial_setup')
ON CONFLICT (id) DO NOTHING;

-- 3. Eski bir keep-alive görevi varsa temizle
DO $$
BEGIN
    PERFORM cron.unschedule('supabase_keep_alive_job');
EXCEPTION WHEN OTHERS THEN
    -- Görev henüz yoksa hata vermez
END $$;

-- 4. Her 3 günde bir gece saat 03:00'te tabloyu güncelleyen görevi kaydet
SELECT cron.schedule(
    'supabase_keep_alive_job',
    '0 3 */3 * *',
    $$
    UPDATE public._system_heartbeat 
    SET ping_count = ping_count + 1,
        last_ping = NOW(),
        source = 'pg_cron_automated'
    WHERE id = 1;
    $$
);

-- Kontrol sorgusu (Aktif cron görevlerini listeler):
SELECT jobid, schedule, command, nodename, nodeport, database, username, active 
FROM cron.job 
WHERE jobname = 'supabase_keep_alive_job';
