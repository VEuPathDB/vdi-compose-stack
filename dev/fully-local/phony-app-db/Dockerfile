FROM postgres:17.6-alpine3.22

ARG SCHEMA_COMMIT=45d3952b5f3dd5db9df7d52fc8e9644fa4c80cd2

# Install the VDI schema
RUN apk add --no-cache git \
 && git clone https://github.com/VEuPathDB/VdiSchema \
 && cd VdiSchema \
 && git checkout ${SCHEMA_COMMIT} \
 && cd Main/lib/sql/Postgres \
 && export SED_PAT='s/:VAR1/TEST/;/^GRANT/d' \
 && sed "$SED_PAT" createVdiControlTables.sql > /docker-entrypoint-initdb.d/02-createVdiControlTables.sql \
 && sed "$SED_PAT" createUserDatasetTypeTables.sql > /docker-entrypoint-initdb.d/03-createUserDatasetTypeTables.sql \
 && sed "$SED_PAT" createEntityGraphTables.sql > /docker-entrypoint-initdb.d/04-createEntityGraphTables.sql \
 && rm -rf /VdiSchema

COPY extra-ddl/ /docker-entrypoint-initdb.d/