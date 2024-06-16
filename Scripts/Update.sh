#!/bin/bash

#########################
# Author: Kobe Wijnants #
#########################

main() {
    check_gcloud_installation

    # Initializing config.sh
    print_blue "Initializing config.sh"
    source config.sh

    choose_project

    update
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

update() {
    print_blue "SSH'ing in every machine and updating one at a time"
    instances=$(gcloud compute instances list --filter="zone:$ZONE AND name:$GROUP_NAME" --format="value(name)")
    for instance_name in $instances; do
        instance_name=$(echo "$instance_name" | tr -d '\n')
        
        # Check if the instance still exists
        gcloud compute instances describe $instance_name --zone=$ZONE || {
        echo "$instance_name does not exist anymore"
        continue
        }

        print_blue "Updating $instance_name..."
        
        # Use scp to copy the script to the instance
        print_blue "Copying script to $instance_name..."
        gcloud compute scp --zone=$ZONE Update_instance.sh root@$instance_name:~ || {
            print_red "ERROR: Unable to copy script to $instance_name."
            exit 1
        }

        # SSH into the instance, move the script to /root, and update
        print_blue "SSH'ing into $instance_name and updating..."
        gcloud compute ssh -q root@$instance_name --zone=$ZONE --command="sudo chmod +x /root/Update_instance.sh && sudo /root/Update_instance.sh" || {
            print_red "ERROR: Unable to SSH into $instance_name OR update."
            exit 1
        }

        # Wait for the service to be active
        print_blue "Waiting for service to be active on $instance_name..."
        while true; do
            status=$(gcloud compute ssh root@$instance_name --zone=$ZONE --command="systemctl is-active phygital.service")
            if [ "$status" = "active" ]; then
                echo "Service is active on $instance_name."
                break
            else
                sleep 5
            fi
        done

        print_green "Update completed successfully on $instance_name."

    done
}

main
