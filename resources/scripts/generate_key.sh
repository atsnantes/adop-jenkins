#!/bin/bash
set -e

# Usage
usage() {
    echo "Usage:"
    echo "    ${0} -c <host> -p <port> -u <username> -w <password>"
    exit 1
}

# Constants
SLEEP_TIME=5
MAX_RETRY=10
BASE_JENKINS_KEY="adop/core/jenkins"
BASE_JENKINS_SSH_KEY="${BASE_JENKINS_KEY}/ssh"
BASE_JENKINS_SSH_PUBLIC_KEY_KEY="${BASE_JENKINS_SSH_KEY}/public_key"
JENKINS_HOME="/var/jenkins_home"
JENKINS_SSH_DIR="${JENKINS_HOME}/.ssh"
JENKINS_USER_CONTENT_DIR="${JENKINS_HOME}/userContent/"

while getopts "c:p:u:w:" opt; do
  case $opt in
    c)
      host=${OPTARG}
      ;;
    p)
      port=${OPTARG}
      ;;
    u)
      username=${OPTARG}
      ;;
    w)
      password=${OPTARG}
      ;;
    *)
      echo "Invalid parameter(s) or option(s)."
      usage
      ;;
  esac
done

if [ -z "${host}" ] || [ -z "${port}" ] || [ -z "${username}" ] || [ -z "${password}" ]; then
    echo "Parameters missing"
    usage
fi

echo "Generating Jenkins Key Pair"
if [ ! -d "${JENKINS_SSH_DIR}" ]; then mkdir -p "${JENKINS_SSH_DIR}"; fi
cd "${JENKINS_SSH_DIR}"

if [[ ! $(ls -A "${JENKINS_SSH_DIR}") ]]; then 
  ssh-keygen -t rsa -f 'id_rsa' -b 4096 -C "jenkins@adop-core" -N ''; 
  echo "Copy key to userContent folder"
  mkdir -p ${JENKINS_USER_CONTENT_DIR}
  rm -f ${JENKINS_USER_CONTENT_DIR}/id_rsa.pub
  cp ${JENKINS_SSH_DIR}/id_rsa.pub ${JENKINS_USER_CONTENT_DIR}/id_rsa.pub

  # Set correct permissions for Content Directory
  chown 1000:1000 "${JENKINS_USER_CONTENT_DIR}"
  
  # Put bitbucket into the known host list
  ssh-keyscan -H -p 7999 -t rsa bitbucket > ${JENKINS_SSH_DIR}/known_hosts
fi

# Getting key content
public_key_val=$(cat ${JENKINS_SSH_DIR}/id_rsa.pub)

# Set correct permissions on SSH Key
chown -R 1000:1000 "${JENKINS_SSH_DIR}"

echo "Testing Bitbucket Connection"
# Init basic auth
bitbucket_token=$(echo -n "${username}:${password}" | base64)

until curl -sL -w "\\n%{http_code}\\n" -H "Authorization: Basic $bitbucket_token" "http://${host}:${port}/bitbucket/projects" -o /dev/null | grep "200" &> /dev/null
do
    echo "Bitbucket unavailable, sleeping for ${SLEEP_TIME}"
    sleep "${SLEEP_TIME}"
done

echo "Bitbucket available, adding data"

cat <<EOF > key.json
{
    "text": "$public_key_val"
}
EOF

count=1
until [ $count -ge ${MAX_RETRY} ]
do

  ret=$(curl -X POST --write-out "%{http_code}" --silent --output /dev/null \
          -H "Authorization: Basic $bitbucket_token" \
          -H "Content-Type: application/json" \
          --data @key.json "http://${host}:${port}/bitbucket/rest/ssh/1.0/keys?user=$username")
 
  # 201 = key added, 409 = key already exists
  [[ ${ret} -eq 201  || ${ret} -eq 409  ]] && break
  count=$[$count+1]
  echo "Unable to add jenkins public key on bitbucket, response code ${ret}, retry ... ${count}"
  sleep ${SLEEP_TIME}
done
