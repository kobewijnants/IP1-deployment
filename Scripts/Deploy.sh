#!/bin/bash

#########################
# Author: Kobe Wijnants #
#########################

main() {
    check_gcloud_installation

    # Initializing config.sh
    print_blue "Initializing config.sh"
    source config.sh

    # Create project and set active
    create_project

    # Link billing account to project
    link_billing

    # Enable needed APIs
    enable_api

    # Create and link the service account
    create_link_service_account

    # Create network for the instances
    create_network

    # Create firewall rules
    setup_firewall

    # Create Cloud SQL instance and database
    create_database

    # Create redis instance
    create_redis

    # Create storage bucket
    create_bucket

    # Fill in rest of variables
    other_var

    # Create Secret Manager secret for env-var and service account key
    create_secret_manager

    # Create compute engine template and instances
    create_compute_engine_template_instances

    # Create and setup load balancer
    create_loadbalancer
}

print_blue() {
    echo -e "\e[34m$1\e[0m"
}

print_green() {
    echo -e "\e[32m$1\e[0m"
}

print_red() {
    echo -e "\e[31m$1\e[0m"
}

check_gcloud_installation() {
    # Check for gcloud installation
    if ! command -v gcloud &>/dev/null; then
        print_red "ERROR: gcloud is not installed. Please install it from https://cloud.google.com/sdk/docs/install"
        exit 1
    fi

    # Check for active gcloud login
    gcloud config get-value account &>/dev/null
    if [[ $? -ne 0 ]]; then
        print_red "ERROR: You are not logged in to gcloud. Please run 'gcloud auth login' to authenticate."
        exit 1
    fi
}

create_project() {
    # Create Google Cloud project (if it doesn't exist)
    print_blue "Creating project: $PROJECT_ID"
    gcloud projects list | grep -q "$PROJECT_ID" || {
        gcloud projects create "$PROJECT_ID" || {
            print_red "Error creating project. Exiting..."
            exit 1
        }
    }

    # Set project as active
    print_blue "Setting $PROJECT_ID as active"
    gcloud config set project "$PROJECT_ID"
}

link_billing() {
    # Enable Billing account
    print_blue "Linking billing account"
    BILLING_ACCOUNT=$(gcloud billing accounts list \
        --format="value(ACCOUNT_ID)" | head -n 1)
    echo "Account: $BILLING_ACCOUNT"
    gcloud billing projects link "$(gcloud config get-value project)" \
        --billing-account="$BILLING_ACCOUNT"
}

enable_api() {
    print_blue "Enabling compute engine api"
    gcloud services enable compute.googleapis.com || {
        print_red "Error enabling Compute Engine API. Exiting..."
        exit 1
    }
    print_blue "Enabling IAM API"
    gcloud services enable iam.googleapis.com || {
        print_red "Error enabling IAM API. Exiting..."
        exit 1
    }
    print_blue "Enabling Secret Manager API"
    gcloud services enable secretmanager.googleapis.com || {
        print_red "Error enabling Secret Manager API. Exiting..."
        exit 1
    }
    print_blue "Enabling sql admin API"
    gcloud services enable sqladmin.googleapis.com || {
        print_red "Error enabling SQL Admin API. Exiting..."
        exit 1
    }

    print_blue "Enabling cloudrecource API"
    gcloud services enable cloudresourcemanager.googleapis.com || {
        print_red "Error enabling Cloud Resource API. Exiting..."
        exit 1
    }

    print_blue "Enabling redis API"
    gcloud services enable redis.googleapis.com || {
        print_red "Error enabling Redis API. Exiting..."
        exit 1
    }
}

create_link_service_account() {
    # Create service account for storage.objectAdmin
    print_blue "Creating service account for storage.objectAdmin"
    if ! gcloud iam service-accounts list --project="$PROJECT_ID" | grep -q "$SERVICE_ACCOUNT_NAME1"; then
        gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME1" \
            --description="Service account for storage admin" \
            --display-name="$SERVICE_ACCOUNT_NAME1"
    else
        echo "Service account $SERVICE_ACCOUNT_NAME1 already exists"
    fi

    # Get service account name
    print_blue "Getting service account name"
    SERVICE_ACCOUNT1=$(gcloud iam service-accounts list --project="$PROJECT_ID" | grep "$SERVICE_ACCOUNT_NAME1" | awk '{print $2}')
    echo "Service account: $SERVICE_ACCOUNT1"

    # Create IAM policy binding for storage.objectAdmin
    print_blue "Creating IAM policy binding for storage.objectAdmin"
    if ! gcloud projects get-iam-policy "$PROJECT_ID" 2>/dev/null | grep -q "$SERVICE_ACCOUNT_NAME1"; then
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SERVICE_ACCOUNT1" \
            --role="roles/storage.objectAdmin" 2>/dev/null || {
            print_red "Error creating IAM policy binding for storage.objectAdmin. Exiting..."
            exit 1
        }
    else
        echo "IAM policy binding for storage.objectAdmin already exists"
    fi

    # Create service account for secretmanager.SecretAccessor
    print_blue "Creating service account for secretmanager.SecretAccessor"
    if ! gcloud iam service-accounts list --project="$PROJECT_ID" | grep -q "$SERVICE_ACCOUNT_NAME2"; then
        gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME2" \
            --description="Service account for secret accessor" \
            --display-name="$SERVICE_ACCOUNT_NAME2"
    else
        echo "Service account $SERVICE_ACCOUNT_NAME2 already exists"
    fi

    # Get service account name
    print_blue "Getting service account name"
    SERVICE_ACCOUNT2=$(gcloud iam service-accounts list --project="$PROJECT_ID" | grep "$SERVICE_ACCOUNT_NAME2" | awk '{print $2}')
    echo "Service account: $SERVICE_ACCOUNT2"

    # Create IAM policy binding for secretmanager.SecretAccessor
    print_blue "Creating IAM policy binding for secretmanager.SecretAccessor"
    if ! gcloud projects get-iam-policy "$PROJECT_ID" 2>/dev/null | grep -q "$SERVICE_ACCOUNT_NAME2"; then
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SERVICE_ACCOUNT2" \
            --role="roles/secretmanager.secretAccessor" 2>/dev/null || {
            print_red "Error creating IAM policy binding for secretmanager.SecretAccessor. Exiting..."
            exit 1
        }
    else
        echo "IAM policy binding for secretmanager.SecretAccessor already exists"
    fi

    # Get service account json key
    print_blue "Getting service account json key"
    gcloud iam service-accounts keys create "service-account-key.json" \
        --iam-account="$SERVICE_ACCOUNT1" || {
        print_red "Error creating service account key. Exiting..."
        exit 1
    }
}

create_network() {
    # Create compute networks (with check)
    print_blue "Creating compute networks"
    if ! gcloud compute networks list 2>/dev/null | grep -q "$NETWORK_NAME"; then
        gcloud compute networks create "$NETWORK_NAME" \
            --project "$PROJECT_ID" \
            --quiet || {
            print_red "Error creating network. Exiting..."
            exit 1
        }
    else
        echo "Network $NETWORK_NAME already exists"
    fi
}

setup_firewall() {
    # firewall
    # Allow HTTP traffic
    print_blue "Creating firewall rule: allow-http-phygital"
    if ! gcloud compute firewall-rules list 2>/dev/null | grep -q "allow-http-phygital"; then
        gcloud compute firewall-rules create allow-http-phygital \
            --network "$NETWORK_NAME" \
            --allow tcp:80,tcp:5000 \
            --description "Allow HTTP traffic"
    else
        echo "Firewall rule allow-http-tcp already exists"
    fi

    # Allow HTTPS traffic
    print_blue "Creating firewall rule: allow-https-phygital"
    if ! gcloud compute firewall-rules list 2>/dev/null | grep -q "allow-https-phygital"; then
        gcloud compute firewall-rules create allow-https-phygital \
            --network "$NETWORK_NAME" \
            --allow tcp:443 \
            --description "Allow HTTPS traffic"
    else
        echo "Firewall rule allow-https-tcp already exists"
    fi

    # Allow ICMP traffic
    print_blue "Creating firewall rule: allow-icmp-phygital"
    if ! gcloud compute firewall-rules list 2>/dev/null | grep -q "allow-icmp-phygital"; then
        gcloud compute firewall-rules create allow-icmp-phygital \
            --network "$NETWORK_NAME" \
            --allow icmp \
            --description "Allow ICMP traffic"
    else
        echo "Firewall rule allow-icmp already exists"
    fi

    # Firewall for load balancer
    print_blue "Creating firewall rule for load balancer allow-health-check-phygital"
    if ! gcloud compute firewall-rules list 2>/dev/null | grep -q "allow-health-check-phygital"; then
        gcloud compute firewall-rules create allow-health-check-phygital \
            --network "$NETWORK_NAME" \
            --action=allow \
            --direction=ingress \
            --source-ranges=130.211.0.0/22,35.191.0.0/16 \
            --target-tags=allow-health-check \
            --rules=tcp:80 \
            --description="Allow health check traffic"
    else
        echo "Firewall rule allow-health-check already exists"
    fi

    # ssh firewall
    print_blue "Creating firewall rule allow-ssh-phygital"
    if ! gcloud compute firewall-rules list 2>/dev/null | grep -q "allow-ssh-phygital"; then
        gcloud compute firewall-rules create allow-ssh-phygital \
            --network "$NETWORK_NAME" \
            --allow tcp:22 \
            --description "Allow SSH traffic"
    else
        echo "Firewall rule allow-ssh already exists"
    fi
}

create_database() {
    # Create Cloud SQL instance
    print_blue "Creating Cloud SQL instance"
    if ! gcloud sql instances list | grep -q $DB_INSTANCE_NAME; then
        gcloud sql instances create "$DB_INSTANCE_NAME" \
            --project="$PROJECT_ID" \
            --region="$REGION" \
            --tier="$DB_TIER" \
            --database-version="$POSTGRES_VERSION" \
            --root-password="$POSTGRES_PASS" \
            --project="$PROJECT_ID" \
            --authorized-networks="0.0.0.0/0" || {
            print_red "Error creating Cloud SQL instance. Exiting..."
            exit 1
        }
    else
        echo "Cloud SQL instance $DB_INSTANCE_NAME already exists."
    fi

    # Create database
    if ! gcloud sql databases list --instance="$DB_INSTANCE_NAME" | grep -q "$DB_NAME"; then
        gcloud sql databases create "$DB_NAME" --instance="$DB_INSTANCE_NAME"
    else
        echo "Database $DB_NAME already exists."
    fi

    # Get external IP address
    print_blue "Getting external IP address of postgres instance"
    DB_IP=$(gcloud sql instances describe "$DB_INSTANCE_NAME" --format="value(ipAddresses.ipAddress)" | cut -d ';' -f 1)
    print_green "External IP address postgres instance: $DB_IP"

    # Update environment variable file
    print_blue "Creating environment variable file"
    set_env_var "ASPNETCORE_POSTGRES_HOST" "$DB_IP"
    set_env_var "ASPNETCORE_POSTGRES_PORT" "$POSTGRES_PORT"
    set_env_var "ASPNETCORE_POSTGRES_DB" "$DB_NAME"
    set_env_var "ASPNETCORE_POSTGRES_USER" "$POSTGRES_USER"
    set_env_var "ASPNETCORE_POSTGRES_PASS" "$POSTGRES_PASS"
}

create_redis() {
    print_blue "Creating redis instance"

    if ! gcloud redis instances list --region=$REGION | grep -q phygital-redis; then
        gcloud redis instances create phygital-redis \
            --size=1 \
            --region=$REGION \
            --redis-version=redis_6_x \
            --network=$NETWORK_NAME \
            --project=$PROJECT_ID || {
            print_red "Error creating redis instance. Exiting..."
            exit 1
        }
    fi

    REDIS_IP=$(gcloud redis instances describe phygital-redis --region=europe-west1 --format="value(host)")
    print_green "Redis IP: $REDIS_IP"
    set_env_var "REDIS" "$REDIS_IP:6379"
}

create_bucket() {
    echo "Creating bucket"
    gcloud storage buckets create gs://$BUCKET_NAME --project $PROJECT_ID --location=eu

    # Update environment variable file
    set_env_var "ASPNETCORE_STORAGE_BUCKET" "$BUCKET_NAME"
}

other_var() {
    set_env_var "TOKEN" "$TOKEN"
    set_env_var "REPO" "$REPO"
    set_env_var "GIT_DIRECTORY" "$GIT_DIRECTORY"
}

# Function to set environment variables
set_env_var() {
    var_name=$1
    var_value=$2
    sed -i "s/^$var_name=.*$/$var_name=$var_value/" env-var
}

create_secret_manager() {
    # Create Secret Manager secret
    print_blue "Creating Secret Manager secret"
    if ! gcloud secrets list | grep -q "phygital-secrets"; then
        gcloud secrets create phygital-secrets --replication-policy="automatic" --data-file=env-var
    else
        echo "Secret 'phygital-secrets' already exists."
    fi

    # Create secret manager for service account json key
    print_blue "Creating Secret Manager secret for service account key"
    if ! gcloud secrets list | grep -q "service-account-key"; then
        gcloud secrets create service-account-key --replication-policy="automatic" --data-file=service-account-key.json
    else
        echo "Secret 'service-account-key' already exists."
    fi
}

create_compute_engine_template_instances() {
    # Create compute engine template
    print_blue "Creating compute engine template"
    if ! gcloud compute instance-templates list | grep -q "phygital-template"; then
        gcloud compute instance-templates create "phygital-template" \
            --project "$PROJECT_ID" \
            --region "$REGION" \
            --machine-type "$VM_MACHINE_TYPE" \
            --boot-disk-size "10GB" \
            --network="$NETWORK_NAME" \
            --image-family "$IMAGE_FAMILY" \
            --image-project "$IMAGE_PROJECT" \
            --metadata-from-file startup-script=./Startup.sh \
            --tags=allow-http-phygital,allow-https-phygital,allow-icmp-phygital,allow-health-check-phygital,allow-ssh-phygital \
            --scopes "https://www.googleapis.com/auth/cloud-platform" \
            --service-account="$SERVICE_ACCOUNT2" || {
            print_red "Error creating compute engine template. Exiting..."
            exit 1
        }
    else
        echo "Template 'phygital-template' already exists."
    fi

    # Create Compute Engine instance groups
    print_blue "Creating compute engine instance groups"
    if ! gcloud compute instance-groups managed describe $GROUP_NAME --zone "$ZONE" &>/dev/null; then
        gcloud compute instance-groups managed create $GROUP_NAME \
            --project "$PROJECT_ID" \
            --zone "$ZONE" \
            --template "phygital-template" \
            --size "$MIN_INSTANCES"
    else
        echo "Instance group $GROUP_NAME already exists in zone $ZONE."
    fi
    print_blue "Setting autoscaling parameters"
    gcloud compute instance-groups managed set-autoscaling $GROUP_NAME \
        --zone=$ZONE \
        --min-num-replicas=$MIN_INSTANCES \
        --max-num-replicas=$MAX_INSTANCES \
        --cool-down-period=$COOL_DOWN_PERIOD \
        --target-cpu-utilization=$TARGET_CPU_UTILIZATION
}

create_loadbalancer() {
    local BACKEND_SERVICE_NAME=phygital-backend-service
    local HEALTH_CHECK_NAME=phygital-health-check
    local URL_MAP_NAME=phygital-url-map
    local TARGET_PROXY_NAME=phygital-target-proxy
    local FORWARDING_RULE_NAME=phygital-forwarding-rule

    if [[ $HTTPS == true ]]; then
        print_blue "Creating HTTPS load balancer"
        gcloud compute health-checks create http $HEALTH_CHECK_NAME --port=5000 --request-path=/health --check-interval=10s --timeout=10s
        gcloud compute backend-services create $BACKEND_SERVICE_NAME --protocol=HTTP --health-checks=$HEALTH_CHECK_NAME --global
        gcloud compute backend-services add-backend $BACKEND_SERVICE_NAME --instance-group=$GROUP_NAME --instance-group-zone=$ZONE --global
        gcloud compute instance-groups set-named-ports $GROUP_NAME --named-ports=http:5000 --zone=$ZONE
        gcloud compute url-maps create $URL_MAP_NAME --default-service=$BACKEND_SERVICE_NAME
        gcloud compute ssl-certificates create ssl-cert --domains="$record_name" --global --project=$PROJECT_ID
        gcloud compute target-https-proxies create $TARGET_PROXY_NAME --url-map=$URL_MAP_NAME --ssl-certificates=ssl-cert
        gcloud compute forwarding-rules create $FORWARDING_RULE_NAME --global --target-https-proxy=$TARGET_PROXY_NAME --ports=443
    else
        print_blue "Creating HTTP load balancer"
        gcloud compute health-checks create http $HEALTH_CHECK_NAME --port=5000 --request-path=/health --check-interval=10s --timeout=10s
        gcloud compute backend-services create $BACKEND_SERVICE_NAME --protocol=HTTP --health-checks=$HEALTH_CHECK_NAME --global
        gcloud compute backend-services add-backend $BACKEND_SERVICE_NAME --instance-group=$GROUP_NAME --instance-group-zone=$ZONE --global
        gcloud compute instance-groups set-named-ports $GROUP_NAME --named-ports=http:5000 --zone=$ZONE
        gcloud compute url-maps create $URL_MAP_NAME --default-service=$BACKEND_SERVICE_NAME
        gcloud compute target-http-proxies create $TARGET_PROXY_NAME --url-map=$URL_MAP_NAME
        gcloud compute forwarding-rules create $FORWARDING_RULE_NAME --global --target-http-proxy=$TARGET_PROXY_NAME --ports=80
    fi

    # Get the IP address of the load balancer
    LOAD_BALANCER_IP=$(gcloud compute forwarding-rules describe $FORWARDING_RULE_NAME --global --format="get(IPAddress)")
    print_green "Load balancer IP: $LOAD_BALANCER_IP"
    ./ddns.sh "$LOAD_BALANCER_IP"
}

main

exit 0
