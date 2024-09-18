#!/bin/bash

# Function to base64 encode input
base64_encode() {
    echo -n "$1" | base64
}

# Check Linux distribution and version
if [ -f /etc/os-release ]; then
    source /etc/os-release
    echo "You are running $NAME $VERSION"
else
    echo "Cannot detect OS. Exiting..."
    exit 1
fi

# Install Docker-CE based on distribution
echo "Installing Docker-CE..."

if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$ID/gpg | sudo tee /etc/apt/keyrings/docker.gpg > /dev/null
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$ID \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
elif [[ "$ID" == "centos" || "$ID" == "rhel" ]]; then
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl start docker
else
    echo "Unsupported distribution: $ID"
    exit 1
fi

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker
echo "Docker installed successfully."

# Install kind
echo "Installing kind..."
if [ $(uname -m) = x86_64 ]; then
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
elif [ $(uname -m) = aarch64 ]; then
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-arm64
else
    echo "Unsupported architecture. Exiting..."
    exit 1
fi

chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
echo "kind installed successfully."

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl

# Create ~/.local/bin if it doesn't exist and add it to the PATH
mkdir -p ~/.local/bin
mv kubectl ~/.local/bin/kubectl
if ! grep -q 'export PATH=$PATH:$HOME/.local/bin' ~/.bashrc; then
    echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc
    export PATH=$PATH:$HOME/.local/bin
fi
echo "kubectl installed successfully."

# Create the kind cluster
echo "Creating kind cluster 'csi-testing'..."
kind create cluster --name csi-testing
echo "Kind cluster 'csi-testing' created."

# Clone the CSI plugin repository
echo "Cloning the CSI plugin repository..."
git clone https://github.com/hammer-space/csi-plugin.git

# Prompt for Hammerspace credentials
echo "Please enter your Hammerspace endpoint IP (e.g., 192.168.100.5):"
read -r endpoint
echo "Please enter the Hammerspace Admin username:"
read -r username
echo "Please enter the Hammerspace Admin password:"
read -r -s password  # -s to hide password input

# Base64 encode the username and password
encoded_username=$(base64_encode "$username")
encoded_password=$(base64_encode "$password")

# Create the Secret YAML file
cat <<EOF > hammerspace-secret.yaml
apiVersion: v1
data:
  endpoint: $endpoint
  password: $encoded_password
  username: $encoded_username
kind: Secret
metadata:
  name: com.hammerspace.csi.credentials
  namespace: kube-system
EOF

echo "Hammerspace credentials Secret created successfully."

# Apply the Secret to the Kubernetes cluster
kubectl apply -f hammerspace-secret.yaml
echo "Hammerspace credentials Secret applied successfully."

# Apply the Kubernetes manifests for Kubernetes 1.25
echo "Applying Kubernetes manifests..."
cd csi-plugin
kubectl apply -f deploy/kubernetes/kubernetes-1.25
echo "CSI plugin deployed successfully."
