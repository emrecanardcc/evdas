# Evdaş - Ortak Masraf Paylaşım & Borç Mahsuplaşma Asistanı

Ev arkadaşları, ofis ortakları, seyahat ve proje grupları arasındaki ortak harcamaları ve şahsi borçları şeffafça yöneten; **uygulamayı açar açmaz 3 saniyede harcama girilmesini sağlayan** yüksek performanslı mobil uygulama.

---

## ⚡ Temel Özellikler

1. **3 Saniyede Hızlı Masraf Girişi:** Form doldurma zahmeti yok. Uygulama açıldığı anda tam ekran sayısal tuş takımı ve tutar alanı hazırdır. Tutarı girin, türü seçin (Ortak / Şahsi), kaydedin ve kapatın.
2. **Ortak Masraf vs. Şahsi Borç ("Şu Şuna") Ayrımı:**
   - **Ortak Grup Masrafı:** Market, fatura, kira gibi genel harcamalar tüm ortaklara eşit olarak bölünür.
   - **Şahsi Borç:** Kişiler arasındaki doğrudan 1'e 1 borçlar havuza girmeden net bakiye üzerinden dengelenir.
3. **Çift Taraflı Karşılıklı Onay:** Borç ödemeleri bildirildiğinde karşı tarafın onayına sunulur. Yalnızca alacaklı onayladığında borç bakiyesinden düşülür.
4. **Minimum Transfer (Debt Simplification):** Ay sonunda grup üyelerinin birbirine çoklu transfer yapmasına gerek kalmaz; algoritma borçları sadeleştirerek minimum sayıda net transfer üretir.
5. **Kriptolojik Güvenli Davet Sistemi:** Kurcalamaya dayanıklı ve doğrulanabilir davet kodları ile en fazla 6 ortaklı gruplar kurulabilir.
6. **Apple Guideline 5.1.1(v) & KVKK / GDPR Uyumlu:** Kullanıcılar uygulama içerisinden hesaplarını ve tüm kişisel verilerini tek tıkla kalıcı olarak silebilir. Hassas bankacılık şifreleri veya kart bilgileri asla talep edilmez.
7. **Offline-First / Kesintisiz Deneyim:** İnternet bağlantısı olmasa dahi tüm işlemler anında yerel belleğe işlenir (0ms UI gecikmesi), bağlantı sağlandığında arka planda Supabase bulutu ile eşitlenir.

---

## 🏗️ Mimari ve Teknolojiler

- **Mobil Çatı:** Flutter 3.47+ / Dart 3.13+ (Android & iOS)
- **Durum Yönetimi:** Flutter Riverpod 3.x (`Notifier` & `NotifierProvider`)
- **Bulut & Veritabanı:** Supabase (PostgreSQL 15+, Satır Düzeyi Güvenlik - RLS, RPC Stored Procedures)
- **Yerel Depolama:** SharedPreferences L1 In-Memory Cache (Offline-First)
- **Hukuk & Uyum:** KVKK Aydınlatma Metni & EULA Sözleşme Modalı
- **Destek Sistemi:** Doğrudan geliştirici iletişim altyapısı (`emrecanardc.dev@gmail.com`)

---

## 🗄️ Supabase PostgreSQL Kurulumu

Proje içerisindeki `supabase/production_schema.sql` dosyasını Supabase Dashboard **SQL Editor** ekranında çalıştırarak gerekli tüm tabloları, RLS güvenlik politikalarını, maksimum 6 üye kontrol tetikleyicisini ve hesap silme RPC fonksiyonunu oluşturabilirsiniz:

1. `profiles`: Kullanıcı kimlik ve isteğe bağlı IBAN bilgileri.
2. `partnerships`: Ortaklıklar, türleri ve güvenli davet kodları.
3. `partnership_members`: Ortaklık üyeleri ve rolleri (Maksimum 6 ortak kuralı).
4. `expenses`: Harcamalar ve şahsi borç kayıtları.
5. `payment_requests`: Çift taraflı onay bekleyen kısmi/tam ödeme talepleri.
6. `settlements`: Dönemsel hesap kapatma ve mahsuplaşma geçmişi.
7. `delete_user_account`: Apple 5.1.1(v) uyumlu cascade veri tasfiyesi fonksiyonu.

---

## 🚀 Test ve Doğrulama

Tüm iş kurallarını, algoritmaları ve arayüz testlerini çalıştırmak için:

```bash
cd c:\Projeler\evdas_mobile
flutter test
```

Statik kod analizi için:

```bash
flutter analyze
```

Uygulamayı geliştirme ortamında başlatmak için:

```bash
flutter run
```

---

## 📱 Mağazaya Yayınlama (Release)

### Android (Google Play Store):
```bash
flutter build appbundle --release
```

### iOS (Apple App Store):
```bash
flutter build ipa --release
```
