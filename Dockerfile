# Kafka Connect image with Debezium SQL Server (and JDBC sink optional)
# Build once and push to your registry for reuse at facilities.

FROM confluentinc/cp-kafka-connect:7.6.0

ENV CONNECT_PLUGIN_PATH="/usr/share/java,/usr/share/confluent-hub-components"

# Install Debezium SQL Server connector and JDBC sink
RUN confluent-hub install --no-prompt debezium/debezium-connector-sqlserver:latest \
	&& confluent-hub install --no-prompt confluentinc/kafka-connect-jdbc:latest \
	&& mkdir -p /usr/share/confluent-hub-components/confluentinc-kafka-connect-jdbc/lib \
	&& curl -fsSL -o /usr/share/confluent-hub-components/confluentinc-kafka-connect-jdbc/lib/postgresql-42.7.3.jar \
		https://jdbc.postgresql.org/download/postgresql-42.7.3.jar

# Keep REST API local by default; override in compose if needed
ENV CONNECT_REST_ADVERTISED_HOST_NAME=localhost \
	CONNECT_REST_HOST_NAME=0.0.0.0 \
	CONNECT_REST_PORT=8083

