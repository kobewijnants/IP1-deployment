#!/usr/bin/env bash

#########################
# Author: Kobe Wijnants #
#########################

while getopts "p:i:" option; do
    case "${option}" in
    p)
        chosen_project=${OPTARG};;
    i)
        chosen_instance=${OPTARG};;
    esac
done

main() {
    check_gcloud_installation

    # Initializing config.sh
    print_blue "Initializing config.sh"
    source config.sh

    if [[ -z $chosen_project ]]; then
        choose_project
    fi

    if [[ -z $chosen_instance ]]; then
        choose_instance
    fi

    create_backup
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

choose_instance() {
    # List all instances
    print_blue "Fetching list of instances..."
    gcloud sql instances list

    print_blue "Please enter the instance name you want to use:"
    read chosen_instance
}

create_backup() {
    # Backup
    echo "Starting backup..."
    gcloud sql backups create --async --instance=$chosen_instance --location=$REGION || {
        print_red "ERROR: Backup failed!"
        exit 1
    }
    print_green "Backup completed successfully!"
}

main
