#!/bin/bash
set -euo pipefail

mkdir -p /etc/pitstop

# Script that fetches DB credentials from Secrets Manager and writes the config
cat > /usr/local/bin/refresh-db-config.sh <<'EOF'
#!/bin/bash
set -euo pipefail
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "${db_secret_arn}" \
  --region "${region}" \
  --query SecretString --output text)

# Combine the secret (username, password) with the connection details
echo "$SECRET" | jq \
  --arg host "${db_host}" \
  --arg port "${db_port}" \
  --arg dbname "${db_name}" \
  '. + {host: $host, port: $port, dbname: $dbname}' > /etc/pitstop/db.json.tmp

chown root:apache /etc/pitstop/db.json.tmp
chmod 640 /etc/pitstop/db.json.tmp
mv /etc/pitstop/db.json.tmp /etc/pitstop/db.json
EOF
chmod 700 /usr/local/bin/refresh-db-config.sh

# Run now, then every 5 minutes to follow password rotation
/usr/local/bin/refresh-db-config.sh
echo "*/5 * * * * root /usr/local/bin/refresh-db-config.sh" > /etc/cron.d/pitstop-db