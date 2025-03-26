## Xüsusiyyətlər

- **Vaxt Möhürlü Yedəklər**: Hər yedəkləmə əməliyyatı üçün unikal vaxt möhürlü qovluq yaradır
- **Artımlı Yedəklər**: Son tam yedəkdən bəri yalnız dəyişiklikləri yedəkləyərək yer və vaxtdan qənaət edin
- **Tənzimlənə bilən Mənbə/Hədəf**: Nəyin haraya yedəklənəcəyini asanlıqla müəyyən edin
- **İstəyə bağlı Sıxma**: Yedəkləri tar.gz formatında sıxmağı seçin
- **Bildiriş Sistemi**: Yedəklər tamamlandıqda e-poçt və ya Telegram xəbərdarlıqları alın
- **Avtomatik Təmizləmə**: Müəyyən gündən köhnə yedəkləri avtomatik olaraq silin
- **Bulud/Şəbəkə Dəstəyi**: Yedəkləri AWS S3, FTP serverləri və ya SSH vasitəsilə uzaq serverlərə yükləyin
- **Planlaşdırma Dəstəyi**: Cron işləri ilə problemsiz işləmək üçün hazırlanmışdır
- **Bərpa Funksiyası**: İstənilən tam və ya artımlı yedəkdən asanlıqla bərpa edin

## Tələblər

- Bash shell
- Standart Linux proqramları (tar, rsync)
- Bildirişlər üçün: mail əmri (e-poçt üçün) və ya curl (Telegram üçün)
- Bulud yedəkləməsi üçün: aws CLI (S3 üçün), curl (FTP üçün) və ya rsync/ssh (uzaq serverlər üçün)

## Quraşdırma

1. Bu reponu klonlayın:
   ```bash
   git clone https://github.com/aliyevmursal/backup-sync.git
   cd backup-sync
   ```

2. Skripti icra edilə bilən edin:
   ```bash
   chmod +x backup_sync.sh
   ```

3. Konfiqurasiyaları fərdiləşdirin:
   ```bash
   nano backup_config.conf
   ```

## Konfiqurasiya

Yedəkləmə parametrlərinizi fərdiləşdirmək üçün `backup_config.conf` redaktə edin:

```bash
# Əsas parametrlər
SOURCE_DIR="/path/to/source"  # Yedəklənəcək kataloq
DESTINATION_DIR="/path/to/backups"  # Yedəklərin saxlanacağı yer
BACKUP_RETENTION_DAYS=30  # Köhnə yedəklərin nə qədər saxlanacağı (0 limitsiz)

# Yedəkləmə növü parametrləri
ENABLE_COMPRESSION=true
ENABLE_INCREMENTAL=false
INCREMENTAL_MAX_FULL=7  # Artımlı yedəkləmədən istifadə edərkən tam yedəklər arasında günlər

# Xüsusiyyətləri aktivləşdirin/deaktiv edin
ENABLE_EMAIL_NOTIFICATION=false
ENABLE_TELEGRAM_NOTIFICATION=false
ENABLE_CLOUD_BACKUP=false

# Aktivləşdirilmiş xüsusiyyətlər üçün əlavə parametrlər
# ...bütün seçimlər üçün konfiqurasiya faylına baxın
```

## İstifadə

### Əl ilə İcra

Skripti əl ilə işə salın:

```bash
./backup_sync.sh
```

### Planlaşdırılmış İcra

Avtomatik işə salmaq üçün crontab-a əlavə edin:

```bash
# Crontab-ı redaktə edin
crontab -e

# Hər gün səhər saat 2-də işləməsi üçün bu kimi bir sətir əlavə edin:
0 2 * * * /path/to/backup_sync.sh
```

### Yedəkdən Bərpa

Yedəkdən bərpa etmək üçün:

```bash
# Orijinal məkana bərpa edin
./backup_sync.sh restore /path/to/backup_directory

# Fərqli məkana bərpa edin
./backup_sync.sh restore /path/to/backup_directory /path/to/restore/target
```

Artımlı yedəkdən bərpa edərkən, skript avtomatik olaraq tam yedəkləməni və bütün aralıq artımlı yedəkləmələri düzgün sıra ilə tətbiq edir.

## Artımlı Yedəkləməni Anlamaq

Artımlı yedəklər aktivləşdirildikdə:
- İlk yedəkləmə həmişə tam yedəkləmədir
- Sonrakı yedəklər yalnız son yedəkdən bəri dəyişən faylları ehtiva edir
- INCREMENTAL_MAX_FULL gündən sonra yeni tam yedəkləmə yaradılır
- Bərpa zamanı, sistem avtomatik olaraq tam yedəkdən və bütün artımlı yedəklərdən tam yedəkləməni yenidən qurur

Faydaları:
- Əhəmiyyətli dərəcədə azaldılmış yedəkləmə ölçüsü
- Daha sürətli yedəkləmə əməliyyatları
- Bulud yedəkləmələri üçün azaldılmış şəbəkə trafiki
- İstənilən nöqtədən bərpa etmək qabiliyyətini saxlayır

## Jurnal

Jurnallar vaxt möhürlü fayl adları ilə `logs/` kataloqunda saxlanılır. Hər yedəkləmə əməliyyatı ətraflı jurnal faylı yaradır.

## Bulud Yedəkləmə Seçimləri

BackupSync bir neçə bulud və uzaq saxlama seçimini dəstəkləyir:

### AWS S3
```bash
ENABLE_CLOUD_BACKUP=true
CLOUD_PROVIDER="aws_s3"
AWS_S3_BUCKET="your-bucket-name"
```

### FTP Server
```bash
ENABLE_CLOUD_BACKUP=true
CLOUD_PROVIDER="ftp"
FTP_SERVER="ftp.example.com"
FTP_USER="username"
FTP_PASSWORD="password"
```

### Uzaq Server (SSH/rsync)
```bash
ENABLE_CLOUD_BACKUP=true
CLOUD_PROVIDER="rsync_ssh"
REMOTE_SERVER="server.example.com"
REMOTE_USER="username"
REMOTE_PATH="/path/on/remote/server"
SSH_KEY_PATH="/path/to/private/key"  # İstəyə bağlı
```

## Bildiriş Quraşdırması

### E-poçt Bildirişləri
```bash
ENABLE_EMAIL_NOTIFICATION=true
EMAIL_RECIPIENT="your-email@example.com"
```

### Telegram Bildirişləri
```bash
ENABLE_TELEGRAM_NOTIFICATION=true
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

## Lisenziya

MIT Lisenziyası

## Müəllif

Mursal Aliyev

---

Problemləri bildirməklə və ya çəkmə sorğuları göndərməklə bu layihəyə töhfə verməkdən çəkinməyin!