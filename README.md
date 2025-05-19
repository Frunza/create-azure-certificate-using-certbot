# Create Azure certificate using certbot

## Scenario

If you have some `DNS` configuration in `Azure`, there might come times when you manually need to generate certificates for development purposes(in production everything should be fully automated). A good tool you can use for this is `certbot`. So how can you do that on your local machine?

## Prerequisites

A Linux or MacOS machine for local development. If you are running Windows, you first need to set up the *Windows Subsystem for Linux (WSL)* environment.

You need `docker cli` and `docker-compose` on your machine for testing purposes, and/or on the machines that run your pipeline.
You can check both of these by running the following commands:
```sh
docker --version
docker-compose --version
```

For `Azure` access you need the following:
- ARM_TENANT_ID
- ARM_SUBSCRIPTION_ID
- ARM_CLIENT_ID
- ARM_CLIENT_SECRET

## Implementation
The idea is to install use a container with all necessary tools, give it credentials via environment variables, and obtain the result by using a volume mount.

The container needs to have `certbot` and its `Azure DNS` plugin installed. This can look as:
```sh
FROM python:3.13-alpine

RUN apk add --no-cache bash curl gcc musl-dev libffi-dev openssl-dev make linux-headers
RUN pip install certbot certbot-dns-azure

RUN mkdir -p /certbot/logs /certbot/config /certbot/work

ADD ./scripts /app
WORKDIR /app
```
To access `Azure`, `certbot` needs some configuration. Let's write the `docker-compose` to pass the required environment variables and configure the volume mount:
```sh
services:
  main:
    image: azure-container-cermanager
    network_mode: host
    volumes:
      - ./certbot:/certbot
    working_dir: /app
    environment:
      - ARM_CLIENT_ID=${ARM_CLIENT_ID}
      - ARM_CLIENT_SECRET=${ARM_CLIENT_SECRET}
      - ARM_TENANT_ID=${ARM_TENANT_ID}
      - ARM_SUBSCRIPTION_ID=${ARM_SUBSCRIPTION_ID}
    entrypoint: ["sh", "-c"]
    command: ["sh run.sh"]
```
The script running inside `docker-compose` must first of all take care of the `certbot` configuration and afterwards run the correct command to create the certificate:
```sh
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
```
The certificate files will be found in the volume mount at **./docker/certbot/config/archive/myapp.myzone.mycompany.com/**

## Usage

From the repository root run:
```sh
sh run.sh
```
to run the script that creates the certificates.

The advantage of this implementation is that you do not need to install any other tools on your local machine, since everything runs inside a container.
