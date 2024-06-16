#!/usr/bin/env bash

#########################
# Author: Kobe Wijnants #
#########################

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

# Function to list projects in the current directory
list_projects() {
  print_blue "Available projects:"
  gcloud projects list --format="value(projectId)"
}
 
# Function to validate project ID
validate_project_id() {
  local input=$1
  local projects=$2

  # Check if input exactly matches a project ID
  if ! grep -q "^$input$" <<< "$projects"; then
    print_red "Error: Project ID does not match any available projects."
    return 1
  fi
  return 0
}

#Check for gcloud installation
if ! command -v gcloud &>/dev/null; then
    print_red "ERROR: gcloud is not installed. Please install it from https://cloud.google.com/sdk/docs/install"
    exit 1
fi

#Check for active gcloud login
gcloud config get-value account &>/dev/null
if [[ $? -ne 0 ]]; then
    print_red "ERROR: You are not logged in to gcloud. Please run 'gcloud auth login' to authenticate."
    exit 1
fi

list_projects

# Prompt user to enter the project ID
print_yellow 'Please copy the ID of the project you want to delete: '
read project_id

# List available projects for validation
projects=$(gcloud projects list --format="value(projectId)")

# Validate project ID
validate_project_id "$project_id" "$projects" 
if [[ $? -ne 0 ]]; then
  exit 1
fi

# Prompt for confirmation
print_yellow "Are you sure you want to delete the project '$project_id'? (y/N)"
read confirm

  # Proceed only if confirmed
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  print_red "Project deletion canceled."
else
    
  # Print a warning message before deletion
  print_yellow "WARNING: This will permanently delete the project '$project_id' and all its contents."

  # Delete the project
  gcloud projects delete "$project_id"
  print_yellow "Project '$project_id' has been deleted."
fi