#!/bin/sh
set -eu

CONNECT_URL="http://connect:8083"

wait_for_connect() {
	until curl -fsS "$CONNECT_URL/connectors" >/dev/null 2>&1; do
		echo "Waiting for Kafka Connect at $CONNECT_URL..."
		sleep 5
	done
	echo "Kafka Connect is ready."
}

slugify() {
	# Lowercase, replace spaces with hyphens, remove non-alphanum/hyphen
	echo "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/--\+/-/g' -e 's/^-\|-$//g'
}

post_connector() {
	name_slug="$(slugify "${FACILITY_NAME}")"
	name="${FACILITY_DHIS2_CODE}-${name_slug}-sqlserver-connector"
	cat > /tmp/connector.json <<'JSON'
{
  "name": "__NAME__",
  "config": {
    "connector.class": "io.debezium.connector.sqlserver.SqlServerConnector",
    "database.hostname": "__DB_HOST__",
    "database.port": "__DB_PORT__",
    "database.user": "__DB_USER__",
    "database.password": "__DB_PASS__",
    "database.names": "__DB_NAME__",
    "topic.prefix": "clinicmasterwarehouse-sqlserver",
    "snapshot.mode": "when_needed",
    "table.include.list": "dbo\\..*",
    "schema.history.internal.kafka.bootstrap.servers": "__KAFKA_BOOTSTRAP_SERVERS__",
    "schema.history.internal.kafka.topic": "__FACILITY_DHIS2_CODE__.clinicmaster.history",
    "include.schema.changes": "true",
    "transforms": "unwrap,addFacilityCode,addFacilityName,addFacilityCodeKey",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "false",
    "transforms.unwrap.add.headers": "op,source.ts_ms",
    "transforms.addFacilityCode.type": "org.apache.kafka.connect.transforms.InsertField$Value",
    "transforms.addFacilityCode.static.field": "facility_dhis2_code",
    "transforms.addFacilityCode.static.value": "__FACILITY_DHIS2_CODE__",
    "transforms.addFacilityName.type": "org.apache.kafka.connect.transforms.InsertField$Value",
    "transforms.addFacilityName.static.field": "facility_name",
    "transforms.addFacilityName.static.value": "__FACILITY_NAME__",
    "transforms.addFacilityCodeKey.type": "org.apache.kafka.connect.transforms.InsertField$Key",
    "transforms.addFacilityCodeKey.static.field": "facility_dhis2_code",
    "transforms.addFacilityCodeKey.static.value": "__FACILITY_DHIS2_CODE__",
    "heartbeat.interval.ms": "30000",
    "openlineage.integration.enabled": "false",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "true",
    "value.converter.schemas.enable": "true",
    "database.encrypt": "false",
    "database.trustServerCertificate": "true",
    "tasks.max": "2"
  }
}
JSON
	sed -i "" \
		-e "s/__NAME__/${name}/g" \
		-e "s/__DB_HOST__/${DB_HOST}/g" \
		-e "s/__DB_PORT__/${DB_PORT}/g" \
		-e "s/__DB_USER__/${DB_USER}/g" \
		-e "s/__DB_PASS__/${DB_PASS}/g" \
		-e "s/__DB_NAME__/${DB_NAME}/g" \
		-e "s/__FACILITY_NAME__/${FACILITY_NAME}/g" \
		-e "s/__FACILITY_DHIS2_CODE__/${FACILITY_DHIS2_CODE}/g" \
		-e "s/__KAFKA_BOOTSTRAP_SERVERS__/${KAFKA_BOOTSTRAP_SERVERS}/g" /tmp/connector.json

	echo "Creating/Upserting connector $name..."
	if curl -fsS -X GET "$CONNECT_URL/connectors/$name" >/dev/null 2>&1; then
		curl -fsS -X PUT -H 'Content-Type: application/json' \
			"$CONNECT_URL/connectors/$name/config" \
			-d @/tmp/connector.json
	else
		curl -fsS -X POST -H 'Content-Type: application/json' \
			"$CONNECT_URL/connectors" \
			-d @/tmp/connector.json
	fi

	echo "Connector $name is configured."
}

wait_for_connect
post_connector
