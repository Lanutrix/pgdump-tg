#!/bin/bash
set -o pipefail

source /etc/environment

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
DUMP_FILE="/dumps/${PG_DATABASE}_${TIMESTAMP}.sql.gz"
TG_API="https://api.telegram.org/bot${TG_BOT_TOKEN}"
MAX_ALLOWED_SIZE=52428800

: "${MAX_DUMP_SIZE:=$MAX_ALLOWED_SIZE}"
if [ "$MAX_DUMP_SIZE" -gt "$MAX_ALLOWED_SIZE" ] 2>/dev/null; then
    MAX_DUMP_SIZE=$MAX_ALLOWED_SIZE
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

send_message() {
    local text="$1"
    local args=(-s -F "chat_id=${TG_CHAT_ID}" -F "text=${text}" -F "parse_mode=HTML")

    if [ "${TG_CHAT_ID:0:1}" = "-" ] && [ -n "$TG_TOPIC_ID" ]; then
        args+=(-F "message_thread_id=${TG_TOPIC_ID}")
    fi

    curl "${args[@]}" "${TG_API}/sendMessage"
}

send_document() {
    local file="$1"
    local caption="$2"
    local args=(-s -F "chat_id=${TG_CHAT_ID}" -F "document=@${file}")

    if [ -n "$caption" ]; then
        args+=(-F "caption=${caption}" -F "parse_mode=HTML")
    fi

    if [ "${TG_CHAT_ID:0:1}" = "-" ] && [ -n "$TG_TOPIC_ID" ]; then
        args+=(-F "message_thread_id=${TG_TOPIC_ID}")
    fi

    curl "${args[@]}" "${TG_API}/sendDocument"
}

log "Starting backup of database '${PG_DATABASE}'..."

export PGPASSWORD="${PG_PASSWORD}"
if ! pg_dump -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE" | gzip > "$DUMP_FILE"; then
    log "ERROR: pg_dump failed"
    send_message "⚠️ <b>Backup failed</b>%0A%0ADatabase: <code>${PG_DATABASE}</code>%0AError: pg_dump exited with error"
    rm -f "$DUMP_FILE"
    exit 1
fi
unset PGPASSWORD

FILE_SIZE=$(stat -c%s "$DUMP_FILE" 2>/dev/null || stat -f%z "$DUMP_FILE" 2>/dev/null)

if [ -z "$FILE_SIZE" ] || [ "$FILE_SIZE" -eq 0 ]; then
    log "ERROR: Dump file is empty or missing"
    send_message "⚠️ <b>Backup failed</b>%0A%0ADatabase: <code>${PG_DATABASE}</code>%0AError: dump file is empty"
    rm -f "$DUMP_FILE"
    exit 1
fi

FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024))
MAX_SIZE_MB=$((MAX_DUMP_SIZE / 1024 / 1024))

log "Dump size: ${FILE_SIZE_MB} MB (${FILE_SIZE} bytes)"

if [ "$FILE_SIZE" -gt "$MAX_DUMP_SIZE" ]; then
    log "WARN: Dump exceeds max size (${FILE_SIZE_MB} MB > ${MAX_SIZE_MB} MB)"
    send_message "⚠️ <b>Dump too large</b>%0A%0ADatabase: <code>${PG_DATABASE}</code>%0ASize: ${FILE_SIZE_MB} MB%0ALimit: ${MAX_SIZE_MB} MB%0A%0AThe dump was not sent."
    rm -f "$DUMP_FILE"
    exit 0
fi

log "Sending dump to Telegram..."
RESPONSE=$(send_document "$DUMP_FILE" "📦 <b>${PG_DATABASE}</b> | ${TIMESTAMP} | ${FILE_SIZE_MB} MB")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    log "Backup sent successfully"
else
    log "ERROR: Failed to send to Telegram. Response: ${RESPONSE}"
    send_message "⚠️ <b>Backup upload failed</b>%0A%0ADatabase: <code>${PG_DATABASE}</code>%0ASize: ${FILE_SIZE_MB} MB%0ACheck container logs for details."
fi

rm -f "$DUMP_FILE"
log "Cleanup done"
