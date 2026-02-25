FROM alpine:3.21

RUN apk add --no-cache \
    bash \
    postgresql16-client \
    curl \
    tzdata \
    gzip

ENV TZ=Europe/Moscow \
    CRON_SCHEDULE="0 8 * * *" \
    MAX_DUMP_SIZE=52428800 \
    PG_PORT=5432

RUN mkdir -p /scripts /dumps /var/log

COPY entrypoint.sh /scripts/entrypoint.sh
COPY backup.sh /scripts/backup.sh

RUN sed -i 's/\r$//' /scripts/*.sh && \
    chmod +x /scripts/entrypoint.sh /scripts/backup.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]
