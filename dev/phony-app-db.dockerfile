FROM postgres:17.6-alpine3.22

ARG SCHEMA_COMMIT=0a489faf64f5c2e440c202fd24ad66b446774a0e

# Install the VDI schema
RUN apk add --no-cache git \
 && git clone https://github.com/VEuPathDB/VdiSchema \
 && cd VdiSchema \
 && git checkout 0a489faf64f5c2e440c202fd24ad66b446774a0e \
 && cd Main/lib/sql/Postgres \
 && export SED_PAT='s/:VAR1/TEST/;/^GRANT/d' \
 && echo "CREATE SCHEMA vdi_control_test; CREATE SCHEMA vdi_datasets_test;" > /docker-entrypoint-initdb.d/01-create_schemata.sql \
 && sed "$SED_PAT" createVdiControlTables.sql > /docker-entrypoint-initdb.d/02-createVdiControlTables.sql \
 && sed "$SED_PAT" createUserDatasetTypeTables.sql > /docker-entrypoint-initdb.d/03-createUserDatasetTypeTables.sql \
 && sed "$SED_PAT" createEntityGraphTables.sql > /docker-entrypoint-initdb.d/04-createEntityGraphTables.sql \
 && echo "CREATE ROLE vdi_w;" > /docker-entrypoint-initdb.d/05-createRoles.sql \
 && rm -rf /VdiSchema
