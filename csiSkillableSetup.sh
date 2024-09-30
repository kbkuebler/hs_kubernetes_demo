#!/bin/bash

# Update Oracle Linux
echo "Updating Oracle Linux..."
sudo yum update -y

# Install a single-node K3s cluster
echo "Installing K3s..."
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
sleep 60

# Set kubectl to use K3s
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

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
  endpoint: 10.200.76.102
kind: Secret
metadata:
  name: com.hammerspace.csi.credentials
  namespace: kube-system
EOF

# Apply the Kubernetes CSI plugin for version 1.25
echo "Applying Kubernetes CSI plugin for version 1.25..."
kubectl apply -f csi-plugin/deploy/kubernetes/kubernetes-1.25

echo "All tasks completed!"
