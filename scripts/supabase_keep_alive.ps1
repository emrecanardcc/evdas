# Supabase Keep-Alive PowerShell Script
$SupabaseUrl = [System.Environment]::GetEnvironmentVariable("SUPABASE_URL")
if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
    $SupabaseUrl = "https://jsqzzikbwilltyfopfyk.supabase.co"
}

$SupabaseAnonKey = [System.Environment]::GetEnvironmentVariable("SUPABASE_ANON_KEY")

if ([string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
    Write-Host "Bilgi: SUPABASE_ANON_KEY ortam degiskeni tanimlanmamis." -ForegroundColor Yellow
    Write-Host "Kullanim: set SUPABASE_ANON_KEY=your_key; powershell -File .\scripts\supabase_keep_alive.ps1"
    exit 0
}

$Headers = @{
    "apikey"        = $SupabaseAnonKey
    "Authorization" = "Bearer $SupabaseAnonKey"
    "Content-Type"  = "application/json"
}

$Endpoint = "$SupabaseUrl/rest/v1/partnerships?select=id&limit=1"
Write-Host "Supabase canlilik pingi gonderiliyor: $Endpoint"

try {
    $Response = Invoke-RestMethod -Uri $Endpoint -Method Get -Headers $Headers -TimeoutSec 15
    Write-Host "Basarili! Supabase veritabani aktif tutuldu ve yanit verdi." -ForegroundColor Green
} catch {
    Write-Host "Hata olustu: $($_.Exception.Message)" -ForegroundColor Yellow
}
