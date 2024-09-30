#!/bin/bash

# Install git-core
echo "Installing git-core..."
sudo yum install -y git-core

# Install a single-node K3s cluster
echo "Installing K3s..."
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
sleep 60

# Create .kube directory and copy K3s kubeconfig file
echo "Configuring KUBECONFIG..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

# Enable Kubernetes autocompletion
echo "Enabling Kubernetes autocompletion..."
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "source <(kubeadm completion bash)" >> ~/.bashrc

# Reload bash
source ~/.bashrc

# Validate K3s installation
echo "Validating K3s installation..."
kubectl get nodes

# Clone the CSI plugin repository
echo "Cloning the Hammerspace CSI plugin repository..."
git clone https://github.com/hammer-space/csi-plugin.git

# Create Kubernetes secret with Hammerspace credentials
echo "Creating Kubernetes secret..."
kubectl apply -f - <<EOF
apiVersion: v1
data:
  password: UGFzc3cwcmQh
  username: YWRtaW4=
stringData:
  endpoint: "https://la-anvil-1.hammer.local"
kind: Secret
metadata:
  name: com.hammerspace.csi.credentials
  namespace: kube-system
EOF

# Apply the Kubernetes CSI plugin for version 1.25
echo "Applying Kubernetes CSI plugin for version 1.25..."
kubectl apply -f csi-plugin/deploy/kubernetes/kubernetes-1.25

# Clone hs_kubernetes_demo repository from the new URL
echo "Cloning hs_kubernetes_demo repository..."
git clone https://github.com/kbkuebler/hs_kubernetes_demo.git

# Apply hs-storage-share.yaml
echo "Applying hs-storage-share.yaml..."
kubectl apply -f https://raw.githubusercontent.com/kbkuebler/hs_kubernetes_demo/refs/heads/master/Storageclasses/hs-storage-share.yaml

# Download and install K9s
echo "Downloading K9s..."
curl -Lo k9s_Linux_amd64.tar.gz https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_Linux_amd64.tar.gz

echo "Extracting K9s..."
tar -xzf k9s_Linux_amd64.tar.gz

echo "Moving K9s executable to /usr/local/bin..."
sudo mv k9s /usr/local/bin/

# Clean up
echo "Cleaning up..."
rm k9s_Linux_amd64.tar.gz

echo "All tasks completed!"
