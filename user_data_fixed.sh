#!/bin/bash
set -e
exec > >(tee -i /var/log/user_data.log) 2>&1

echo "========================================="
echo "   SmartGrid Backend Auto-Bootstrap      "
echo "========================================="

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl netcat-openbsd

echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

echo "Installing PM2..."
npm install -g pm2

echo "Cloning codebase..."
rm -rf /home/ubuntu/electricity-grid
git clone -b feature/ai-assistant-bedrock-nova https://github.com/Likhi161/electricity-grid.git /home/ubuntu/electricity-grid
chown -R ubuntu:ubuntu /home/ubuntu/electricity-grid

echo "Waiting for RDS MySQL to become active..."
DB_HOST="smartgrid-dev-rds-db.cvas0qse4i7j.ap-south-1.rds.amazonaws.com"
DB_USER="smartgrid_user"
DB_PASSWORD="password"
DB_NAME="smartgrid"

for i in {1..60}; do
  if nc -z -w3 "$DB_HOST" 3306; then
    echo "Database is ready!"
    break
  fi
  echo "Database not ready yet... sleeping 5s"
  sleep 5
done

echo "Generating .env configuration files..."
PROJECT_ROOT="/home/ubuntu/electricity-grid"

write_base_env() {
  local PATH_TO_ENV=$1
  cat > "$PATH_TO_ENV" <<EOF
NODE_ENV=production
DB_HOST=$DB_HOST
DB_PORT=3306
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
JWT_SECRET=a2b53cdd87431e5630283c448f72ee7b2c91b5da8d1234c9fb66b3f7efc4901f
SMTP_HOST=smtp.mailtrap.io
SMTP_PORT=2525
SMTP_USER=
SMTP_PASS=
SENDER_EMAIL=noreply@smartgrid.com
AWS_REGION=ap-south-1
AWS_SECRET_NAME=smartgrid/config
EOF
}

# Shared DB env
write_base_env "$PROJECT_ROOT/shared/database/.env"

# auth-service
write_base_env "$PROJECT_ROOT/services/auth-service/.env"
echo "PORT=3001" >> "$PROJECT_ROOT/services/auth-service/.env"

# consumer-service
write_base_env "$PROJECT_ROOT/services/consumer-service/.env"
echo "PORT=3002" >> "$PROJECT_ROOT/services/consumer-service/.env"

# meter-service
write_base_env "$PROJECT_ROOT/services/meter-service/.env"
echo "PORT=3003" >> "$PROJECT_ROOT/services/meter-service/.env"

# billing-service
write_base_env "$PROJECT_ROOT/services/billing-service/.env"
cat >> "$PROJECT_ROOT/services/billing-service/.env" <<EOF
PORT=3004
LAMBDA_BILL_GENERATOR=smartgrid-dev-bill-generator-ddda1s
LAMBDA_TARIFF_ENGINE=smartgrid-dev-tariff-engine-ddda1s
LAMBDA_UNIT_CALCULATOR=smartgrid-dev-unit-calculator-ddda1s
S3_BUCKET_NAME=smartgrid-dev-bills-bucket-ddda1s
EOF

# alert-service
write_base_env "$PROJECT_ROOT/services/alert-service/.env"
echo "PORT=3005" >> "$PROJECT_ROOT/services/alert-service/.env"

# ai-assistant-service (critical: Bedrock + service URLs)
write_base_env "$PROJECT_ROOT/services/ai-assistant-service/.env"
cat >> "$PROJECT_ROOT/services/ai-assistant-service/.env" <<EOF
PORT=4004
BEDROCK_REGION=us-east-1
BEDROCK_MODEL_PRIMARY=amazon.nova-pro-v1:0
BEDROCK_MODEL_FALLBACK=amazon.nova-lite-v1:0
CONSUMER_SERVICE_URL=http://localhost:3002
BILLING_SERVICE_URL=http://localhost:3004
METER_SERVICE_URL=http://localhost:3003
EOF

chown -R ubuntu:ubuntu /home/ubuntu/electricity-grid

echo "Installing dependencies..."
cd "$PROJECT_ROOT/shared/database"
npm install --unsafe-perm

SERVICES=("auth-service" "consumer-service" "meter-service" "billing-service" "alert-service" "ai-assistant-service")
for SERVICE in "${SERVICES[@]}"; do
  echo "Installing dependencies for $SERVICE..."
  cd "$PROJECT_ROOT/services/$SERVICE"
  npm install --unsafe-perm
done

echo "Running migrations and bootstrapping database..."
cd "$PROJECT_ROOT/shared/database"
npm run migrate

echo "Bootstrapping Administrator..."
ADMIN_NAME="Admin" ADMIN_EMAIL="admin@smartgrid.com" ADMIN_PASSWORD="password123" npm run bootstrap

echo "Starting microservices..."
for SERVICE in "${SERVICES[@]}"; do
  echo "Launching $SERVICE..."
  cd "$PROJECT_ROOT/services/$SERVICE"
  sudo -u ubuntu pm2 start server.js --name "smartgrid-$SERVICE"
done

sudo -u ubuntu pm2 save
env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu | bash

echo "========================================="
echo "      Bootstrap Process Completed        "
echo "========================================="
