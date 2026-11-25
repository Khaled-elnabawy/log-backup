#!/usr/bin/env bash
set -euo pipefail

# --- 1) مكان السكريبت ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 2) تحميل الإعدادات ---
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
fi

# --- 3) المتغيرات الضرورية ---
: "${LOG_SOURCE_DIR:?LOG_SOURCE_DIR is required}"
: "${BACKUP_DIR:?BACKUP_DIR is required}"
: "${RETENTION_DAYS:=7}"

# --- 4) التجهيز ---
mkdir -p "$BACKUP_DIR"
LOG_FILE="$BACKUP_DIR/backup.log"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE="$BACKUP_DIR/logs_${TIMESTAMP}.tar.gz"

# --- 5) دالة التسجيل: تطبع على الشاشة وتكتب في الملف ---
log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }

# --- 6) لو حصل أي خطأ: سجّله مع رقم السطر ---
on_error() {
    log "ERROR: backup failed at line $1"
}
trap 'on_error $LINENO' ERR

# --- 7) القفل: يمنع تشغيلين مع بعض ---
exec 9>/tmp/log_backup.lock
if ! flock -n 9; then
    log "Another instance is running. Exiting."
    exit 1
fi

# --- 8) التحقق من المصدر ---
if [[ ! -d "$LOG_SOURCE_DIR" ]]; then
    log "ERROR: source dir not found: $LOG_SOURCE_DIR"
    exit 1
fi

# --- 9) الضغط ---
log "Starting backup of $LOG_SOURCE_DIR"
tar -czf "$ARCHIVE" -C "$(dirname "$LOG_SOURCE_DIR")" "$(basename "$LOG_SOURCE_DIR")"

# --- 10) التحقق من الأرشيف ---
tar -tzf "$ARCHIVE" > /dev/null
log "Archive OK: $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"

# --- 11) مسح القديم ---
find "$BACKUP_DIR" -name 'logs_*.tar.gz' -mtime +"$RETENTION_DAYS" -delete
log "Old backups cleaned (older than $RETENTION_DAYS days)"

log "Done."
