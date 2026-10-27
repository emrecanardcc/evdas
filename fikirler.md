# EVDAS FIKIR HAVUZU VE SECILEN GELISTIRMELER YONETIM PLANI

Bu dokuman, Evdas urununun gercek hayat ihtiyaclarina gore evrimlesmesini saglayan dinamik fikir bankasidir.
Kullanici masaustu yonetim paneli (EvdasManager.exe) uzerinden veya bu dosyayi dogrudan duzenleyerek fikirleri 'Fikir Havuzu' ile 'Secilen Fikirler' arasinda tasiyabilir.
Agent/Gelistirici her evrim dongusunde oncelikle 'Secilen Fikirler' bolumundeki maddeleri koda donusturur.

---

## 1. Fikir Havuzu (Backlog)

- **[DAMACANA_SU_HIZLI_BUTON]**: Kapida nakit veya kartla odenen 19L damacana su siparisleri icin ana ekranda 1 tıkla son siparis tutarini (orn. 90 TL) harcamaya ekleme kisayolu.
- **[AKILLI_ALISVERIS_LISTESI]**: Evdekilerin 'evde tuz bitti', 'deterjan alinacak' gibi ortak eksikleri tek listede topladigi ve markete gidenin aldiklarini tek tikla harcamaya donusturdugu entegre liste.
- **[EVCIL_HAYVAN_MAMAVEKUM_HAVUZU]**: Evde kedi/kopek bakan ortaklar icin mama, veteriner ve kum masraflarini genel ev bütçesinden izole eden ozel alt kategori kurali.
- **[MINIMUM_TRANSFER_SETTLEMENT]**: Ay sonunda 10 farkli ikili borc yerine, borclari netlestirip tum evi en fazla 1 veya 2 kisi arasinda tek EFT/FAST transferi ile sifirlayan algoritma.
- **[KIRA_VE_AIDAT_TALIMAT_UYARISI]**: Ayin 1'inde ev sahibine ve site yonetimine gidecek kira/aidat icin sorumlu kisiye hatirlatma ve ev arkadaslarina kisi basi pay bildirimi.
- **[TEK_TIKLA_FAST_IBAN_KOPYALAMA]**: Hesaplasma ekraninda kime borcun varsa onun banka IBAN'ini tek tusla kopyalama ve banka uygulamasina gonderim kolayligi.
- **[MISAFIR_VE_ETKINLIK_AYRACISI]**: Evde parti veya ortak mac gecesi yapildiginda, harcamayi sadece o gece katilanlar arasinda esit bolme; sehir disinda olan arkadasi muaf tutma.
- **[EV_DEVRIN_DEPOZITO_HESAPLAYICI]**: Evden ayrilan veya yeni tasinan arkadasin depozito, gecmis borc ve kalan fatura paylarini tek ekranda netlestiren devir sihirbazi.
- **[ORTAK_KUMBARA_KASA_MODULU]**: Her ay basinda kisi basi ornegin 500 TL ortak kasaya nakit/havale atilmasi ve gunluk kucuk harcamalarin bu kasadan dusulmesi.
- **[EV_KURALLARI_VE_ACIL_PANOSU]**: Wi-Fi sifresi, kombi basinci, acil durum anahtari ve ev sahibi iletisim bilgilerini iceren sabit bilgi koku.

---

## 2. Secilen Fikirler (Gelistirilecekler)

- **[SECILEN_01_GERCEKCI_KATEGORI_REFAKTORU]**: Gunluk hizli harcamalardan ayda 1 kez yapilan 'Kira' butonunun kaldirilmasi; yerine gercek hayat siklik siralamasi: Market, Damacana Su, Temizlik, Ortak Yemek, İcecek & Eglence, Faturalar.
- **[SECILEN_02_EV_BAZLI_ORTAK_PREMIUM]**: Bireysel abonelik yerine tek bir 'Ev Lisansi' (300 TL/ay). Alindiginda otomatik olarak 3 kisi arasinda 100 TL kisi basi ortak harcama olarak bolusturulur.
- **[SECILEN_03_OTOMATIK_TALIMATLAR_PRO_GATING]**: Kira, aidat, internet gibi sabit harcamalarin 'Otomatik Talimat' olarak kurulmasi; 1 aylik ucretsiz kullanim sonrasi pro katmana gecis tetikleyicisi yapilmasi.

---

## 3. Fikir Degerlendirme ve Secim Rehberi

1. Bir fikrin 'Secilen Fikirler' bolumune alinmasi, sonraki gelistirme dongusunde oncelikli olarak kodlanacagi anlamina gelir.
2. Ev arkadaslari arasinda iletisim gerilimini azaltan, 3 saniyeden kisa surede cozum saglayan fikirler en yuksek oncelige sahiptir.
3. Karmasiklestiren veya yapay zeka gosterisi olan fikirler havuza dahi alinmamali, dogrudan 'ozellikler.md -> Kaldirilacaklar' listesine gonderilmelidir.
