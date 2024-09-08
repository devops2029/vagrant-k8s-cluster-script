#! /bin/bash

# Variable Declaration
KUBERNETES_VERSION="1.28.13"
# Patch Releases: 1.30.0, 1.30.1, 1.30.2, 1.30.3, 1.30.4
# Patch Releases: 1.29.0, 1.29.1, 1.29.2, 1.29.3, 1.29.4, 1.29.5, 1.29.6, 1.29.7, 1.29.8
# Patch Releases:1.28.0, 1.28.1, 1.28.2, 1.28.3, 1.28.4, 1.28.5, 1.28.6, 1.28.7, 1.28.8, 1.28.9, 1.28.10, 1.28.11, 1.28.12, 1.28.13
# Patch Releases:1.31 Latest Release:1.31.0 (released: 2024-08-13)

# disable swap 
sudo swapoff -a
# keeps the swaf off during reboot
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

#Letting iptables see bridged traffic 
lsmod | grep br_netfilter
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

# containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

#Clean Install Docker Engine on Ubuntu
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

#Add Docker’s official GPG key:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

#set up the stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

#Install Docker Engine
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

#Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

#restart containerd
sudo systemctl restart containerd

echo "ContainerD Runtime Configured Successfully"

#Installing kubeadm, kubelet and kubectl
sudo apt-get update -y 
sudo apt-get install -y apt-transport-https ca-certificates curl

#Google Cloud public signing key
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

#Add Kubernetes apt repository
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

#Update apt package index, install kubelet, kubeadm and kubectl, and pin their version:
sudo apt-get update -y

sudo apt-get install -y kubelet kubectl kubeadm

sudo apt-mark hold kubelet kubeadm kubectl

