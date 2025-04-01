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
- **Şifrələmə Dəstəyi**: Yedəklərinizi AES-256 şifrələmə ilə təmin edin
- **Yedək Doğrulama**: Avtomatik doğrulama ilə yedək bütövlüyünü təmin edin
- **Verilənlər Bazası Yedəkləməsi**: MySQL/MariaDB və PostgreSQL verilənlər bazaları üçün dəstək
- **Təkmilləşdirilmiş Yedəkləmə Xüsusiyyətləri**: Fayl istisna nümunələri və dublikat aradan qaldırma
- **Disk Sahəsi İzləmə**: Yedəkləmədən əvvəl kifayət qədər disk sahəsini avtomatik yoxlayın

## Tələblər

- Bash shell
- Standart Linux proqramları (tar, rsync)
- Bildirişlər üçün: mail əmri (e-poçt üçün) və ya curl (Telegram üçün)
- Şifrələmə üçün: openssl
- Verilənlər bazası yedəkləməsi üçün: mysqldump (MySQL/MariaDB) və ya pg_dump (PostgreSQL)
- Bulud yedəkləməsi üçün: aws CLI (S3 üçün), curl (FTP üçün) və ya rsync/ssh (uzaq serverlər üçün)

## Quraşdırma

1. Bu reponu klonlayın:
   ```bash
   git clone https://github.com/aliyevmursal/backupsync.git
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

# Verilənlər bazası yedəkləmə parametrləri
ENABLE_DATABASE_BACKUP=false
DATABASE_TYPE="mysql"  # mysql və ya postgresql
DB_HOST="localhost"
DB_PORT="3306"  # MySQL üçün 3306, PostgreSQL üçün 5432
DB_USER="root"
DB_PASSWORD=""
DB_NAMES=""  # Bütün verilənlər bazaları üçün boş, xüsusi verilənlər bazaları üçün vergüllə ayrılmış siyahı

# Təkmilləşdirilmiş yedəkləmə xüsusiyyətləri
FILE_EXCLUSION_PATTERNS="*.tmp,*.log,*~,.git/,.svn/"
ENABLE_DEDUPLICATION=false
MIN_DISK_SPACE_MB=1024  # Tələb olunan minimum boş yer MB ilə

# Təhlükəsizlik parametrləri
ENABLE_ENCRYPTION=false
ENCRYPTION_PASSWORD=""
ENABLE_BACKUP_VERIFICATION=true

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

## Verilənlər Bazası Yedəkləmə Xüsusiyyətləri

BackupSync MySQL/MariaDB və PostgreSQL verilənlər bazalarını yedəkləməyi dəstəkləyir:

### MySQL/MariaDB
- Saxlanmış prosedurlar, trigerlər və hadisələr ilə tam verilənlər bazası dumpları
- Xüsusi verilənlər bazalarını və ya bütün verilənlər bazalarını yedəkləmək seçimi
- Şifrələmə və sıxma xüsusiyyətləri ilə inteqrasiya

### PostgreSQL
- Səmərəli saxlama üçün xüsusi format yedəkləri
- Xüsusi verilənlər bazalarını və ya bütün verilənlər bazalarını yedəkləmək seçimi
- Şifrələmə və doğrulama xüsusiyyətləri ilə inteqrasiya

## Təkmilləşdirilmiş Yedəkləmə Xüsusiyyətləri

### Fayl İstisnası
Nümunələr istifadə edərək yedəkləmədən çıxarılacaq faylları və qovluqları müəyyən edin:
```bash
FILE_EXCLUSION_PATTERNS="*.tmp,*.log,*~,.git/,.svn/"
```

### Təkrar Aradan Qaldırma (Deduplikasiya)
Yedəklər arasında təkrarlanan faylları aradan qaldıraraq saxlama yerindən qənaət edin:
```bash
ENABLE_DEDUPLICATION=true
```

### Disk Sahəsi İzləmə
Yedəkləməyə başlamazdan əvvəl kifayət qədər disk sahəsini avtomatik olaraq yoxlayır:
```bash
MIN_DISK_SPACE_MB=1024  # Minimum boş yer MB ilə
```

## Təhlükəsizlik Xüsusiyyətləri

### Şifrələmə
Yedəklərinizi AES-256 şifrələmə ilə qoruyun:
```bash
ENABLE_ENCRYPTION=true
ENCRYPTION_PASSWORD="your-secure-password"
```

### Yedək Doğrulama
Avtomatik doğrulama ilə yedək bütövlüyünü təmin edin:
```bash
ENABLE_BACKUP_VERIFICATION=true
```

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

E-poçtlar bunları əhatə edir:
- Yedəkləmə vəziyyəti (uğurlu/uğursuz)
- Yedəkləmə uğursuz olduqda ətraflı səhv məlumatı
- Disk sahəsi məlumatı
- Yedəkləmə təfərrüatları (növ, məkan və s.)

### Telegram Bildirişləri
```bash
ENABLE_TELEGRAM_NOTIFICATION=true
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

Telegram mesajları bunları əhatə edir:
- Vizual göstərici ilə yedəkləmə vəziyyəti (✅/❌)
- Disk sahəsi metrikləri
- Yedəkləmə təfərrüatları
- Yedəkləmə uğursuz olduqda səhv məlumatı

## Lisenziya

MIT Lisenziyası

## Müəllif

Mursal Aliyev

---

Problemləri bildirməklə və ya çəkmə sorğuları göndərməklə bu layihəyə töhfə verməkdən çəkinməyin!