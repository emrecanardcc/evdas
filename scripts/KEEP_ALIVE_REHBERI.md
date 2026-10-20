# 💓 Supabase Uyku Modunu (Pause) Önleme Rehberi

Supabase ücretsiz (Free) katmanı, **7 gün boyunca hiçbir API isteği almayan** projeleri sunucu kaynaklarını tasarruf etmek amacıyla otomatik olarak **uyku moduna (inactivity pause)** alır. 

Evdaş projesinde bu durumu tamamen engellemek ve veritabanını 7/24/365 kesintisiz uyanık tutmak için **4 kademeli tam otomatik bir sistem** kurulmuştur:

---

## 1. Kademe: GitHub Actions Cron Görevi (Önerilen & Otomatik)
Proje GitHub reposuna yüklendiğinde `.github/workflows/supabase_keep_alive.yml` dosyası devreye girer.
- **Çalışma Aralığı:** Her 2 günde bir gece saat 04:00 UTC.
- **Maliyet:** %100 Ücretsiz (GitHub Actions public ve private repolarda ücretsiz dakikalar sunar).
- **Avantajı:** Hiçbir bilgisayarın veya telefonun açık kalmasına gerek yoktur; GitHub bulutu otomatik çalıştırır.
- **Manuel Test:** GitHub reposunda `Actions` sekmesine gidip `Supabase Database Keep-Alive` seçilerek "Run workflow" butonuna basılabilir.

---

## 2. Kademe: Mobil Uygulama İçi Canlılık Kalp Atışı (`HeartbeatService`)
`lib/core/services/heartbeat_service.dart` servisi Flutter mobil uygulamasına entegre edilmiştir.
- Kullanıcılar uygulamayı her açtığında veya ön plana aldığında, son ping üzerinden 12 saat geçmişse arka planda sessizce hafif bir ping (`select('id').limit(1)`) gönderilir.
- Kullanıcı arayüzünü (UI) asla bloklamaz veya bekletmez.

---

## 3. Kademe: cron-job.org veya UptimeRobot ile Harici Web Hook (1 Dakikalık Kurulum)
Eğer GitHub Actions dışında harici bir ping servisi de eklemek isterseniz:
1. [cron-job.org](https://cron-job.org) veya [uptimerobot.com](https://uptimerobot.com) adresine ücretsiz üye olun.
2. Yeni bir Cron Job (Monitor) oluşturun:
   - **URL:** `https://jsqzzikbwilltyfopfyk.supabase.co/rest/v1/partnerships?select=id&limit=1`
   - **Method:** `GET`
   - **Headers:**
     - `apikey`: `<Supabase Dashboard -> Project Settings -> API anon key>`
     - `Authorization`: `Bearer <Supabase Dashboard -> Project Settings -> API anon key>`
   - **Zamanlama:** Her 3 günde bir (veya her gün).
3. Kaydedin. Artık bu servis Supabase'i periyodik olarak uyandıracaktır.

---

## 4. Kademe: Supabase SQL İçi `pg_cron` (Veritabanı Seviyesi)
`supabase/keep_alive_cron.sql` dosyası içerisindeki SQL sorgusunu Supabase Dashboard'daki SQL Editor ekranında çalıştırarak PostgreSQL'in kendi dahili cron motoruyla her 3 günde bir uyanık kalmasını sağlayabilirsiniz.
