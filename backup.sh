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

# --- 3) المتغيرات ---
: "${LOG_SOURCE_DIR:?LOG_SOURCE_DIR is required}"
: "${BACKUP_DIR:?BACKUP_DIR is required}"
: "${RETENTION_DAYS:=7}"
: "${WEBHOOK_URL:=}"            # فاضي = مفيش إشعارات

# --- 4) التجهيز ---
mkdir -p "$BACKUP_DIR"
LOG_FILE="$BACKUP_DIR/backup.log"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE="$BACKUP_DIR/logs_${TIMESTAMP}.tar.gz"

# --- 5) دالة التسجيل ---
log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"; }

# --- 6) دالة الإشعار (البونص) ---
# الرابط جاي من .env، مش مكتوب هنا
notify() {
    [[ -z "$WEBHOOK_URL" ]] && return 0
    curl -fsS -m 10 -X POST \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"$1\"}" \
        "$WEBHOOK_URL" > /dev/null \
        || log "WARN: webhook notification failed"
}

# --- 7) عند أي خطأ: سجّل وابعت إشعار ---
on_error() {
    log "ERROR: backup failed at line $1"
    notify "Backup FAILED on $(hostname) at line $1"
}
trap 'on_error $LINENO' ERR

# --- 8) القفل ---
exec 9>/tmp/log_backup.lock
if ! flock -n 9; then
    log "Another instance is running. Exiting."
    exit 1
fi

# --- 9) التحقق من المصدر ---
if [[ ! -d "$LOG_SOURCE_DIR" ]]; then
    log "ERROR: source dir not found: $LOG_SOURCE_DIR"
    notify "Backup FAILED on $(hostname): source dir not found"
    exit 1
fi

# --- 10) الضغط ---
log "Starting backup of $LOG_SOURCE_DIR"
tar -czf "$ARCHIVE" -C "$(dirname "$LOG_SOURCE_DIR")" "$(basename "$LOG_SOURCE_DIR")"

# --- 11) التحقق من الأرشيف ---
tar -tzf "$ARCHIVE" > /dev/null
SIZE="$(du -h "$ARCHIVE" | cut -f1)"
log "Archive OK: $ARCHIVE ($SIZE)"

# --- 12) مسح القديم ---
find "$BACKUP_DIR" -name 'logs_*.tar.gz' -mtime +"$RETENTION_DAYS" -delete
log "Old backups cleaned (older than $RETENTION_DAYS days)"

# --- 13) إشعار النجاح ---
notify "Backup OK on $(hostname): $(basename "$ARCHIVE") ($SIZE)"
log "Done."
