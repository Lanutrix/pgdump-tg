# pgdump-tg

Lightweight Docker image (~15 MB) that automatically backs up a PostgreSQL database on a cron schedule and sends the gzipped dump to a Telegram chat via Bot API.

## Features

- Alpine-based minimal image
- Cron-scheduled `pg_dump` + `gzip` compression
- Sends dump file to Telegram (personal chat, group, or supergroup topic)
- Configurable max file size with Telegram Bot API 50 MB limit enforcement
- Timezone support (default: MSK / Europe/Moscow)
- Validates required env vars on startup — logs all missing ones and exits
- Sends a startup connectivity check to Telegram — verifies bot token and chat ID before scheduling backups

## Quick Start

```bash
docker run -d --name pgdump-tg \
  -e TG_BOT_TOKEN="123456:ABC-DEF" \
  -e TG_CHAT_ID="-1001234567890" \
  -e PG_HOST="db" \
  -e PG_USER="postgres" \
  -e PG_PASSWORD="secret" \
  -e PG_DATABASE="mydb" \
  pgdump-tg
```

## Docker Compose

```yaml
services:
  pgdump-tg:
    build: .
    environment:
      TG_BOT_TOKEN: "123456:ABC-DEF"
      TG_CHAT_ID: "-1001234567890"
      TG_TOPIC_ID: "42"             # optional
      PG_HOST: "db"
      PG_PORT: "5432"               # optional, default: 5432
      PG_USER: "postgres"
      PG_PASSWORD: "secret"
      PG_DATABASE: "mydb"
      CRON_SCHEDULE: "0 8 * * *"    # optional, default: daily at 08:00
      TZ: "Europe/Moscow"           # optional, default: Europe/Moscow
      MAX_DUMP_SIZE: "52428800"     # optional, default: 50 MB (bytes)
    restart: unless-stopped
```

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `TG_BOT_TOKEN` | yes | — | Telegram bot token |
| `TG_CHAT_ID` | yes | — | Telegram chat ID. Positive = direct/group, negative = supergroup |
| `PG_HOST` | yes | — | PostgreSQL host |
| `PG_USER` | yes | — | PostgreSQL user |
| `PG_PASSWORD` | yes | — | PostgreSQL password |
| `PG_DATABASE` | yes | — | Database name to dump |
| `PG_PORT` | no | `5432` | PostgreSQL port |
| `CRON_SCHEDULE` | no | `0 8 * * *` | Cron expression for backup schedule |
| `TZ` | no | `Europe/Moscow` | Container timezone (MSK +3) |
| `TG_TOPIC_ID` | no | — | Forum topic ID (only used when `TG_CHAT_ID` is negative) |
| `MAX_DUMP_SIZE` | no | `52428800` | Max dump size in bytes. Cannot exceed 50 MB (Telegram Bot API limit) |

## How It Works

1. **Startup** — `entrypoint.sh` validates all required env vars. If any are missing, it logs which ones and exits with code 1. Then sends a test message to Telegram to verify bot token and chat ID — if it fails, the container exits immediately.
2. **Cron** — A cron job is set up with the configured schedule. The container runs `crond` in the foreground.
3. **Backup** — `backup.sh` runs `pg_dump`, pipes through `gzip`, and produces `dbname_YYYY-MM-DD_HH-MM.sql.gz`.
4. **Size check** — If the compressed dump exceeds `MAX_DUMP_SIZE`, a text notification is sent instead of the file.
5. **Send** — The dump is sent to Telegram via `sendDocument`. If `TG_CHAT_ID` is negative and `TG_TOPIC_ID` is set, the file is sent to that specific topic.
6. **Cleanup** — Temporary dump files are deleted after each run.

## License

BSD 3-Clause License. See [LICENSE](LICENSE).
