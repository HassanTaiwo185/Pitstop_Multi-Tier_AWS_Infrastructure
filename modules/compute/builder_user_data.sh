#!/bin/bash
set -euxo pipefail
# App version: ${app_hash}

# Install Apache, PHP + PostgreSQL support, jq, cron, and the psql client
dnf update -y
dnf install -y httpd php php-cli php-pgsql jq cronie postgresql16

# Enable services for instances launched from the AMI (not started here)
systemctl enable httpd php-fpm crond

# Download the site (site/ prefix only) into the web root
aws s3 sync "s3://${app_bucket}/site/" /var/www/html/ --delete

# Health check page for the ALB target group
echo "OK" > /var/www/html/health.html
chown -R apache:apache /var/www/html

# ---- Load the database schema (safe to re-run) ----
aws s3 cp "s3://${app_bucket}/db/schema.sql" /tmp/schema.sql

# Turn off command logging while handling the password,
# so it never appears in the cloud-init log
set +x
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "${db_secret_arn}" \
  --region "${region}" \
  --query SecretString --output text)
DB_USER=$(echo "$SECRET" | jq -r .username)
export PGPASSWORD=$(echo "$SECRET" | jq -r .password)

psql "host=${db_host} port=${db_port} dbname=${db_name} user=$DB_USER sslmode=require" \
  -v ON_ERROR_STOP=1 -f /tmp/schema.sql

unset PGPASSWORD SECRET
set -x
rm -f /tmp/schema.sql

# Remove builder logs so they aren't baked into the AMI
cloud-init clean --logs

# Finished: power off so Terraform can capture the AMI
shutdown -h now