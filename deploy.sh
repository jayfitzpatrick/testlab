#!/bin/sh
echo "Starting deployment process..."
set -euo pipefail

echo "Creating Working Directory"
workdir=$HOME/docker
mkdir -p ${workdir} 
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
wget -O docker-compose.yml https://raw.githubusercontent.com/labs-practicals/SOC/refs/heads/main/MISP/docker-compose.yml
echo "Modifying MISP docker-compose.yml to use host's IP address"
ipaddr=$(ip r | grep default | awk '{print $9}')
sed -i "s#MISP_BASEURL: http://localhost:8080#MISP_BASEURL: http://${ipaddr}:8080#g" docker-compose.yml


echo "Modifying MISP docker-compose.yml to bind to all interfaces"
sed -i 's/127.0.0.1:8080:80/8080:80/g' docker-compose.yml

echo "Starting MISP services using Docker Compose"
sudo docker compose up -d

echo "Misp Deployment process completed."


echo "Creating Working Directory for Cortex"
mkdir -p ${workdir}/Cortex
cd ${workdir}/Cortex

echo "Downloading the Cortex docker-compose.yml file"
wget -O docker-compose.yml https://raw.githubusercontent.com/labs-practicals/SOC/refs/heads/main/CORTEX/docker-compose.yml

echo "Starting Cortex services using Docker Compose"
sudo docker compose up -d

echo "Cortex Deployment process completed."


echo "Creating Working Directory for TheHive"
mkdir -p ${workdir}/TheHive
cd ${workdir}/TheHive
echo "Downloading TheHive docker-compose.yml file"
wget -O docker-compose.yml https://raw.githubusercontent.com/labs-practicals/SOC/refs/heads/main/THEHIVE/docker-compose.yml

echo "Starting TheHive services using Docker Compose"
sudo docker compose up -d

echo "TheHive Deployment process completed."


echo "Creating Working Directory for Wazuh"
mkdir -p ${workdir}/Wazuh
cd ${workdir}/Wazuh
echo "Downloading Wazuh docker Config"
if [ ! -d "wazuh-docker" ]; then
    git clone https://github.com/wazuh/wazuh-docker.git -b v4.14.0 --single-branch
else
    echo "wazuh-docker directory already exists, skipping clone"
fi

echo "Increase "max_map_count" value for Wazuh"
sudo sysctl -w vm.max_map_count=262144


echo "Generating self-signed SSL certificates for Wazuh"
cd $workdir/Wazuh/wazuh-docker/single-node
ps -f $$  # shows the current shell
sudo docker compose -f generate-indexer-certs.yml run --rm generator  >/dev/null 2>&1 < /dev/null || true
ps -f $$  # if this line never prints, shell was replaced


echo "Modify Wazuh configuration due to port conflict with TheHive"
sudo sed -i 's/9200:9200/9201:9200/g' docker-compose.yml


echo "Starting Wazuh services using Docker Compose"
sudo docker compose up -d


echo "Wazuh Deployment process completed."



echo "Creating SOC Network..."

if ! sudo docker network inspect soc >/dev/null 2>&1; then
    sudo docker network create soc
    echo "SOC network created."
else
    echo "SOC network already exists, skipping creation."
fi

echo "Connecting MISP, Cortex, TheHive, and Wazuh to SOC Network..."

services=("misp" "cortex" "thehive" "wazuh")
network="soc"

for svc in "${services[@]}"; do
    container_ids=$(sudo docker ps -qf "name=$svc")
    if [ -n "$container_ids" ]; then
        for cid in $container_ids; do
            # Human-readable container name
            cname=$(sudo docker inspect -f '{{.Name}}' "$cid" | sed 's/^\/\+//')

            # Check if container is already connected to the network
            connected=$(sudo docker inspect -f \
                '{{if .NetworkSettings.Networks.'$network'}}yes{{else}}no{{end}}' "$cid")

            if [ "$connected" = "no" ]; then
                sudo docker network connect "$network" "$cid"
                echo "Connected $cname ($cid) to SOC network."
            else
                echo "$cname ($cid) is already connected, skipping."
            fi
        done
    else
        echo "No running container found for $svc, skipping."
    fi
done

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


# Lists container names and IPs for containers attached to the SOC network.

services=("misp" "cortex" "thehive" "wazuh")
network="soc"

echo "Listing container names and SOC network IPs:"

for svc in "${services[@]}"; do
    container_ids=$(sudo docker ps -qf "name=$svc")
    if [ -n "$container_ids" ]; then
        for cid in $container_ids; do
            cname=$(sudo docker inspect -f '{{.Name}}' "$cid" | sed 's/^\/\+//')
            
            # Get IP for the network by name
            ip=$(sudo docker inspect -f \
                "{{with index .NetworkSettings.Networks \"$network\"}}{{.IPAddress}}{{end}}" \
                "$cid")
            
            echo "$cname:$ip"
        done
    fi
done


