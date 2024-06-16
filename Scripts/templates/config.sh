#!/usr/bin/env bash

# Define project and VM details (replace with your values)
PROJECT_ID="project_id"
REGION="europe-west1"      
ZONE="europe-west1-b"      
VM_MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
GROUP_NAME="phygital-group"

MIN_INSTANCES="2"
MAX_INSTANCES="5"
TARGET_CPU_UTILIZATION="0.8"
COOL_DOWN_PERIOD="180"

# Network
NETWORK_NAME="phygital-network"

# Bucket
BUCKET_NAME="bucket-$PROJECT_ID"

# Database details
DB_INSTANCE_NAME="phygital-db-instance"
DB_NAME="phygital-db"
DB_TIER="db-g1-small"
POSTGRES_VERSION="POSTGRES_15"
POSTGRES_USER="postgres"
POSTGRES_PASS="postgres123"
POSTGRES_PORT="5432"

# Service account
SERVICE_ACCOUNT_NAME1="storage-admin"
SERVICE_ACCOUNT_NAME2="secret-accessor"

# loadbalancer
HTTPS=true

#GIT
TOKEN=git_access_token
REPO=git_repo
GIT_DIRECTORY=root_dir_repo

# Cloudflare
auth_email="example@gmail.com"                      # The email used to login 'https://dash.cloudflare.com'
auth_method="token"                                 # Set to "global" for Global API Key or "token" for Scoped API Token
auth_key="token123"                                 # Your API Token or Global API Key
zone_identifier="zone_identifier"                   # Can be found in the "Overview" tab of your domain
record_name="example.com"                           # Which record you want to be synced
ttl="60"                                            # Set the DNS TTL (seconds)
proxy="false"                                       # Set the proxy to true or false
sitename="example"                                 # Title of site "Example Site"
