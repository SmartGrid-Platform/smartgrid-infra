#!/bin/bash

# Exit on error
set -e

# Log output to user_data.log
exec > >(tee -i /var/log/user_data.log) 2>&1

echo "========================================="
echo "   SmartGrid Backend Auto-Bootstrap      "
echo "========================================="

# 1. Update packages and install dependencies
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl netcat-openbsd

# 2. Install Node.js v18 LTS
echo "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# 3. Install PM2 globally
echo "Installing PM2..."
npm install -g pm2

# 4. Clone repository
echo "Cloning codebase..."
rm -rf /home/ubuntu/electricity-grid
git clone -b feature/ai-assistant-bedrock-nova https://github.com/Likhi161/electricity-grid.git /home/ubuntu/electricity-grid
chown -R ubuntu:ubuntu /home/ubuntu/electricity-grid

# 5. Wait for RDS MySQL Database (up to 5 minutes)
echo "Waiting for RDS MySQL to become active..."
DB_HOST="${db_host}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
DB_NAME="${db_name}"

for i in {1..60}; do
  if nc -z -w3 "$DB_HOST" 3306; then
    echo "Database is ready!"
    break
  fi
  echo "Database not ready yet... sleeping 5s"
  sleep 5
done

# 6. Generate .env files for microservices
echo "Generating .env configuration files..."
PROJECT_ROOT="/home/ubuntu/electricity-grid"
SERVICES=("auth-service" "consumer-service" "meter-service" "billing-service" "alert-service" "ai-assistant-service")

write_env_file() {
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
AWS_REGION=${aws_region}
AWS_SECRET_NAME=${secret_name}
EOF
}

# Write shared database env
write_env_file "$PROJECT_ROOT/shared/database/.env"

# Write per-service env files
write_env_file "$PROJECT_ROOT/services/auth-service/.env"
echo "PORT=3001" >> "$PROJECT_ROOT/services/auth-service/.env"

write_env_file "$PROJECT_ROOT/services/consumer-service/.env"
echo "PORT=3002" >> "$PROJECT_ROOT/services/consumer-service/.env"

write_env_file "$PROJECT_ROOT/services/meter-service/.env"
echo "PORT=3003" >> "$PROJECT_ROOT/services/meter-service/.env"

write_env_file "$PROJECT_ROOT/services/billing-service/.env"
echo "PORT=3004" >> "$PROJECT_ROOT/services/billing-service/.env"
echo "LAMBDA_BILL_GENERATOR=${lambda_bill_generator}" >> "$PROJECT_ROOT/services/billing-service/.env"
echo "LAMBDA_TARIFF_ENGINE=${lambda_tariff_engine}" >> "$PROJECT_ROOT/services/billing-service/.env"
echo "LAMBDA_UNIT_CALCULATOR=${lambda_unit_calculator}" >> "$PROJECT_ROOT/services/billing-service/.env"
echo "S3_BUCKET_NAME=${s3_bucket_name}" >> "$PROJECT_ROOT/services/billing-service/.env"

write_env_file "$PROJECT_ROOT/services/alert-service/.env"
echo "PORT=3005" >> "$PROJECT_ROOT/services/alert-service/.env"

# AI Assistant specific env — includes Bedrock model IDs + internal service URLs
write_env_file "$PROJECT_ROOT/services/ai-assistant-service/.env"
cat >> "$PROJECT_ROOT/services/ai-assistant-service/.env" <<EOF
PORT=4004
BEDROCK_REGION=us-east-1
BEDROCK_MODEL_PRIMARY=amazon.nova-pro-v1:0
BEDROCK_MODEL_FALLBACK=amazon.nova-lite-v1:0
CONSUMER_SERVICE_URL=http://localhost:3002
BILLING_SERVICE_URL=http://localhost:3004
METER_SERVICE_URL=http://localhost:3003
EOF

# Ensure files are owned by ubuntu
chown -R ubuntu:ubuntu /home/ubuntu/electricity-grid

# 7. Install Monorepo Dependencies
echo "Installing dependencies..."
cd "$PROJECT_ROOT/shared/database"
npm install --unsafe-perm

for SERVICE in "$${SERVICES[@]}"; do
  echo "Installing dependencies for $SERVICE..."
  cd "$PROJECT_ROOT/services/$SERVICE"
  npm install --unsafe-perm
done

# 8. Synchronize Database & Create Admin Account with Tariff seeds
echo "Running migrations and bootstrapping database..."
cd "$PROJECT_ROOT/shared/database"
npm run migrate

echo "Bootstrapping Administrator..."
# Inject environment variables to run bootstrap script non-interactively
ADMIN_NAME="Admin" ADMIN_EMAIL="admin@smartgrid.com" ADMIN_PASSWORD="password123" npm run bootstrap

# 9. Start Microservices in PM2
echo "Starting microservices..."
for SERVICE in "$${SERVICES[@]}"; do
  echo "Launching $SERVICE..."
  cd "$PROJECT_ROOT/services/$SERVICE"
  # Start under pm2 for ubuntu user
  sudo -u ubuntu pm2 start server.js --name "smartgrid-$SERVICE"
done

# Save PM2 state for automatic startup on reboot
sudo -u ubuntu pm2 save
env PATH=$$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu | bash

echo "========================================="
echo "      Bootstrap Process Completed        "
echo "========================================="
