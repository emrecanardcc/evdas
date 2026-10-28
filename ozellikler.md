# EVDAS OZELLIK MATRISI, URUN FELSEFESI VE SISKINLIK AYIKLAMA PLANI

Bu dokuman, Evdas uygulamasinin gercek varlik amacini, kullanici profilini, aktif/planlanan ozelliklerini ve gereksiz yapay zeka siskinliklerinin ayiklanma takvimini tanimlar.
Masaustu yonetim paneli (EvdasManager.exe) uzerinden ozellikler 'Ucretsiz', 'Ev Premium' ve 'Kaldirilacaklar' arasinda suruklenip yonetilebilir.

---

## 1. Urun Vizyonu, Hedef Profil ve 30 Gunluk Yasam Dongusu

### A. Projenin Varlik Amaci
Evdas, ev arkadaslarinin (ozellikle universite ogrencileri ve genc calisanlar) aralarindaki para ve ev ici sorumluluk gerilimlerini sifirlamak amaciyla tasarlanmis minimalist bir ortak yasam asistanidir.
Uygulamanin tek bir varlik amaci vardir:
'Kimin kime ne kadar borcu oldugunu, bu ay kimin ne harcadigini ve evin gunluk islerini 3 saniye icinde, hicbir tartismaya yer birakmadan seffafca cozmek.'

### B. Gercek Kullanici Profili (Kadikoy 3+1 Ornek Daire)
- **Can (22, Bilgisayar Muhendisligi Ogrencisi):** Evin kirasini ve internet faturasini uzerine alan, teknolojiyi seven ama gereksiz adimlarla ugrasmak istemeyen kisi.
- **Ece (21, Ic Mimarlik Ogrencisi):** Mutfak eksiklerini, damacana suyu ve temizlik malzemelerini sik sik alan, harcamalarinin gozden kacmasini istemeyen kisi.
- **Arda (23, Jr. Yazilim Gelistirici):** Genellikle evde calisan, yemek siparislerini ortak veren, borcunu ay sonunda tek transferle kapatmak isteyen kisi.

### C. 30 Gunluk Gercek Ev Yasam Similasyonu
1. **Gun 1 (Kira & Aidat Gunu):** Can ev sahibine 30.000 TL kirayi ve yonetime 1.500 TL aidati gonderir. Bu harcama gunluk ekranda buton aramak yerine 'Otomatik Talimat' ile 3 kisi arasinda kisi basi 10.500 TL borc olarak aninda paylasilir.
2. **Gun 3 (Damacana Su Biter):** Ece kapidan 90 TL'ye damacana su alir. Uygulamayi acar, 'Damacana Su' butonuna basar ve 2 saniyede kaydeder.
3. **Gun 7 (Haftalik Temizlik & Market):** Can BİM'den 450 TL'lik camasir deterjani, bulasik tableti ve tuvalet kagidi alir. 'Temizlik & Hijyen' kategorisiyle esit boler.
4. **Gun 9 (Bulasik Tartismasi):** Mutfaktaki yigilan bulasiklar icin 'Karar Carki' cevrilir; gorev Arda'ya cikar. Tartisma kapanir.
5. **Gun 14 (Ortak Aksam Yemegi):** 3 kisi beraber 750 TL'lik pizza siparis eder. Arda oder, 3'e esit bolunur.
6. **Gun 18 (Mac Gecesi - 2 Kisi):** Can ve Arda icecek ve atistirmalik alir (300 TL). Ece okulda oldugu icin harcama sadece Can ve Arda arasinda bolunur.
7. **Gun 22 (Elektrik & Dogalgaz Faturalari Gelir):** Fatura bildirimleri gelir, sisteme fatura olarak islenir.
8. **Gun 30 (Ay Sonu Hesaplasmasi):** 15 ayri ikili odeme yerine sistem tek bir net bakiye ozeti cikarir: 'Arda, Can'a 1.250 TL; Ece, Can'a 800 TL atarsa butun ev sifirlanir.' Tek tıkla IBAN kopyalanir ve FAST ile hesaplar denklenir.

---

## 2. Kaldirilacaklar / Gereksiz Siskinlikler (Bloat Trimming)

Kullanici deneyimini karmasiklastiran, yapay zeka gosterisi olan ve gercek hayatta kullanilmayan gereksiz ozellikler:

- **[KALDIRILDI_FIS_FOTOGRAF_OCR]**: Karmasik kamera OCR ve fis ayristirici. Hizli harcama giris ekranindan tamamen temizlendi; kullanici bilissel yuku sifirlandi.
- **[KALDIRILDI_HESAP_MAKINASI_SERIDI]**: Hizli giris numpad'indeki gereksiz formul islecleri (+, -, x, /) temizlendi; tek odak aninda tutar yazip kaydetmeye cevrildi.
- **[KALDIRILDI_HIZLI_BUTONDA_KIRA]**: Hizli harcama secicisinden ayda bir odenen kira butonu kaldirildi; Sabit Giderler ve Otomatik Talimatlara delege edildi.
- **[KALDIRILACAK_ASIRI_FINANSAL_GRAFIKLER]**: Borsa tarzi agir grafikler ve asiri burn-rate tahminleri yerine yalnizca net kisi basi harcama kartlari.

---

## 3. Aktif Ozellikler - Ucretsiz (Free Tier)

- **[HIZLI_HARCAMA_GIRISI]**: 3 saniyede baslik, tutar ve kategori secerek harcama kaydetme.
- **[GERCEKCI_KATEGORI_LISTESI]**: Gercek hayat sikligina gore siralanmis ana kategoriler (Market, Mutfak, Temizlik, Fatura, Ulasim, Diger).
- **[OZELLESTIRILEBILIR_KATEGORILER]**: Kullanicinin kendi evine ozel kategori ekleyebilmesi (Damacana Su, Kedi Mamasi, Eglence), vektor ikon ve renk secebilmesi.
- **[ESIT_VEYA_KISI_SECIMLI_BOLUSUM]**: Tum eve esit veya o harcamaya katilan secili kisiler arasinda bolme.
- **[TEMEL_HESAPLASMA_MOTORU]**: Kimin kime borclu oldugunu gosteren ve odesme kaydi olusturan temel mutabakat.
- **[GOREV_VE_TEMIZLIK_CARKI]**: Ev ici anlasmazliklari ve gorevleri sansa birakan sifir-emoji vektor karar carki.
- **[YEREL_CEVRIMDISI_DESTEK]**: Internet kesilse bile yerel hafizada harcama kaydedebilme ve senkronizasyon.
- **[TEST_HESABI_VE_KOLAY_GIRIS]**: Apple App Store ve Google Play inceleme uyumlu hazir test hesabi (test@evdas.app / Evdas2026!).

---

## 4. Aktif Ozellikler - Ev Premium (Household Pro Tier)

- **[EV_ORTAK_PREMIUM_MODELI]**: Bireysel abonelik yerine butun eve aylik 300 TL (kisi basi yalnizca 100 TL/ay). Alindiginda 3 kisilik ev bilancosuna kisi basi 100 TL ortak harcama olarak islenir.
- **[OTOMATIK_TALIMATLAR_RECURRING]**: Kira, aidat, internet ve haftalik damacana suyu otomatik vade tarihinde sisteme isleyen ve ev arkadaslarina pay bildirimi gonderen akilli motor (1 aylik deneme sonrasi Pro katman).
- **[MINIMUM_TRANSFER_OPTIMIZASYONU]**: Coklu borclari birlestirip tum evi en az sayida banka transferine indirgeyen borc sadelestirme algoritmasi.
- **[TEK_TIKLA_IBAN_KOPYALAMA]**: Hesaplasma aninda alacaklinin IBAN'ini tek dokunusla panoya kopyalama ve aciklama sablonu uretme.
- **[DETAYLI_EXCEL_VE_RAPOR_DISA_AKTARIM]**: Ev butcesini aylik CSV/Excel veya PDF olarak disa aktarabilme.

---

## 5. Yol Haritasi ve Evrim Fazlari (Roadmap)

### Faz 1: Sadeleştirme ve Siskinlik Temizligi (Anlik)
- Fiş OCR ve ayri hesap makinasi kalintilarini arayuzden gizleme / kaldirma.
- Kategori hiyerarsisini gercek hayat frekansina gore duzenleme (Kira butonunu gunluk alandan kaldirma).
- Masaustu EvdasManager.exe ile fikirler ve ozellikler yonetimini saglama.

### Faz 2: Ev Bazli Ortak Premium & Otomatik Talimatlar
- Ev lisansi modelini subscription_service'e entegre etme (300 TL/ay -> 3 kisilik evde kisi basi 100 TL ortak harcama).
- 1 aylik ucretsiz kullanim sonrasi otomatik talimatlar ve gelismis odesme ozellikleri ile donusum artirma.
- Ozel kategori olusturma arayuzu.

### Faz 3: Gelismis Borc Sadelesmesi ve Ev Devir Sihirbazi
- Minimum banka transferi algoritmasi.
- Evden ayrilan arkadas icin gecmis borc ve depozito mutabakat sihirbazi.
- FAST entegrasyonu ve dekont yukleme dogrulamasi.
