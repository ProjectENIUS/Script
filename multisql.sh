#!/bin/bash

su - postgres -c "psql -c 'SELECT 1;'" > /dev/null || { echo "PostgreSQL not available"; exit 1; }

read -p "SQL file URL: " url
read -p "Database name: " db

DB_EXISTS=$(su - postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='$db';\"")

if [ "$DB_EXISTS" = "1" ]; then
    BACKUP_FILE="/tmp/${db}_$(date +%Y%m%d_%H%M%S).dump"
    su - postgres -c "pg_dump -U postgres -Fc '$db' > '$BACKUP_FILE'" || exit 1
    echo "Backup: $BACKUP_FILE"
fi

wget -q "$url" -O /tmp/script.sql
chown postgres:postgres /tmp/script.sql

su - postgres -c "psql -c 'DROP DATABASE IF EXISTS \"$db\";'"
su - postgres -c "psql -c 'CREATE DATABASE \"$db\";'"
su - postgres -c "psql -d '$db' -f /tmp/script.sql" || exit 1

echo "Done."
