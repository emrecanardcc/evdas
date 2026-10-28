# EVDAS OTONOM PROJE VE SOHBET AKTARIM BELGESİ (CONVERSATION HANDOVER)

> Bu belge, Antigravity sohbet oturumunun sıfırdan, temiz ve yüksek performanslı yeni bir sohbete taşınması sırasında projenin **tüm hafızasını, mimari kurallarını, test hesaplarını, tamamlanan kilometre taşlarını ve sıradaki görevlerini** %100 eksiksiz aktarmak üzere oluşturulmuştur.

---

## 1. PROJE KİMLİĞİ VE TEMEL BİLGİLER

- **Proje Adı:** Evdaş (evdas_mobile)
- **Çalışma Dizini:** `c:\Projeler\evdas_mobile`
- **GitHub Deposu:** `https://github.com/emrecanardcc/evdas.git` (Ana dal: `main`)
- **Proje Türü:** Flutter (Dart), Supabase & Riverpod 3.x
- **Masaüstü Yönetici Aracı:** `EvdasManager.exe` (Masaüstünde `fikirler.md` ve `ozellikler.md` yönetimini sürükle-bırak ile sağlayan bağımsız panel).

---

## 2. TAVİZSİZ MİMARİ VE GELİŞTİRME STANDARTLARI

1. **SIFIR EMOJİ KURALI (STRICT ZERO-EMOJI):**
   - Arayüzde hiçbir buton, ikon, metin, sekme, modal veya bildirimde emoji (`🚀`, `💡`, `🔥`, `🎉` vb.) KULLANILAMAZ.
   - Tüm simgeler yüksek çözünürlüklü, modern vektörel `Icons.*` simgeleridir.
   - Bu kural `test/emoji_audit_test.dart` otomatik regresyon testi ile denetlenir.

2. **YERLEŞİK TEST VE DENETÇİ HESABI (REVIEWER ACCOUNT):**
   - **E-posta:** `test@evdas.app`
   - **Şifre:** `Evdas2026!`
   - Giriş ekranında (`auth_screen.dart`) tek tıkla form doldurma butonu bulunur. Supabase çevrimdışı olsa dahi yerleşik mock ortaklık ve harcama verisiyle tüm ekranlar anında test edilebilir.

3. **OTOMATİK TEST VE KALİTE ZORUNLULUĞU:**
   - Projede her özellik için kapsamlı birim ve widget testleri yazılmıştır.
   - Her evrim döngüsü tamamlandığında `flutter test` %100 başarılı olmak zorundadır (Şu an 317/317 test aktif ve %100 başarılıdır).

4. **HER ADIMDA GITHUB COMMIT & PUSH:**
   - Her evrim döngüsü veya görev tamamlandığında kod yerel depoya commit edilmeli ve KESİNLİKLE `git push origin main` ile GitHub uzak sunucusuna itilmelidir. Asla itilmemiş kod bırakılamaz.

5. **ERGONOMİ VE TAŞMA GÜVENCESİ:**
   - Tüm ekranlar 280x480'den 800x400'e kadar, 1.8x sistem yazı tipi ölçeğinde sıfır taşma (`A RenderFlex overflowed`) verecek şekilde tasarlanmıştır (`SingleChildScrollView`, responsive thumb zone 48px).

---

## 3. ÜRÜN FELSEFESİ VE ŞİŞKİNLİK AYIKLAMA (BLOAT REMOVAL)

Evdaş, ev arkadaşlarının (özellikle üniversite öğrencileri ve genç çalışanlar) aralarındaki para ve ev içi sorumlulukları dostluklarını zedelemeden, adaleti şeffafça sağlayarak çözmesi için vardır.
- **Kaldırılan / Gizlenen Şişkinlikler:** Karmaşık fiş OCR kamerası ve numpad üzerindeki gereksiz hesap makinesi işleçleri kaldırıldı. Kira gibi ayda 1 kez girilen kalemler günlük hızlı ekrandan temizlendi.
- **Özel Kategoriler:** Gerçek hayat frekansına uygun kategori sıralaması (Market, Mutfak, Temizlik, Fatura, Ulaşım, Diğer) ve kullanıcının kendi kategorilerini oluşturabilmesi sağlandı.
- **Ev Lisansı (Ortak Premium):** Bireysel abonelik yerine tek bir 'Ev Lisansı' (Aylık 300 TL). Alındığında 3 kişi arasında kişi başı 100 TL ortak harcama olarak bölünür.

---

## 4. DOSYA DÜZENİ VE YÖNETİM MATRİSİ

- `fikirler.md`: Fikir Havuzu (Backlog) ve 'Secilen Fikirler' bölümlerini içerir.
- `ozellikler.md`: Ücretsiz, Ev Premium ve Kaldırılacaklar (Bloat) özellik matrisini barındırır.
- `AUTONOMOUS_LOG.md`: Tamamlanan tüm evrim döngülerinin, mimari değişikliklerin ve test paketlerinin detaylı geçmişidir.
- `AUTONOMOUS_TRIGGER.flag`: Masaüstü yönetim panelinden veya kullanıcıdan yeni bir otonom döngü tetiklendiğini belirten bayrak dosyasıdır.

---

## 5. SIRADAKİ GÖREVLER (SECILEN FIKIRLER - DÖNGÜ 15)

`fikirler.md` dosyasında kullanıcı tarafından seçilen ve sıradaki döngüde koda dönüştürülecek maddeler:
1. **`[MINIMUM_TRANSFER_SETTLEMENT]`**: Ay sonunda 10 farklı ikili borcu netleştirip tüm evi en fazla 1 veya 2 kişi arasında tek EFT/FAST transferi ile sıfırlayan minimum cash flow graf optimizasyon algoritması.
2. **`[TEK_TIKLA_FAST_IBAN_KOPYALAMA]`**: Hesaplaşma ekranında kime borcun varsa onun banka IBAN'ını tek dokunuşla panoya kopyalama ve hazır banka açıklama şablonu üretme.

---

## 6. YENİ SOHBETTE BAŞLATMA KOMUTU (PROMPT)

Yeni açılacak temiz Antigravity sohbetinde ajana şu komut gönderildiğinde ajan bu dosyayı okuyarak projeyi kaldığı yerden tam güçle devam ettirecektir:

```
# GÖREV: OTONOM PROJE MÜKEMMELLEŞTİRME VE EVRİM MOTORU
CONVERSATION_HANDOVER.md, AUTONOMOUS_LOG.md, fikirler.md ve ozellikler.md dosyalarını oku. Projeyi sıfır emoji kuralı, hazır test hesabı (test@evdas.app / Evdas2026!), 317+ test güvencesi ve her adımda GitHub push kuralıyla kaldığı yerden evrimleştirmeye devam et.
```
