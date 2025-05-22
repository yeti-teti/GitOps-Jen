# sudo sysctl -w vm.max_map_count=262144
# sudo sysctl -w fs.file-max=65536
# Check current limits
# ulimit -n # open files
# ulimit -u # max user processes

sudo apt-get update
curl -sSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

# Create Docker Volume
sudo docker volume create sonarqube_data
sudo docker volume create sonarqube_logs
sudo docker volume create sonarqube_extensions

sudo docker pull sonarqube:lts-community
sudo docker run -d --name sonarqube \
    -p 9000:9000 \
    -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
    -v sonarqube_data:/opt/sonarqube/data \
    -v sonarqube_logs:/opt/sonarqube/logs \
    -v sonarqube_extensions:/opt/sonarqube/extensions \
    sonarqube:lts-community

# sudo docker logs -f sonarqube

# Check firewall
# sudo ufw allow 9000/tcp
