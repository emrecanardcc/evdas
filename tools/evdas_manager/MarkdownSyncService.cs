using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace EvdasManager
{
    public class MarkdownSyncService
    {
        public string ProjectPath { get; private set; }
        public string FikirlerPath => Path.Combine(ProjectPath, "fikirler.md");
        public string OzelliklerPath => Path.Combine(ProjectPath, "ozellikler.md");
        public string TriggerFlagPath => Path.Combine(ProjectPath, "AUTONOMOUS_TRIGGER.flag");

        public ObservableCollection<ItemModel> FikirHavuzu { get; } = new();
        public ObservableCollection<ItemModel> SecilenFikirler { get; } = new();
        public ObservableCollection<ItemModel> AktifUcretsiz { get; } = new();
        public ObservableCollection<ItemModel> AktifPro { get; } = new();
        public ObservableCollection<ItemModel> Kaldirilacaklar { get; } = new();

        public MarkdownSyncService()
        {
            // Proje dizinini tespit et
            if (Directory.Exists(@"C:\Projeler\evdas_mobile"))
            {
                ProjectPath = @"C:\Projeler\evdas_mobile";
            }
            else
            {
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                string candidate = Path.GetFullPath(Path.Combine(baseDir, @"..\..\..\.."));
                if (File.Exists(Path.Combine(candidate, "pubspec.yaml")))
                {
                    ProjectPath = candidate;
                }
                else
                {
                    ProjectPath = Directory.GetCurrentDirectory();
                }
            }
        }

        public void SetProjectPath(string path)
        {
            if (Directory.Exists(path))
            {
                ProjectPath = path;
                LoadAll();
            }
        }

        public void LoadAll()
        {
            LoadFikirler();
            LoadOzellikler();
        }

        public void LoadFikirler()
        {
            FikirHavuzu.Clear();
            SecilenFikirler.Clear();

            if (!File.Exists(FikirlerPath)) return;

            string[] lines = File.ReadAllLines(FikirlerPath, Encoding.UTF8);
            int currentSection = 0; // 1: Havuz, 2: Secilenler

            foreach (string rawLine in lines)
            {
                string line = rawLine.Trim();
                string norm = NormalizeTurkish(line);
                if (norm.StartsWith("## 1.", StringComparison.OrdinalIgnoreCase))
                {
                    currentSection = 1;
                    continue;
                }
                if (norm.StartsWith("## 2.", StringComparison.OrdinalIgnoreCase))
                {
                    currentSection = 2;
                    continue;
                }
                if (norm.StartsWith("## 3.", StringComparison.OrdinalIgnoreCase))
                {
                    currentSection = 0;
                    continue;
                }

                if (line.StartsWith("-") && currentSection > 0)
                {
                    var item = ParseItem(line);
                    if (item != null)
                    {
                        if (currentSection == 1) FikirHavuzu.Add(item);
                        else if (currentSection == 2) SecilenFikirler.Add(item);
                    }
                }
            }
        }

        public void LoadOzellikler()
        {
            AktifUcretsiz.Clear();
            AktifPro.Clear();
            Kaldirilacaklar.Clear();

            if (!File.Exists(OzelliklerPath)) return;

            string[] lines = File.ReadAllLines(OzelliklerPath, Encoding.UTF8);
            int currentSection = 0; // 2: Kaldirilacaklar, 3: Ucretsiz, 4: Pro

            foreach (string rawLine in lines)
            {
                string line = rawLine.Trim();
                string norm = NormalizeTurkish(line);
                if (norm.StartsWith("## 2.", StringComparison.OrdinalIgnoreCase))
                {
                    currentSection = 2;
                    continue;
                }
                if (norm.StartsWith("## 3.", StringComparison.OrdinalIgnoreCase))
                {
                    currentSection = 3;
                    continue;
                }
                if (norm.StartsWith("## 4.", StringComparison.OrdinalIgnoreCase))
                {
                    currentSection = 4;
                    continue;
                }
                if (norm.StartsWith("## 5.", StringComparison.OrdinalIgnoreCase))
                {
                    currentSection = 0;
                    continue;
                }

                if (line.StartsWith("-") && currentSection > 0)
                {
                    var item = ParseItem(line);
                    if (item != null)
                    {
                        if (currentSection == 2) Kaldirilacaklar.Add(item);
                        else if (currentSection == 3) AktifUcretsiz.Add(item);
                        else if (currentSection == 4) AktifPro.Add(item);
                    }
                }
            }
        }

        private static string NormalizeTurkish(string text)
        {
            return text
                .Replace('İ', 'I')
                .Replace('ı', 'i')
                .Replace('ş', 's')
                .Replace('Ş', 'S')
                .Replace('ğ', 'g')
                .Replace('Ğ', 'G')
                .Replace('ü', 'u')
                .Replace('Ü', 'U')
                .Replace('ö', 'o')
                .Replace('Ö', 'O')
                .Replace('ç', 'c')
                .Replace('Ç', 'C');
        }

        private static ItemModel? ParseItem(string line)
        {
            // Format 1: - **[TAG]**: Aciklama  veya  - **TAG**: Aciklama
            var match = Regex.Match(line, @"^-\s*\*\*\[?([^\]\*\:]+)\]?\*\*:\s*(.*)$");
            if (match.Success)
            {
                return new ItemModel
                {
                    Tag = match.Groups[1].Value.Trim(),
                    Description = match.Groups[2].Value.Trim()
                };
            }

            // Format 2: - [TAG]: Aciklama
            var matchSimple = Regex.Match(line, @"^-\s*\[([^\]]+)\]:\s*(.*)$");
            if (matchSimple.Success)
            {
                return new ItemModel
                {
                    Tag = matchSimple.Groups[1].Value.Trim(),
                    Description = matchSimple.Groups[2].Value.Trim()
                };
            }

            // Format 3: - TAG: Aciklama
            var matchColon = Regex.Match(line, @"^-\s*([^:]+):\s*(.*)$");
            if (matchColon.Success)
            {
                return new ItemModel
                {
                    Tag = matchColon.Groups[1].Value.Trim().Trim('[', ']', '*'),
                    Description = matchColon.Groups[2].Value.Trim()
                };
            }

            return null;
        }

        public void SaveFikirler()
        {
            var sb = new StringBuilder();
            sb.AppendLine("# EVDAS FIKIR HAVUZU VE SECILEN GELISTIRMELER YONETIM PLANI");
            sb.AppendLine();
            sb.AppendLine("Bu dokuman, Evdas urununun gercek hayat ihtiyaclarina gore evrimlesmesini saglayan dinamik fikir bankasidir.");
            sb.AppendLine("Kullanici masaustu yonetim paneli (EvdasManager.exe) uzerinden veya bu dosyayi dogrudan duzenleyerek fikirleri 'Fikir Havuzu' ile 'Secilen Fikirler' arasinda tasiyabilir.");
            sb.AppendLine("Agent/Gelistirici her evrim dongusunde oncelikle 'Secilen Fikirler' bolumundeki maddeleri koda donusturur.");
            sb.AppendLine();
            sb.AppendLine("---");
            sb.AppendLine();
            sb.AppendLine("## 1. Fikir Havuzu (Backlog)");
            sb.AppendLine();
            foreach (var item in FikirHavuzu)
            {
                sb.AppendLine($"- **[{item.Tag}]**: {item.Description}");
            }
            sb.AppendLine();
            sb.AppendLine("---");
            sb.AppendLine();
            sb.AppendLine("## 2. Secilen Fikirler (Gelistirilecekler)");
            sb.AppendLine();
            foreach (var item in SecilenFikirler)
            {
                sb.AppendLine($"- **[{item.Tag}]**: {item.Description}");
            }
            sb.AppendLine();
            sb.AppendLine("---");
            sb.AppendLine();
            sb.AppendLine("## 3. Fikir Degerlendirme ve Secim Rehberi");
            sb.AppendLine();
            sb.AppendLine("1. Bir fikrin 'Secilen Fikirler' bolumune alinmasi, sonraki gelistirme dongusunde oncelikli olarak kodlanacagi anlamina gelir.");
            sb.AppendLine("2. Ev arkadaslari arasinda iletisim gerilimini azaltan, 3 saniyeden kisa surede cozum saglayan fikirler en yuksek oncelige sahiptir.");
            sb.AppendLine("3. Karmasiklestiren veya yapay zeka gosterisi olan fikirler havuza dahi alinmamali, dogrudan 'ozellikler.md -> Kaldirilacaklar' listesine gonderilmelidir.");

            File.WriteAllText(FikirlerPath, sb.ToString(), Encoding.UTF8);
        }

        public void SaveOzellikler()
        {
            var sb = new StringBuilder();
            sb.AppendLine("# EVDAS OZELLIK MATRISI, URUN FELSEFESI VE SISKINLIK AYIKLAMA PLANI");
            sb.AppendLine();
            sb.AppendLine("Bu dokuman, Evdas uygulamasinin gercek varlik amacini, kullanici profilini, aktif/planlanan ozelliklerini ve gereksiz yapay zeka siskinliklerinin ayiklanma takvimini tanimlar.");
            sb.AppendLine("Masaustu yonetim paneli (EvdasManager.exe) uzerinden ozellikler 'Ucretsiz', 'Ev Premium' ve 'Kaldirilacaklar' arasinda suruklenip yonetilebilir.");
            sb.AppendLine();
            sb.AppendLine("---");
            sb.AppendLine();
            sb.AppendLine("## 1. Urun Vizyonu, Hedef Profil ve 30 Gunluk Yasam Dongusu");
            sb.AppendLine();
            sb.AppendLine("### A. Projenin Varlik Amaci");
            sb.AppendLine("Evdas, ev arkadaslarinin (ozellikle universite ogrencileri ve genc calisanlar) aralarindaki para ve ev ici sorumluluk gerilimlerini sifirlamak amaciyla tasarlanmis minimalist bir ortak yasam asistanidir.");
            sb.AppendLine("Uygulamanin tek bir varlik amaci vardir:");
            sb.AppendLine("'Kimin kime ne kadar borcu oldugunu, bu ay kimin ne harcadigini ve evin gunluk islerini 3 saniye icinde, hicbir tartismaya yer birakmadan seffafca cozmek.'");
            sb.AppendLine();
            sb.AppendLine("### B. Gercek Kullanici Profili (Kadikoy 3+1 Ornek Daire)");
            sb.AppendLine("- **Can (22, Bilgisayar Muhendisligi Ogrencisi):** Evin kirasini ve internet faturasini uzerine alan, teknolojiyi seven ama gereksiz adimlarla ugrasmak istemeyen kisi.");
            sb.AppendLine("- **Ece (21, Ic Mimarlik Ogrencisi):** Mutfak eksiklerini, damacana suyu ve temizlik malzemelerini sik sik alan, harcamalarinin gozden kacmasini istemeyen kisi.");
            sb.AppendLine("- **Arda (23, Jr. Yazilim Gelistirici):** Genellikle evde calisan, yemek siparislerini ortak veren, borcunu ay sonunda tek transferle kapatmak isteyen kisi.");
            sb.AppendLine();
            sb.AppendLine("### C. 30 Gunluk Gercek Ev Yasam Similasyonu");
            sb.AppendLine("1. **Gun 1 (Kira & Aidat Gunu):** Can ev sahibine 30.000 TL kirayi ve yonetime 1.500 TL aidati gonderir. Bu harcama gunluk ekranda buton aramak yerine 'Otomatik Talimat' ile 3 kisi arasinda kisi basi 10.500 TL borc olarak aninda paylasilir.");
            sb.AppendLine("2. **Gun 3 (Damacana Su Biter):** Ece kapidan 90 TL'ye damacana su alir. Uygulamayi acar, 'Damacana Su' butonuna basar ve 2 saniyede kaydeder.");
            sb.AppendLine("3. **Gun 7 (Haftalik Temizlik & Market):** Can BİM'den 450 TL'lik camasir deterjani, bulasik tableti ve tuvalet kagidi alir. 'Temizlik & Hijyen' kategorisiyle esit boler.");
            sb.AppendLine("4. **Gun 9 (Bulasik Tartismasi):** Mutfaktaki yigilan bulasiklar icin 'Karar Carki' cevrilir; gorev Arda'ya cikar. Tartisma kapanir.");
            sb.AppendLine("5. **Gun 14 (Ortak Aksam Yemegi):** 3 kisi beraber 750 TL'lik pizza siparis eder. Arda oder, 3'e esit bolunur.");
            sb.AppendLine("6. **Gun 18 (Mac Gecesi - 2 Kisi):** Can ve Arda icecek ve atistirmalik alir (300 TL). Ece okulda oldugu icin harcama sadece Can ve Arda arasinda bolunur.");
            sb.AppendLine("7. **Gun 22 (Elektrik & Dogalgaz Faturalari Gelir):** Fatura bildirimleri gelir, sisteme fatura olarak islenir.");
            sb.AppendLine("8. **Gun 30 (Ay Sonu Hesaplasmasi):** 15 ayri ikili odeme yerine sistem tek bir net bakiye ozeti cikarir: 'Arda, Can'a 1.250 TL; Ece, Can'a 800 TL atarsa butun ev sifirlanir.' Tek tıkla IBAN kopyalanir ve FAST ile hesaplar denklenir.");
            sb.AppendLine();
            sb.AppendLine("---");
            sb.AppendLine();
            sb.AppendLine("## 2. Kaldirilacaklar / Gereksiz Siskinlikler (Bloat Trimming)");
            sb.AppendLine();
            sb.AppendLine("Kullanici deneyimini karmasiklastiran, yapay zeka gosterisi olan ve gercek hayatta kullanilmayan gereksiz ozellikler:");
            sb.AppendLine();
            foreach (var item in Kaldirilacaklar)
            {
                sb.AppendLine($"- **[{item.Tag}]**: {item.Description}");
            }
            sb.AppendLine();
            sb.AppendLine("---");
            sb.AppendLine();
            sb.AppendLine("## 3. Aktif Ozellikler - Ucretsiz (Free Tier)");
            sb.AppendLine();
            foreach (var item in AktifUcretsiz)
            {
                sb.AppendLine($"- **[{item.Tag}]**: {item.Description}");
            }
            sb.AppendLine();
            sb.AppendLine("---");
            sb.AppendLine();
            sb.AppendLine("## 4. Aktif Ozellikler - Ev Premium (Household Pro Tier)");
            sb.AppendLine();
            foreach (var item in AktifPro)
            {
                sb.AppendLine($"- **[{item.Tag}]**: {item.Description}");
            }
            sb.AppendLine();
            sb.AppendLine("---");
            sb.AppendLine();
            sb.AppendLine("## 5. Yol Haritasi ve Evrim Fazlari (Roadmap)");
            sb.AppendLine();
            sb.AppendLine("### Faz 1: Sadeleştirme ve Siskinlik Temizligi (Anlik)");
            sb.AppendLine("- Fiş OCR ve ayri hesap makinasi kalintilarini arayuzden gizleme / kaldirma.");
            sb.AppendLine("- Kategori hiyerarsisini gercek hayat frekansina gore duzenleme (Kira butonunu gunluk alandan kaldirma).");
            sb.AppendLine("- Masaustu EvdasManager.exe ile fikirler ve ozellikler yonetimini saglama.");
            sb.AppendLine();
            sb.AppendLine("### Faz 2: Ev Bazli Ortak Premium & Otomatik Talimatlar");
            sb.AppendLine("- Ev lisansi modelini subscription_service'e entegre etme (300 TL/ay -> 3 kisilik evde kisi basi 100 TL ortak harcama).");
            sb.AppendLine("- 1 aylik ucretsiz kullanim sonrasi otomatik talimatlar ve gelismis odesme ozellikleri ile donusum artirma.");
            sb.AppendLine("- Ozel kategori olusturma arayuzu.");
            sb.AppendLine();
            sb.AppendLine("### Faz 3: Gelismis Borc Sadelesmesi ve Ev Devir Sihirbazi");
            sb.AppendLine("- Minimum banka transferi algoritmasi.");
            sb.AppendLine("- Evden ayrilan arkadas icin gecmis borc ve depozito mutabakat sihirbazi.");
            sb.AppendLine("- FAST entegrasyonu ve dekont yukleme dogrulamasi.");

            File.WriteAllText(OzelliklerPath, sb.ToString(), Encoding.UTF8);
        }

        public void SaveAll()
        {
            SaveFikirler();
            SaveOzellikler();
        }

        public string GenerateAutonomousPrompt()
        {
            var sb = new StringBuilder();
            sb.AppendLine("# GÖREV: OTONOM PROJE MÜKEMMELLEŞTİRME VE EVRİM MOTORU");
            sb.AppendLine();
            sb.AppendLine("Hedef Proje: C:\\Projeler\\evdas_mobile");
            sb.AppendLine("Tarih / Tetikleme: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
            sb.AppendLine();
            sb.AppendLine("ÖNCELİKLİ DİREKTİFLER:");
            sb.AppendLine("1. fikirler.md dosyasını oku ve 'Secilen Fikirler' bölümündeki şu maddeleri öncelikle koda dönüştür:");
            foreach (var item in SecilenFikirler)
            {
                sb.AppendLine($"   - [{item.Tag}] {item.Description}");
            }
            sb.AppendLine();
            sb.AppendLine("2. ozellikler.md dosyasını oku ve 'Kaldirilacaklar' bölümündeki şu gereksiz şişkinlikleri temizle:");
            foreach (var item in Kaldirilacaklar)
            {
                sb.AppendLine($"   - [{item.Tag}] {item.Description}");
            }
            sb.AppendLine();
            sb.AppendLine("3. KATEGORİ REFAKTÖRÜ:");
            sb.AppendLine("   - Günlük hızlı harcamalardan ayda 1 kez ödenen 'Kira' butonunu çıkar.");
            sb.AppendLine("   - Gerçek hayat sıklığı: Market & Bakkal, Damacana Su, Temizlik, Ortak Yemek, İçecek & Eğlence, Faturalar.");
            sb.AppendLine("   - Kullanıcı tanımlı özel kategorilere olanak sağla.");
            sb.AppendLine();
            sb.AppendLine("4. EV BAZLI ORTAK PREMİUM MODELİ:");
            sb.AppendLine("   - Bireysel ₺150 yerine tüm eve ₺300/ay ortak lisans kurgula.");
            sb.AppendLine("   - 3 kişilik evde otomatik ortak ev harcaması olarak kaydet (kişi başı ₺100).");
            sb.AppendLine();
            sb.AppendLine("5. KURAL 1: SIFIR EMOJİ! Sadece keskin vektörel Material Symbols / Icons. test/emoji_audit_test.dart geçmelidir.");
            sb.AppendLine("6. flutter analyze ve flutter test %100 başarılı olmalıdır.");
            sb.AppendLine("7. git add ., commit ve git push origin main ile GitHub'a gönderilmelidir.");

            return sb.ToString();
        }

        public void TriggerAutonomousEvolution()
        {
            string prompt = GenerateAutonomousPrompt();
            File.WriteAllText(TriggerFlagPath, prompt, Encoding.UTF8);
        }
    }
}
