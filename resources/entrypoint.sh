#!/bin/bash

echo "Genarate JENKINS SSH KEY and add it to bitbucket"

host=$BITBUCKET_HOSTNAME
port=$BITBUCKET_PORT
username=$BITBUCKET_JENKINS_USERNAME
password=$BITBUCKET_JENKINS_PASSWORD
nohup /usr/share/jenkins/ref/adop\_scripts/generate_key.sh -c ${host} -p ${port} -u ${username} -w ${password} &

echo "skip upgrade wizard step after installation"
echo "2.7.4" > /var/jenkins_home/jenkins.install.UpgradeWizard.state

echo "start JENKINS"

chown -R 1000:1000 /var/jenkins_home
su jenkins -c /usr/local/bin/jenkins.sh
