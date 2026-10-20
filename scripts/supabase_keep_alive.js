/**
 * 💓 Evdaş - Supabase Keep-Alive Node.js Betiği
 * 
 * Herhangi bir sunucuda, Render, Vercel veya yerel ortamda periyodik çalıştırılabilir.
 * Kullanım: node scripts/supabase_keep_alive.js
 */

const https = require('https');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://jsqzzikbwilltyfopfyk.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_ANON_KEY) {
  console.log('ℹ️ Bilgi: SUPABASE_ANON_KEY ortam değişkeni tanımlanmamış.');
  console.log('Kullanım: SUPABASE_ANON_KEY="your_key" node scripts/supabase_keep_alive.js');
  process.exit(0);
}

const options = {
  hostname: SUPABASE_URL.replace('https://', ''),
  path: '/rest/v1/partnerships?select=id&limit=1',
  method: 'GET',
  headers: {
    'apikey': SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
  }
};

console.log(`💓 [${new Date().toISOString()}] Supabase canlılık pingi gönderiliyor...`);

const req = https.request(options, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    console.log(`HTTP Durum Kodu: ${res.statusCode}`);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      console.log('✅ Başarılı: Supabase veritabanı aktif tutuldu, uyku modu engellendi.');
    } else {
      console.log(`⚠️ Yanıt alındı: ${data}`);
    }
  });
});

req.on('error', (err) => {
  console.error(`❌ Hata: ${err.message}`);
});

req.end();
