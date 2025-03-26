🚀 BackupSync, tam ve artımlı yedeklemeleri verimli bir şekilde yöneten güçlü bir yedekleme çözümüdür. Depolama kullanımını optimize ederken hızlı ve güvenilir veri koruması sağlar.

Linux sistem yöneticileri için gelişmiş özelliklere sahip kapsamlı bir yedekleme çözümü.

| Dil | README |
| --- | --- |
| <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/us.svg" width="22"> 🇺🇸 İngilizce | [English](README.md) |
| <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/tr.svg" width="22"> 🇹🇷 Türkçe | [Türkçe](README.tr.md) |
| <img src="https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/az.svg" width="22"> 🇦🇿 Azerbaycanca | [Azərbaycanca](README.az.md) |

## Özellikler

- **Zaman Damgalı Yedeklemeler**: Her yedekleme işlemi için benzersiz bir zaman damgalı klasör oluşturur
- **Artımsal Yedeklemeler**: Son tam yedeklemeden bu yana yalnızca değişiklikleri yedekleyerek alan ve zaman tasarrufu sağlar
- **Yapılandırılabilir Kaynak/Hedef**: Neyin nereye yedekleneceğini kolayca belirtin
- **İsteğe Bağlı Sıkıştırma**: Yedekleri tar.gz formatında sıkıştırmayı seçin
- **Bildirim Sistemi**: Yedeklemeler tamamlandığında e-posta veya Telegram uyarıları alın
- **Otomatik Temizleme**: Belirtilen günlerden daha eski yedeklemeleri otomatik olarak kaldırın
- **Bulut/Ağ Desteği**: Yedekleri AWS S3, FTP sunucuları veya SSH üzerinden uzak sunuculara yükleyin
- **Zamanlama Desteği**: Cron işleriyle sorunsuz çalışacak şekilde tasarlanmıştır
- **Geri Yükleme İşlevi**: Herhangi bir tam veya artımsal yedeklemeden kolayca geri yükleme yapın

## Gereksinimler

- Bash kabuğu
- Standart Linux yardımcı programları (tar, rsync)
- Bildirimler için: mail komutu (e-posta için) veya curl (Telegram için)
- Bulut yedekleme için: aws CLI (S3 için), curl (FTP için) veya rsync/ssh (uzak sunucular için)

## Kurulum

1. Bu depoyu klonlayın:
   ```bash
   git clone https://github.com/aliyevmursal/backup-sync.git
   cd backup-sync
   ```

2. Betiği çalıştırılabilir yapın:
   ```bash
   chmod +x backup_sync.sh
   ```

3. Yapılandırmayı özelleştirin:
   ```bash
   nano backup_config.conf
   ```

## Yapılandırma

Yedekleme ayarlarınızı özelleştirmek için `backup_config.conf` düzenleyin:

```bash
# Temel ayarlar
SOURCE_DIR="/path/to/source"  # Yedeklenecek dizin
DESTINATION_DIR="/path/to/backups"  # Yedeklerin depolanacağı yer
BACKUP_RETENTION_DAYS=30  # Eski yedeklemelerin ne kadar süre tutulacağı (0 sınırsız)

# Yedekleme türü ayarları
ENABLE_COMPRESSION=true
ENABLE_INCREMENTAL=false
INCREMENTAL_MAX_FULL=7  # Artımsal kullanırken tam yedeklemeler arasındaki gün sayısı

# Özellikleri etkinleştir/devre dışı bırak
ENABLE_EMAIL_NOTIFICATION=false
ENABLE_TELEGRAM_NOTIFICATION=false
ENABLE_CLOUD_BACKUP=false

# Etkinleştirilen özellikler için ek ayarlar
# ...tüm seçenekler için yapılandırma dosyasına bakın
```

## Kullanım

### Manuel Çalıştırma

Betiği manuel olarak çalıştırın:

```bash
./backup_sync.sh
```

### Zamanlanmış Çalıştırma

Otomatik olarak çalıştırmak için crontab'a ekleyin:

```bash
# Crontab'ı düzenleyin
crontab -e

# Her gün sabah 2'de çalışacak şekilde şöyle bir satır ekleyin:
0 2 * * * /path/to/backup_sync.sh
```

### Yedekten Geri Yükleme

Bir yedekten geri yüklemek için:

```bash
# Orijinal konuma geri yükle
./backup_sync.sh restore /path/to/backup_directory

# Farklı bir konuma geri yükle
./backup_sync.sh restore /path/to/backup_directory /path/to/restore/target
```

Artımsal bir yedekten geri yüklerken, betik otomatik olarak tam yedeklemeyi ve ara artımsal yedeklemeleri doğru sırayla uygular.

## Artımsal Yedeklemeleri Anlamak

Artımsal yedeklemeler etkinleştirildiğinde:
- İlk yedekleme her zaman tam bir yedekleme olur
- Sonraki yedeklemeler yalnızca son yedeklemeden bu yana değişen dosyaları içerir
- INCREMENTAL_MAX_FULL günden sonra yeni bir tam yedekleme oluşturulur
- Geri yüklerken, sistem otomatik olarak tam yedekten ve tüm artımsal yedeklerden eksiksiz yedeği yeniden oluşturur

Avantajlar:
- Önemli ölçüde azaltılmış yedekleme boyutu
- Daha hızlı yedekleme işlemleri
- Bulut yedeklemeleri için azaltılmış ağ trafiği
- Herhangi bir zamandan geri yükleme yeteneğini korur

## Günlük Kaydı

Günlükler, zaman damgalı dosya adlarıyla `logs/` dizininde saklanır. Her yedekleme işlemi ayrıntılı bir günlük dosyası oluşturur.

## Bulut Yedekleme Seçenekleri

BackupSync, çeşitli bulut ve uzak depolama seçeneklerini destekler:

### AWS S3
```bash
ENABLE_CLOUD_BACKUP=true
CLOUD_PROVIDER="aws_s3"
AWS_S3_BUCKET="your-bucket-name"
```

### FTP Sunucusu
```bash
ENABLE_CLOUD_BACKUP=true
CLOUD_PROVIDER="ftp"
FTP_SERVER="ftp.example.com"
FTP_USER="username"
FTP_PASSWORD="password"
```

### Uzak Sunucu (SSH/rsync)
```bash
ENABLE_CLOUD_BACKUP=true
CLOUD_PROVIDER="rsync_ssh"
REMOTE_SERVER="server.example.com"
REMOTE_USER="username"
REMOTE_PATH="/path/on/remote/server"
SSH_KEY_PATH="/path/to/private/key"  # İsteğe bağlı
```

## Bildirim Ayarları

### E-posta Bildirimleri
```bash
ENABLE_EMAIL_NOTIFICATION=true
EMAIL_RECIPIENT="your-email@example.com"
```

### Telegram Bildirimleri
```bash
ENABLE_TELEGRAM_NOTIFICATION=true
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

## Lisans

MIT Lisansı

## Yazar

Mursal Aliyev

---

Bu projeye sorun bildirerek veya çekme istekleri göndererek katkıda bulunmaktan çekinmeyin!
