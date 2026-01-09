#!/bin/sh
echo "Starting deployment process..."

echo "Creating Working Directory"
mkdir ~/docker
workdir=~/docker
cd $workdir || exit


echo "Update the package list and install system upgrades"
sudo apt update && sudo apt upgrade -y

echo "Installing Docker dependencies and adding Docker's official GPG key and repository"
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "Setting up the Docker repository"
sudo echo  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update

echo "Installing Docker Engine and Docker Compose"
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin


echo "Creating Working Directory for MISP"
mkdir -p ${workdir}/MISP
cd ${workdir}/MISP
echo "Downloading the MISP docker-compose.yml file"
wget https://raw.githubusercontent.com/labs-practicals/SOC/refs/heads/main/MISP/docker-compose.yml


echo "Starting MISP services using Docker Compose"
sudo docker compose up -d

echo "Misp Deployment process completed."