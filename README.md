### ClinicMaster Facility Deployment - Debezium Kafka Connect

This guide explains how a ClinicMaster facility deploys the reusable Kafka Connect container to stream SQL Server CDC events to the central Kafka, with the connector auto-created from environment variables.

### Prerequisites
- Facility host has Docker and Docker Compose installed
- Secure network path (VPN/private link) from facility to central Kafka
- SQL Server CDC enabled on the target DB/tables
- Kafka credentials available (no public IP exposure)

### 1) Get the deployment files
- If you ALREADY have this folder locally (e.g., shared via USB/drive/IT package), continue to step 2.
- If you DO NOT have the files, clone or download from the ClinicMaster repository:
  ```bash
  git clone <clinicmaster-repo-url> ClinicMasterWareHouseConnector
  cd ClinicMasterWareHouseConnector
  ```

### 2) Prepare environment configuration
```bash
cd ClinicMasterWareHouseConnector
cp env.sample .env
vi .env
```
Edit `.env` with facility-specific values:
- FACILITY_NAME and FACILITY_DHIS2_CODE
- DB_HOST, DB_PORT (for named instances set the configured port), DB_USER, DB_PASS, DB_NAME
- KAFKA_BOOTSTRAP_SERVERS, KAFKA_USER, KAFKA_PASS

### 3) Get the container image (optional)
- If the image is already present on the host or preloaded by IT, you can skip this step.
- Otherwise, pull the official ClinicMaster image:
  ```bash
  # Replace with the actual ClinicMaster registry path if different
  docker pull clinicmaster/clinicmasterwarehouse:latest

  # Tag locally for compose if needed
  docker tag clinicmaster/clinicmasterwarehouse:latest clinicmasterwarehouse:latest
  ```

### 4) Start the stack (Connect worker + auto-init source connector)
```bash
docker compose up -d
```
This launches:
- `clinicmasterwarehouse`: Kafka Connect worker with Debezium plugins
- `init-connector`: one-shot job that waits for Connect then POSTs the Debezium source connector using your `.env`

### 5) Verify deployment
```bash
# Worker logs
docker logs clinicmasterwarehouse | tail -n 200

# List connectors
curl -s http://localhost:8083/connectors | jq

# Check status (replace with your connector name if needed)
# Format: <DHIS2_CODE>-<facility-name-slug>-sqlserver-connector
curl -s http://localhost:8083/connectors | jq -r '.[]' | head -n 1 | xargs -I {} curl -s http://localhost:8083/connectors/{}/status | jq
```

### 6) Quick connectivity checks (if issues)
```bash
# Kafka reachability over your secure tunnel
nc -vz <central-kafka-host> 9093

# SQL Server reachability
nc -vz ${DB_HOST} ${DB_PORT}

# Connect REST
curl -s http://localhost:8083/ | jq
```

### 7) Expected behavior
- Source connector publishes to shared topics: `clinicmasterwarehouse-sqlserver.<DB>.dbo.<TABLE>`
- Each record includes `facility_dhis2_code` and `facility_name`
- Record key includes `facility_dhis2_code` alongside the true table PK (composite), enabling safe upserts into shared tables downstream

### 8) Troubleshooting
- CDC not enabled: enable CDC at DB and table level, then restart connector
- Schema history: per-facility history topic is used; if recovery needed, restart after resolving history retention
- Auth failures: verify `KAFKA_USER`/`KAFKA_PASS` and `CONNECT_SECURITY_PROTOCOL`
- Named instances: ensure `DB_PORT` matches SQL Server listener port

### 9) Operations
- Stop stack: `docker compose down`
- Update image: `docker pull clinicmaster/clinicmasterwarehouse:latest && docker compose up -d`
- View connector config: `curl -s http://localhost:8083/connectors/<name>/config | jq`

### Notes
- Do not commit credentials; use `.env`
- REST API is local-only by default; manage via SSH tunnel if remote access is required
- For central sink connector setup and data warehouse details, see `writeup.md`
