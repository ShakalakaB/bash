#!/usr/bin/env bash
# ec2-config.sh
#
# Description:
#   Configure a remote AWS EC2 instance with essential tools and services.
#   Executes remotely via SSH from your local machine.
#   All connection details are fully configurable via command-line flags or
#   environment variables so the same script can be reused across instances.
#
# Usage examples:
#   # Minimal (reads values from env vars)
#   EC2_CONFIG_HOST="ec2-1-2-3-4.compute.amazonaws.com" \
#   EC2_CONFIG_SSH_KEY="~/.ssh/my-key.pem" \
#   ./ec2-config.sh
#
#   # With explicit flags (overrides env vars)
#   ./ec2-config.sh \
#     --ssh-key ~/.ssh/my-key.pem \
#     --ec2-host ec2-1-2-3-4.compute.amazonaws.com \
#     --instance-name "my-server"
#
# Supported environment variables (all prefixed with EC2_CONFIG_):
#   SSH_KEY          SSH private key (path) used to connect to the EC2 instance
#   EC2_USER         OS user on the instance (default: ec2-user)
#   EC2_HOST         Public DNS / IP of the instance (required)
#   GITHUB_EMAIL_1   Email for first GitHub SSH key (default: aldora988@gmail.com)
#   GITHUB_EMAIL_2   Email for second GitHub SSH key (default: rakihubo@gmail.com)
#   INSTANCE_NAME    Instance name for health check messages (default: ec2-instance)
#
# Exit immediately if a command exits with a non-zero status, treat unset
# variables as an error, and fail if any element of a pipeline fails.
set -euo pipefail

########################################
# Utility functions
########################################
usage() {
  cat <<USAGE >&2
Usage: $(basename "$0") [options]

Options:
  --ssh-key PATH        Path to the SSH private key
  --ec2-user USER       Username for SSH (default: ec2-user)
  --ec2-host HOST       Public DNS or IP of the EC2 instance (required)
  --github-email-1 EMAIL Email for first GitHub SSH key (default: aldora988@gmail.com)
  --github-email-2 EMAIL Email for second GitHub SSH key (default: rakihubo@gmail.com)
  --instance-name NAME  Instance name for health check messages (default: ec2-instance)
  -h, --help            Show this help message

All options may also be supplied via environment variables, see script header.
USAGE
}

########################################
# Defaults (can be overridden via env)
########################################
SSH_KEY="${EC2_CONFIG_SSH_KEY:-}"
EC2_USER="${EC2_CONFIG_EC2_USER:-ec2-user}"
EC2_HOST="${EC2_CONFIG_EC2_HOST:-}"
GITHUB_EMAIL_1="${EC2_CONFIG_GITHUB_EMAIL_1:-aldora988@gmail.com}"
GITHUB_EMAIL_2="${EC2_CONFIG_GITHUB_EMAIL_2:-rakihubo@gmail.com}"
INSTANCE_NAME="${EC2_CONFIG_INSTANCE_NAME:-ec2-instance}"

########################################
# Parse command-line flags
########################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-key)        SSH_KEY="$2";        shift 2;;
    --ec2-user)       EC2_USER="$2";       shift 2;;
    --ec2-host)       EC2_HOST="$2";       shift 2;;
    --github-email-1) GITHUB_EMAIL_1="$2";  shift 2;;
    --github-email-2) GITHUB_EMAIL_2="$2";  shift 2;;
    --instance-name)  INSTANCE_NAME="$2";  shift 2;;
    -h|--help)        usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

########################################
# Validation
########################################
if [[ -z "${SSH_KEY}" ]]; then
  echo "Error: --ssh-key is required (or set EC2_CONFIG_SSH_KEY)." >&2
  exit 1
fi

if [[ -z "${EC2_HOST}" ]]; then
  echo "Error: --ec2-host is required (or set EC2_CONFIG_EC2_HOST)." >&2
  exit 1
fi

# Resolve leading ~ to $HOME for SSH_KEY path
if [[ "${SSH_KEY}" =~ ^~(/.*)?$ ]]; then
  SSH_KEY="${SSH_KEY/#~/${HOME}}"
fi

########################################
# Configuration files to copy
########################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILES=("configs/config" "configs/nginx.conf")

# Check if required config files exist
for file in "${CONFIG_FILES[@]}"; do
  if [[ ! -f "${SCRIPT_DIR}/${file}" ]]; then
    echo "Error: Required config file '${file}' not found in ${SCRIPT_DIR}" >&2
    exit 1
  fi
done

########################################
# Begin configuration
########################################
echo ""
echo "🚀 ============ EC2 CONFIGURATION ============"
echo "▶️  Starting EC2 configuration for ${EC2_HOST}"
echo "📋 Instance name: ${INSTANCE_NAME}"
echo "📧 GitHub email: ${GITHUB_EMAIL_1}, ${GITHUB_EMAIL_2}"

# Test SSH connection first
echo ""
echo "🔗 Testing SSH connection..."
if ! ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${EC2_USER}@${EC2_HOST}" "echo 'SSH connection successful'"; then
  echo "❌ ERROR: Cannot connect to EC2 instance via SSH" >&2
  exit 1
fi
echo "✅ SSH connection successful"

# Copy configuration files to remote instance
echo ""
echo "📁 Copying configuration files..."
scp -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SCRIPT_DIR}/configs/config" "${SCRIPT_DIR}/configs/nginx.conf" "${EC2_USER}@${EC2_HOST}:/tmp/"
echo "✅ Configuration files copied"

# Run the configuration script on remote instance
echo ""
echo "🔧 ============ REMOTE INSTALLATION ============"
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${EC2_USER}@${EC2_HOST}" \
  "sudo bash -s '${GITHUB_EMAIL_1}' '${GITHUB_EMAIL_2}' '${INSTANCE_NAME}'" <<'EOSSH'
#!/bin/bash
set -euo pipefail

GITHUB_EMAIL_1="$1"
GITHUB_EMAIL_2="$2"
INSTANCE_NAME="$3"

echo "[1/10] 🤖 Installing git-2.40.1..."
yum install -y git-2.40.1

echo "[2/10] 📦 Installing nginx-1.22.1..."
yum install -y nginx-1.22.1
systemctl start nginx.service

echo "[3/10] 🟢 Installing nvm & Node.js 18.20.3..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# Temporarily disable unbound variable check for sourcing bashrc
set +u
export NVM_DIR="$HOME/.nvm"
# This loads nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# This loads nvm bash_completion
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Verify nvm is loaded
if ! command -v nvm >/dev/null 2>&1; then
  echo "ERROR: nvm command not found after installation"
  exit 1
fi

nvm install 18.20.3
nvm use 18.20.3
# Re-enable unbound variable check
set -u

echo "[4/10] ⚙️  Enabling Corepack..."
npm update corepack -g
corepack enable

echo "[5/10] 🐳 Installing docker-25.0.3..."
yum install -y docker-25.0.3

echo "[6/10] 🐙 Installing docker-compose v2.27.0..."
curl -L https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
# Start docker
systemctl start docker

echo "[7/10] 🔒 Installing certbot..."
dnf install -y augeas-libs
python3 -m venv /opt/certbot/
/opt/certbot/bin/pip install --upgrade pip
/opt/certbot/bin/pip install certbot certbot-nginx
if [[ ! -L /usr/bin/certbot ]]; then
  ln -s /opt/certbot/bin/certbot /usr/bin/certbot
else
  echo "✅ Certbot symlink already exists, skipping..."
fi

echo "[8/10] ⏰ Installing crontab..."
yum install -y cronie
systemctl start crond.service
systemctl enable crond.service

# Choose download package from "https://dev.mysql.com/downloads/"
echo "[9/10] 🗄️  Installing MySQL client..."
yum install -y https://dev.mysql.com/get/mysql84-community-release-el9-1.noarch.rpm
yum install -y mysql-community-client

# Install pm2
echo "[10/10] 🚀 Installing pm2@5.4.2..."
yarn global add pm2@5.4.2

echo ""
echo "🔧 ============ CONFIGURATION SETUP ============"

# set github ssh key
echo "🔑 Setting up GitHub SSH keys..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [[ ! -f /root/.ssh/github-aldora ]]; then
  ssh-keygen -t ed25519 -C "${GITHUB_EMAIL_1}" -f "/root/.ssh/github-aldora" -N ""
  echo "✅ Generated github-aldora SSH key"
else
  echo "✅ SSH key github-aldora already exists, skipping..."
fi

if [[ ! -f /root/.ssh/github-raki ]]; then
  ssh-keygen -t ed25519 -C "${GITHUB_EMAIL_2}" -f "/root/.ssh/github-raki" -N ""
  echo "✅ Generated github-raki SSH key"
else
  echo "✅ SSH key github-raki already exists, skipping..."
fi

# create ssh/config file
echo "📋 Creating SSH config file..."
cp /tmp/config ~/.ssh/

# set up nginx: copy and paste nginx.conf
echo "🌐 Setting up Nginx configuration..."
cp /tmp/nginx.conf /etc/nginx/nginx.conf

# Add crontab job: auto renew domain certs
echo "⏰ Adding certificate renewal crontab job..."
(crontab -l 2>/dev/null || true; echo "0 0 */3 * * certbot -q renew && curl -fsS -X POST https://hc-ping.com/07b9ddd2-9b38-4a78-854f-89af632495c4 -d \"message=${INSTANCE_NAME}\"") | crontab -

echo ""
echo "✅ ============ CONFIGURATION COMPLETED ============"
echo ""
echo "📋 Next steps:"
echo "   1. Add the following SSH public key to your GitHub account:"
echo "      cat ~/.ssh/github-aldora.pub"
echo "      cat ~/.ssh/github-raki.pub"
echo "   2. Configure your domain DNS to point to this instance"
echo "   3. Run: sudo certbot --nginx -d your-domain.com"
echo "   4. Deploy your applications"

# Clean up temporary files
rm -f /tmp/config /tmp/nginx.conf

EOSSH

echo ""
echo "✅ ============ EC2 CONFIGURATION COMPLETED ============"
echo ""
echo "🔑 To view the generated SSH public keys for GitHub:"
echo "   cat ~/.ssh/github-aldora.pub"
echo "   cat ~/.ssh/github-raki.pub"
