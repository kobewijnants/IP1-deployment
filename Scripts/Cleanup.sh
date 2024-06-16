#!/bin/bash

#########################
# Author: Kobe Wijnants #
#########################

main() {
    # Initialize config.sh
    print_blue "Initializing config.sh"
    source config.sh

    # Check for gcloud installation
    check_gcloud_installation

    # Choose project
    choose_project

    # Set the active project
    gcloud config set project "$chosen_project"

    # Delete load balancer
    delete_load_balancer

    # Delete compute engine template and instances
    delete_compute_engine_template_instances

    # Delete Secret Manager secret for env-var and service account key
    delete_secret_manager

    # Delete storage bucket
    delete_bucket

    # Delete redis instance
    delete_redis

    # Delete Cloud SQL instance and database
    delete_database

    # Delete firewall rules
    delete_firewall

    # Delete network for the instances
    delete_network

    # Delete and unlink service account
    delete_service_account
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

print_yellow() {
    echo -e "\e[33m$1\e[0m"
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

choose_project() {
    # List all projects
    print_blue "Fetching list of projects..."
    gcloud projects list

    print_blue "Please enter the project ID you want to use:"
    read chosen_project

    # Set the project
    gcloud config set project $chosen_project
    print_green "Project set to $chosen_project"
}

delete_load_balancer() {
    local BACKEND_SERVICE_NAME=phygital-backend-service
    local HEALTH_CHECK_NAME=phygital-health-check
    local URL_MAP_NAME=phygital-url-map
    local TARGET_PROXY_NAME=phygital-target-proxy
    local FORWARDING_RULE_NAME=phygital-forwarding-rule
    if [[ $HTTPS == true ]]; then
        print_blue "Deleting load balancer..."
        gcloud compute forwarding-rules delete $FORWARDING_RULE_NAME --quiet --global
        gcloud compute target-https-proxies delete $TARGET_PROXY_NAME --quiet
        gcloud compute url-maps delete $URL_MAP_NAME --quiet
        gcloud compute backend-services delete $BACKEND_SERVICE_NAME --quiet --global
        gcloud compute health-checks delete $HEALTH_CHECK_NAME --quiet
        gcloud compute ssl-certificates delete ssl-cert --quiet
        
    else
        print_blue "Deleting load balancer..."
        gcloud compute forwarding-rules delete $FORWARDING_RULE_NAME --quiet --global
        gcloud compute target-http-proxies delete $TARGET_PROXY_NAME --quiet
        gcloud compute url-maps delete $URL_MAP_NAME --quiet
        gcloud compute backend-services delete $BACKEND_SERVICE_NAME --quiet --global
        gcloud compute health-checks delete $HEALTH_CHECK_NAME --quiet
    fi
}

delete_compute_engine_template_instances() {
    print_blue "Deleting compute engine template and instances..."
    gcloud compute instance-groups managed delete $GROUP_NAME --zone $ZONE --quiet
    gcloud compute instance-templates delete phygital-template --quiet
}

delete_secret_manager() {
    print_blue "Deleting Secret Manager secret for env-var and service account key..."
    gcloud secrets delete phygital-secrets --quiet
    gcloud secrets delete service-account-key --quiet
}

delete_bucket() {
    print_blue "Deleting storage bucket..."
    gsutil rm -r gs://$BUCKET_NAME
}

delete_redis() {
    print_blue "Deleting Redis instance..."
    gcloud redis instances delete phygital-redis --region=$REGION --quiet
}

delete_database() {
    print_blue "Deleting Cloud SQL instance and database..."
    gcloud sql instances delete $DB_INSTANCE_NAME --quiet
}

delete_firewall() {
    print_blue "Deleting firewall rules..."
    gcloud compute firewall-rules delete allow-ssh-phygital --quiet
    gcloud compute firewall-rules delete allow-health-check-phygital --quiet
    gcloud compute firewall-rules delete allow-icmp-phygital --quiet
    gcloud compute firewall-rules delete allow-http-phygital --quiet
    gcloud compute firewall-rules delete allow-https-phygital --quiet
}

delete_network() {
    print_blue "Deleting network of the instances..."
    gcloud compute networks delete $NETWORK_NAME --quiet
}

delete_service_account() {
    print_blue "Deleting and unlinking service account..."
    # delete storage admin
    gcloud projects remove-iam-policy-binding $chosen_project --member=serviceAccount:$SERVICE_ACCOUNT_NAME1@$chosen_project.iam.gserviceaccount.com --role=roles/storage.objectAdmin
    gcloud iam service-accounts delete $SERVICE_ACCOUNT_NAME1@$chosen_project.iam.gserviceaccount.com --quiet
    # delete secret accesor
    gcloud projects remove-iam-policy-binding $chosen_project --member=serviceAccount:$SERVICE_ACCOUNT_NAME2@$chosen_project.iam.gserviceaccount.com --role=roles/secretmanager.secretAccessor
    gcloud iam service-accounts delete $SERVICE_ACCOUNT_NAME2@$chosen_project.iam.gserviceaccount.com --quiet
}

main

