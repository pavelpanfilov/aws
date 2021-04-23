#!/bin/bash
set -e

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | awk '{print substr($1, 0, length($1)-1)}')
VOLUME_ID=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID}  --region  $REGION --query  Reservations[].Instances[].BlockDeviceMappings[].Ebs[].VolumeId | tr -d  '"[]\n ')
ID_FROM_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 | cut -d "." -f3-4 | sed 's/\./-/g')
AUTO_SCALING_GROUP_NAME=$(aws ec2 describe-tags \
  --output text \
  --filters "Name=resource-id,Values=${INSTANCE_ID}" \
            "Name=key,Values=aws:autoscaling:groupName" \
  --region "${REGION}" \
  --query "Tags[*].Value")
TAG_NAME="$AUTO_SCALING_GROUP_NAME-$ID_FROM_IP"


function tag_name_it {
    /usr/bin/aws ec2 create-tags --region $REGION --resources ${INSTANCE_ID} --tags Key="Name",Value="${TAG_NAME}"
}

function tag_ebs_it {
    if [[ $(cat /proc/version ) =~ "ubuntu" ]]
    then
        TAGS=$( aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --region $REGION --query Reservations[].Instances[].Tags[] | sed -e 's/: /=/g' | tr -d '[]{}"\n' | sed -e 's/, *Value/\nValue/g'  | awk '!/aws:/' | sed -e 's/ *Value/,Value/g' | sed -e 's/Key=/Key="/g' | tr -d '[:space:]' | sed -e 's/,Value=/",Value="/g'  | sed -e 's/,Key/" Key/g' )'"'
    else
        TAGS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --region   $REGION --query Reservations[].Instances[].Tags[] | sed 's/: /=/g' | tr -d '[]{}"\n'  | sed 's/, *Value/\nValue/g'  | awk '!/aws:/' |sed 's/Value=/Value="/' |sed 's/, */",/' |sed 's/ *$//g' | sed ':a;N;$!ba;s/\n/ /g' )
    fi
    
    for V in $(echo $VOLUME_ID | tr "," "\n")
        do
            /usr/bin/aws ec2 create-tags --resources $V --region $REGION  --tags ${TAGS}
    done
}


if [ ! -z $AUTO_SCALING_GROUP_NAME ]; then
    tag_name_it;
    tag_ebs_it;
else
    echo "Not apply tag_name_it for Ubuntu instance"
    tag_ebs_it;
fi