#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

echo "Creating azure.ini config..."
mkdir -p /certbot/config /certbot/logs /certbot/work

cat > /certbot/config/azure.ini <<EOF
dns_azure_tenant_id = $ARM_TENANT_ID
dns_azure_sp_client_id = $ARM_CLIENT_ID
dns_azure_sp_client_secret = $ARM_CLIENT_SECRET
dns_azure_environment = "AzurePublicCloud"
# Map your DNS zone to the resource group and subscription ID
dns_azure_zone1 = myzone.mycompany.com:/subscriptions/12345678-abcd-abcd-abcd-123456789012/resourceGroups/myRresourceGroup
EOF

chmod 600 /certbot/config/azure.ini

echo "Requesting certificate..."
certbot certonly -v \
  --authenticator dns-azure \
  --preferred-challenges dns \
  --noninteractive \
  --agree-tos \
  --register-unsafely-without-email \
  --dns-azure-config /certbot/config/azure.ini \
  --config-dir /certbot/config \
  --work-dir /certbot/work \
  --logs-dir /certbot/logs \
  -d myapp.myzone.mycompany.com
