#!/usr/bin/env bash

#########################
# Author: Kobe Wijnants #
#########################

set -x

# Check if the startup script has already been run
if [ -f /root/.startup_complete ]; then
    echo "Startup script has already been run."
    exit 0
fi

# Access secrets and write to a temporary file
gcloud secrets versions access latest --secret="phygital-secrets" > /tmp/secrets

# Loop through the file and export each line as an environment variable
while IFS= read -r line
do
    # If the line starts with a '#', skip it
    if [[ $line != \#* ]]; then
        export "$line"
        echo "export $line" >> ~/.bashrc
    fi
done < /tmp/secrets

source ~/.bashrc

# Check if the environment variables are set
if [ -z "${!REPO}" ]; then
    echo "Environment variables do not exist."
    exit 1
fi

# Remove the temporary file
rm /tmp/secrets

# Create the user if it doesn't exist
if ! id -u phygital &>/dev/null; then
    useradd -s /bin/bash -md /home/phygital phygital
    echo "phygital:phygital" | chpasswd
    usermod -aG sudo phygital
fi

cd /home/phygital || { echo "Directory not found /home/phygital"; exit 1; }

# Get service account key
export GOOGLE_APPLICATION_CREDENTIALS="/home/phygital/service-account-key.json"
gcloud secrets versions access latest --secret="service-account-key" > $GOOGLE_APPLICATION_CREDENTIALS

# Installing requirements
apt-get update -yq && apt-get upgrade -yq && apt-get install -yq git

# Installing ops agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install
systemctl restart google-cloud-ops-agent"*"


# Installing nodejs
cd /root || { echo "Directory not found /root"; exit 1; }
wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.39.0/install.sh | bash
. /.nvm/nvm.sh && nvm install 20.11.1

# Installing dotnet
curl https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get install -y dotnet-sdk-8.0

# Cloning the repository
echo "Cloning the repository..."
git clone -b main "https://oath2:glpat-$TOKEN@$REPO" /home/phygital/$GIT_DIRECTORY
git config --global --add safe.directory /home/phygital/dotnet
mv $GOOGLE_APPLICATION_CREDENTIALS /home/phygitall/$GIT_DIRECTORY/UI-MVC
sudo chown -R phygital:phygital /home/phygital/$GIT_DIRECTORY

mkdir -p /home/phygital/app

cd /home/phygital/$GIT_DIRECTORY/UI-MVC/ClientApp || { echo "Directory not found /home/phygital/$GIT_DIRECTORY/UI-MVC/ClientApp"; exit 1; }

. /.nvm/nvm.sh && npm rebuild && npm install && npm install @types/webspeechapi --save-dev && npm install chart.js && npm run build

cd /home/phygital/$GIT_DIRECTORY || { echo "Directory not found /home/phygital/$GIT_DIRECTORY"; exit 1; }

export DOTNET_CLI_HOME=/
export HOME=/
dotnet publish "/home/phygital/$GIT_DIRECTORY/UI-MVC/UI-MVC.csproj" -c Release -o /home/phygital/app/

mkdir -p /var/www/phygital
chmod -R 755 /var/www/phygital
chown -R www-data:www-data /var/www/phygital

# Copying the app folder to /var/www/phygital
mkdir -p /var/www/phygital/app
cp -r /home/phygital/app/* /var/www/phygital/app

# Running the project
# /root/.dotnet/dotnet out/DN.UI.Web.dll  --urls "http://0.0.0.0:80"

# Running the project using systemd
echo "Creating systemd service..."
tee /etc/systemd/system/phygital.service <<EOF
[Unit]
Description=phygital-dotnet-app

[Service]
WorkingDirectory=/home/phygital/dotnet/UI-MVC
ExecStart=/usr/bin/dotnet /var/www/phygital/app/DN.UI.Web.dll --urls "http://0.0.0.0:5000"
Restart=on-failure
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=phygital
User=phygital

Environment="ASPNETCORE_ENVIRONMENT=Production"
Environment="ASPNETCORE_POSTGRES_HOST=$ASPNETCORE_POSTGRES_HOST"
Environment="ASPNETCORE_POSTGRES_PORT=$ASPNETCORE_POSTGRES_PORT"
Environment="ASPNETCORE_POSTGRES_DB=$ASPNETCORE_POSTGRES_DB"
Environment="ASPNETCORE_POSTGRES_USER=$ASPNETCORE_POSTGRES_USER"
Environment="ASPNETCORE_POSTGRES_PASS=$ASPNETCORE_POSTGRES_PASS"
Environment="ASPNETCORE_CONTENTROOT=$ASPNETCORE_CONTENTROOT"
Environment="ASPNETCORE_STORAGE_BUCKET=$ASPNETCORE_STORAGE_BUCKET"
Environment="GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS"
Environment="REDIS=$REDIS"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

systemctl enable phygital.service

systemctl start phygital.service

# Create a file to indicate that the startup script has been run
touch /root/.startup_complete
