#!/bin/bash
set -e

MAX_ALLOWED_SIZE=52428800

REQUIRED_VARS=(
    "TG_BOT_TOKEN"
    "TG_CHAT_ID"
    "PG_HOST"
    "PG_USER"
    "PG_PASSWORD"
    "PG_DATABASE"
)

missing=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        missing+=("$var")
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    echo "[ERROR] Missing required environment variables: ${missing[*]}"
    exit 1
fi

: "${CRON_SCHEDULE:=0 8 * * *}"
: "${TZ:=Europe/Moscow}"
: "${MAX_DUMP_SIZE:=$MAX_ALLOWED_SIZE}"
: "${PG_PORT:=5432}"

if [ "$MAX_DUMP_SIZE" -gt "$MAX_ALLOWED_SIZE" ] 2>/dev/null; then
    echo "[WARN] MAX_DUMP_SIZE ($MAX_DUMP_SIZE) exceeds Telegram Bot API limit (50 MB). Forcing to 50 MB."
    MAX_DUMP_SIZE=$MAX_ALLOWED_SIZE
fi

echo "[INFO] Timezone: $TZ"
echo "[INFO] Cron schedule: $CRON_SCHEDULE"
echo "[INFO] Database: $PG_USER@$PG_HOST:$PG_PORT/$PG_DATABASE"
echo "[INFO] Telegram chat: $TG_CHAT_ID"
if [ -n "$TG_TOPIC_ID" ]; then
    echo "[INFO] Telegram topic: $TG_TOPIC_ID"
fi
echo "[INFO] Max dump size: $((MAX_DUMP_SIZE / 1024 / 1024)) MB"

export -p > /etc/environment

echo "$CRON_SCHEDULE /scripts/backup.sh >> /var/log/backup.log 2>&1" | crontab -

echo "[INFO] Starting crond..."
exec crond -f -d 8
