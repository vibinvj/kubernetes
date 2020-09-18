systemctl stop firewalld
systemctl disable firewalld
systemctl stop NetworkManager
systemctl disable NetworkManager
rm -rf /etc/localtime ; ln -s /usr/share/zoneinfo/Asia/Kolkata /etc/localtime ; date
sed -i 's/^enabled=1$/enabled=0/' /etc/yum.repos.d/google-cloud.repo
cp /etc/ssh/sshd_config /etc/ssh/sshd_config_`date +%F_%T`
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sed -i 's/^PermitRootLogin no$/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication yes$/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no$/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^ClientAliveInterval 420$/ClientAliveInterval 0/' /etc/ssh/sshd_config
systemctl restart sshd
echo 1 > /proc/sys/net/ipv4/ip_forward
kuberepo() {
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
#repo_gpgcheck=1
#gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF
}

echo "SELECT WHICH SERVER NEED TO INSTALL"
echo "====== ===== ====== ==== == ======="
echo ""
echo -e "1 - DOCKER \n2 - k8S(kubeadm,kubelet,kubectl) \n3 - CLIENT(kubectl) \n4 - GFS(Glusterfs) \n5 - HEKETI"
echo ""
echo "ENTER NUMERIC VALUE"
echo "==================="
echo ""
echo -n "VALUE : "
read a
case "$a" in
"1") 
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
sleep 2
systemctl restart docker
systemctl enable docker
sed -i 's/^enabled=1$/enabled=0/' /etc/yum.repos.d/docker-ce.repo
else	
	echo -e "Docker package already installed : \n `rpm -qa | grep -i docker-ce`"
fi
;;
"2")
rpm_wc1=`rpm -qa | grep -i kube | wc -l`
if [ $rpm_wc1 -eq 0 ]
then
kuberepo
echo ""
echo "List Of Versions"
echo "================"
yum list kubectl --showduplicates --disableexcludes=kubernetes | awk '{print $2}'
echo ""
echo "Select Proper version"
echo "====================="
echo -n "version : " 
read b
yum install -y kubelet-$b.x86_64 kubeadm-$b.x86_64 kubectl-$b.x86_64 --disableexcludes=kubernetes
systemctl enable --now kubelet
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system >/dev/null
else
	echo -e "kubeadm packages already installed : \n `rpm -qa | grep -i kube`"
fi
;;
"3")
rpm_wc3=`rpm -qa | grep kubectl | wc -l`
if [ $rpm_wc3 -eq 0 ]
then
kuberepo
echo ""
echo "List Of Versions"
echo "================"
yum list kubectl --showduplicates --disableexcludes=kubernetes | awk '{print $2}'
echo ""
echo "Select Proper version"
echo "====================="
echo -n "version : " 
read c
yum install -y kubectl-$c.x86_64 --disableexcludes=kubernetes
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system >/dev/null
else
        echo -e "kubectl package already installed : \n `rpm -qa | grep -i kube`"
fi
	;;
	"4")
yum install -y Centos-release-gluster7
yum install -y glusterfs glusterfs-server
systemctl start glusterd
systemctl enable glusterd
	;;
	"5")
yum install -y Centos-release-gluster7
yum install -y heketi
systemctl start heketi
systemctl enable heketi
	;;
esac
