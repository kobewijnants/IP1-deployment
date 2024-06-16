#!/bin/bash

#########################
# Author: Kobe Wijnants #
#########################

set -x

# Stop de service
systemctl stop phygital.service

cd /home/phygital/dotnet || { echo "Directory not found"; exit 1;}

# Fetch the latest changes
git config --global --add safe.directory /home/phygital/dotnet
git fetch origin
git reset --hard origin/main

# Restore the dotnet project
dotnet restore /home/phygital/dotnet/UI-MVC/UI-MVC.csproj

# Build the client app
cd /home/phygital/dotnet/UI-MVC/ClientApp || { echo "Directory not found"; exit 1;}
. /.nvm/nvm.sh && npm rebuild && npm install && npm install @types/webspeechapi --save-dev && npm install chart.js && npm run build

# Go back to the root of the project
cd ../..

# Remove the old app folder
rm -rf /home/phygital/app && rm -rf /var/www/phygital/app

# Publish the project
dotnet publish "/home/phygital/dotnet/UI-MVC/UI-MVC.csproj" -c Release -o /home/phygital/app/

# Move the published project to the correct folder
mv /home/phygital/app /var/www/phygital/

# Start the service
systemctl start phygital.service
