#!/bin/bash
set -e

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | awk '{print substr($1, 0, length($1)-1)}')
ID_FROM_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 | cut -d "." -f3-4 | sed 's/\./-/g')
AUTO_SCALING_GROUP_NAME=$(aws ec2 describe-tags \
  --output text \
  --filters "Name=resource-id,Values=${INSTANCE_ID}" \
            "Name=key,Values=aws:autoscaling:groupName" \
  --region "${REGION}" \
  --query "Tags[*].Value")

if [ ! -z $AUTO_SCALING_GROUP_NAME ];
then
    NEWHOSTNAME="$AUTO_SCALING_GROUP_NAME-$ID_FROM_IP"
else
    NEWHOSTNAME=$(aws ec2 describe-tags --output text --filters "Name=resource-id,Values=$INSTANCE_ID" --region "$REGION" | grep -e "TAGS[[:space:]]*Name"| cut -f 5)
fi

function network_file {
    TMPFILE1=$(mktemp /tmp/temporary-file.XXXXXXXX)
    /usr/bin/sudo /bin/cat > ${TMPFILE1} << EOF
NETWORKING=yes
HOSTNAME=${NEWHOSTNAME}
NOZEROCONF=yes
EOF
    /bin/cat ${TMPFILE1} | /usr/bin/sudo tee /etc/sysconfig/network >/dev/null
}

function hostname_it {
    /usr/bin/sudo /bin/hostname ${NEWHOSTNAME}
}

function hostname_file {
    echo ${NEWHOSTNAME} > /etc/hostname
}

function hosts_file {
    TMPFILE2=$(mktemp /tmp/temporary-file.XXXXXXXX)
    /usr/bin/sudo /bin/cat > ${TMPFILE2} << EOF
127.0.0.1 localhost
127.0.0.1 ${NEWHOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1         localhost6 localhost6.localdomain6
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
    /bin/cat ${TMPFILE2} | /usr/bin/sudo tee /etc/hosts >/dev/null
}

hostname_it;
hostname_file;
hosts_file;