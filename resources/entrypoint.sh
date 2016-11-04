#!/bin/bash

echo "Genarate JENKINS SSH KEY and add it to bitbucket"

nohup /usr/share/jenkins/ref/adop\_scripts/generate_key.sh -c $BITBUCKET_HOSTNAME -u $BITBUCKET_JENKINS_USERNAME -w $BITBUCKET_JENKINS_PASSWORD &

echo "skip upgrade wizard step after installation"
echo "2.7.4" > /var/jenkins_home/jenkins.install.UpgradeWizard.state

echo "start JENKINS"

chown -R 1000:1000 /var/jenkins_home
su jenkins -c /usr/local/bin/jenkins.sh
