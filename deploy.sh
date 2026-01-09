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
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

echo "Setting up the Docker repository"
sudo echo  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update

echo "Installing Docker Engine and Docker Compose"
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "Enabling and starting Docker service"
sudo systemctl enable docker
sudo systemctl start docker 


echo "Creating Working Directory for MISP"
mkdir -p ${workdir}/MISP
cd ${workdir}/MISP

echo "Downloading the MISP docker-compose.yml file"
wget https://raw.githubusercontent.com/labs-practicals/SOC/refs/heads/main/MISP/docker-compose.yml


echo "Starting MISP services using Docker Compose"
sudo docker compose up -d

echo "Misp Deployment process completed."


echo "Creating Working Directory for Cortex"
mkdir -p ${workdir}/Cortex
cd ${workdir}/Cortex

echo "Downloading the Cortex docker-compose.yml file"
wget https://raw.githubusercontent.com/labs-practicals/SOC/refs/heads/main/CORTEX/docker-compose.yml

echo "Starting Cortex services using Docker Compose"
sudo docker compose up -d

echo "Cortex Deployment process completed."


echo "Creating Working Directory for TheHive"
mkdir -p ${workdir}/TheHive
cd ${workdir}/TheHive
echo "Downloading TheHive docker-compose.yml file"
wget https://raw.githubusercontent.com/labs-practicals/SOC/refs/heads/main/THEHIVE/docker-compose.yml

echo "Starting TheHive services using Docker Compose"
sudo docker compose up -d

echo "TheHive Deployment process completed."


echo "Creating Working Directory for Wazuh"
mkdir -p ${workdir}/Wazuh
cd ${workdir}/Wazuh
echo "Downloading Wazuh docker Config"
git clone https://github.com/wazuh/wazuh-docker.git -b v4.14.0 --single-branch

echo "Increase "max_map_count" value for Wazuh"
sudo sysctl -w vm.max_map_count=262144


echo "Generating self-signed SSL certificates for Wazuh"
cd $workdir/Wazuh/wazuh-docker/single-node
sudo docker compose -f generate-indexer-certs.yml run --rm generator

echo "Modify Wazuh configuration due to port conflict with TheHive"
sudo sed -i 's/9200:9200/9201:9200/g' docker-compose.yml


echo "Starting Wazuh services using Docker Compose"
sudo docker compose up -d


echo "Wazuh Deployment process completed."



echo "Creating SOC Network"
sudo docker network create soc

echo "Connecting MISP, Cortex, TheHive, and Wazuh to SOC Network"
sudo docker network connect soc $(sudo docker ps -qf "name=misp")
sudo docker network connect soc $(sudo docker ps -qf "name=cortex")
sudo docker network connect soc $(sudo docker ps -qf "name=thehive")
sudo docker network connect soc $(sudo docker ps -qf "name=wazuh")
echo "All components connected to SOC Network."


echo "Adding Firewall Rules for Services"
sudo ufw allow 8080/tcp    # MISP
sudo ufw allow 9000/tcp    # Cortex
sudo ufw allow 9001/tcp    # TheHive
sudo ufw allow 443/tcp     # Wazuh
sudo ufw reload
echo "Firewall rules added."



echo "Deployment process completed successfully."

echo "You can access the services at the following URLs:"
echo "MISP: http://<your_server_ip>:8080"
echo "Cortex: http://<your_server_ip>:9000"     
echo "TheHive: http://<your_server_ip>:9001"
echo "Wazuh: https://<your_server_ip>:443"




