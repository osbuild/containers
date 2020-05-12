#!/bin/bash
set -eux

# Set DB credentials
sed -i  -e "s/.*DBHost =.*/DBHost = ${POSTGRES_HOST}/" \
        -e "s/.*DBUser =.*/DBUser = ${POSTGRES_USER}/" \
        -e "s/.*DBPass =.*/DBPass = ${POSTGRES_PASSWORD}/" \
        -e "s/.*DBName =.*/DBName = ${POSTGRES_DB}/" \
        /etc/koji-hub/hub.conf

# wait for postgres to come on-line
timeout 10 bash -c "until printf '' 2>/dev/null >/dev/tcp/${POSTGRES_HOST}/5432; do sleep 0.1; done"

# psql uses PGPASSWORD env variable
export PGPASSWORD="${POSTGRES_PASSWORD}"

# create an "alias" for the long psql command
psql_cmd() {
  psql -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" "$@"
}

# initialize the database if it isn't initialized already
if ! psql_cmd -c "select * from users" &>/dev/null; then
  psql_cmd -f /usr/share/doc/koji/docs/schema.sql >/dev/null
  psql_cmd -c "insert into users (name, password, status, usertype) values ('kojiadmin', 'kojipass', 0, 0);" >/dev/null
  psql_cmd -c "insert into user_perms (user_id, perm_id, creator_id) values (1, 1, 1);" >/dev/null
fi

# run apache
httpd -DFOREGROUND
