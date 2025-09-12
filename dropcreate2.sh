#!/bin/bash

su - postgres -c "psql -c 'SELECT 1;'" > /dev/null || { echo "PostgreSQL not available"; exit 1; }

read -p "SQL file URL: " url
read -p "Database name: " db

wget -q "$url" -O /tmp/script.sql
chown postgres:postgres /tmp/script.sql

su - postgres -c "psql -c 'DROP DATABASE IF EXISTS \"$db\";'"
su - postgres -c "psql -c 'CREATE DATABASE \"$db\";'"

su - postgres -c "psql -d '$db' -f /tmp/script.sql"

echo "Done."
