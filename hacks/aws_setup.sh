#!/bin/bash

CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-"podman"}"
AWS_CLI="${CONTAINER_RUNTIME} run --rm -it -e AWS_ACCESS_KEY_ID=${1} -e AWS_SECRET_ACCESS_KEY=${2} -e AWS_DEFAULT_REGION=${3} docker.io/amazon/aws-cli:latest"

aws_cmd () {
    ${AWS_CLI} ${1}
}

jq_cmd () {
    echo '#!/bin/bash' | tee tmp-jq.sh
    echo "jq ${2} /data" | tee -a tmp-jq.sh
    chmod +x tmp-jq.sh
    ${CONTAINER_RUNTIME} run -v "$PWD/${1}":/data:Z -v "$PWD/tmp-jq.sh":/usr/local/bin/tmp-jq.sh:Z -ti quay.io/biocontainers/jq:1.6 tmp-jq.sh
    rm tmp-jq.sh
}

# Create a group 
group_name="${4}-infra-management"
aws_cmd "iam get-group --group-name ${group_name}"
if [[ $? -ne 0 ]]; then 
    aws_cmd "iam create-group --group-name ${group_name}"
fi

# Create user
user_name="${4}-tstenvs"
aws_cmd "iam get-user --user-name ${user_name}"
if [[ $? -ne 0 ]]; then 
    aws_cmd "iam create-user --user-name ${user_name}"
    aws_cmd "iam create-access-key --user-name crcqe-tstenvs > access_key_info"
fi

# Add user to group
aws_cmd "iam add-user-to-group --user-name ${user_name} --group-name ${group_name}"

# Got creds for user / sa
jq_cmd access_key_info "'.AccessKey.AccessKeyId'"
jq_cmd access_key_info "'.AccessKey.SecretAccessKey'"

# Add policies to group
# Policies
AmazonVPCFullAccess_arn="arn:aws:iam::aws:policy/AmazonVPCFullAccess"
aws_cmd "iam attach-group-policy --group-name ${group_name} --policy-arn ${AmazonVPCFullAccess_arn}"
AmazonEC2FullAccess_arn="arn:aws:iam::aws:policy/AmazonEC2FullAccess"
aws_cmd "iam attach-group-policy --group-name ${group_name} --policy-arn ${AmazonEC2FullAccess_arn}"
IAMUserSSHKeys_arn="arn:aws:iam::aws:policy/IAMUserSSHKeys"
aws_cmd "iam attach-group-policy --group-name ${group_name} --policy-arn ${IAMUserSSHKeys_arn}"