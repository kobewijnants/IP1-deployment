#!/usr/bin/env bash

#########################
# Author: Kobe Wijnants #
#########################

main() {
    check_gcloud_installation

    # Initializing config.sh
    print_blue "Initializing config.sh"
    source config.sh

    choose_project

    choose_instance

    choose_backup

    restore
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

choose_backup() {
    # List all backup files
    print_blue "Fetching list of backup files..."
    gcloud sql backups list --instance=$chosen_instance

    print_blue "Please enter the backup ID you want to restore:"
    read chosen_backup
}

restore() {
    # Restore
    print_blue "Starting restore..."
    gcloud sql backups restore $chosen_backup --restore-instance=$chosen_instance || { print_red "ERROR: Restore failed!"; exit 1; }
    print_green "Restore completed successfully!"
}

main
