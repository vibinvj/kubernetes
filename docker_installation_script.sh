systemctl stop firewalld
systemctl disable firewalld
systemctl stop NetworkManager
systemctl disable NetworkManager

rm -rf /etc/localtime ; ln -s /usr/share/zoneinfo/Asia/Kolkata /etc/localtime ; date

sed -i 's/^enabled=1$/enabled=0/' /etc/yum.repos.d/google-cloud.repo

cp /etc/ssh/sshd_config /etc/ssh/sshd_config_`date +%F_%T`

sed -i 's/^PermitRootLogin no$/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication yes$/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no$/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^ClientAliveInterval 420$/ClientAliveInterval 0/' /etc/ssh/sshd_config

systemctl restart sshd

rpm_wc=`rpm -qa | grep -i 'docker'| wc -l`

if [ $rpm_wc -eq 0 ]

then

echo "Installing Docker"
echo "================="

yum install yum-utils device-mapper-persistent-data lvm2 -y
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install docker-ce-18.06.2.ce -y
mkdir /etc/docker

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

systemctl daemon-reload
sleep 5
systemctl restart docker
systemctl enable docker
sed -i 's/^enabled=1$/enabled=0/' /etc/yum.repos.d/docker-ce.repo

else
	
	echo -e "Docker package already installed : \n `rpm -qa | grep -i docker-ce`"
fi

sleep 5

rpm_wc1=`rpm -qa | grep -i kube | wc -l`

if [ $rpm_wc1 -eq 0 ]

then

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

echo "List Of Versions"
echo "================"
yum list kubectl --showduplicates --disableexcludes=kubernetes | grep kubectl | awk '{print $2}'
echo ""
echo "Select Proper version"
echo "====================="
echo -n "version : " 
read a
yum install -y kubelet-$a.x86_64 kubeadm-$a.x86_64 kubectl-$a.x86_64 --disableexcludes=kubernetes

sleep 5

systemctl enable --now kubelet

cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

else
	echo -e "kubeadm packages already installed : \n `rpm -qa | grep -i kube`"
fi
