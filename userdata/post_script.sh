MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
echo "Running custom user data script"

export prefix=ksy
export env=dev
export dev_id=sy_kim
export region=ap-southeast-3
export token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export instance_ip=$(curl -s -H "X-aws-ec2-metadata-token: ${token}" http://169.254.169.254/latest/meta-data/local-ipv4)
export instance_id=$(curl -s -H "X-aws-ec2-metadata-token: ${token}" http://169.254.169.254/latest/meta-data/instance-id)

#=============================
# hostname
#=============================
ng_name=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${instance_id}" --query "Tags[?Key=='eks:nodegroup-name'].Value" --output text --region ${region})

tag_name=${prefix}-${env}-${ng_name}-$(echo ${instance_ip} | cut -d. -f3,4 | sed s/"\."/"-"/g)   

#=============================
# tagdata
#=============================
aws ec2 create-tags --resources ${instance_id} --tags Key=Name,Value=${tag_name} --region ${region}

#=============================
# Timezone Change 
#=============================
timedatectl set-timezone Asia/Seoul

#=============================
# useradd
#=============================
users=("${dev_id}" "rundeck")
for user in "${users[@]}"; do
    if [ "$user" == "" ]; then
        continue
    fi
    useradd ${user}
    mkdir -m 700 /home/${user}/.ssh
    aws s3 cp s3://s3-sykim-ops/auth/${user}/id_rsa.pub /home/${user}/credentials/id_rsa.pub --region ${region}
    mv /home/${user}/credentials/id_rsa.pub /home/${user}/.ssh/authorized_keys
    rm -rf /home/${user}/credentials
    chmod 600 /home/$user/.ssh/authorized_keys
    chown -R ${user}:${user} /home/${user}/.ssh
    echo "${user}    ALL=(ALL)   NOPASSWD: ALL" > /etc/sudoers.d/${user}
done

#=============================
# Add the kubelet garbage collection
#=============================
# Inject imageGCHighThresholdPercent value unless it has already been set.
if ! grep -q imageGCHighThresholdPercent /etc/kubernetes/kubelet/kubelet-config.json; 
then 
    sed -i '/"apiVersion*/a \ \ "imageGCHighThresholdPercent": 70,' /etc/kubernetes/kubelet/kubelet-config.json
fi

# Inject imageGCLowThresholdPercent value unless it has already been set.
if ! grep -q imageGCLowThresholdPercent /etc/kubernetes/kubelet/kubelet-config.json; 
then 
    sed -i '/"imageGCHigh*/a \ \ "imageGCLowThresholdPercent": 50,' /etc/kubernetes/kubelet/kubelet-config.json
fi
--==MYBOUNDARY==--