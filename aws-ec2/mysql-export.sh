#!/usr/bin/env bash
# mysql-export.sh
#
# Description:
#   Dump every non-system MySQL schema found on a remote AWS EC2 instance
#   into its own SQL file and copy the resulting files to the local machine.
#   All connection details are fully configurable via command-line flags or
#   environment variables so the same script can be reused across accounts.
#
# Usage examples:
#   # Minimal (reads values from env vars)
#   MYSQL_EXPORT_EC2_HOST="ec2-1-2-3-4.compute.amazonaws.com" \
#   MYSQL_EXPORT_SSH_KEY="~/.ssh/my-key.pem" \
#   MYSQL_EXPORT_MYSQL_PASS="supersecret" \
#   ./mysql-export.sh
#
#   # With explicit flags (overrides env vars)
#   ./mysql-export.sh \
#     --ec2-host ec2-1-2-3-4.compute.amazonaws.com \
#     --ssh-key ~/.ssh/my-key.pem \
#     --mysql-user admin \
#     --mysql-pass supersecret \
#     --mysql-host database-1.caubw1tslulz.us-east-1.rds.amazonaws.com
#
# Supported environment variables (all prefixed with MYSQL_EXPORT_):
#   SSH_KEY        SSH private key (path) used to connect to the EC2 instance
#   EC2_USER       OS user on the instance (default: ec2-user)
#   EC2_HOST       Public DNS / IP of the instance (required)
#   MYSQL_USER     MySQL user (default: root)
#   MYSQL_PASS     MySQL password (required)
#   MYSQL_HOST     MySQL hostname as seen from inside the instance (default: localhost)
#   OUT_DIR        Local directory where dumps will be placed (default: ./mysql_exports)
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
  --mysql-user USER     MySQL username (default: admin)
  --mysql-pass PASS     MySQL password (required)
  --mysql-host HOST     MySQL host inside the instance (required)
  --out DIR             Local output directory for dumps (default: ~/Desktop/mysql_exports)
  -h, --help            Show this help message

All options may also be supplied via environment variables, see script header.
USAGE
}

########################################
# Defaults (can be overridden via env)
########################################
SSH_KEY="${MYSQL_EXPORT_SSH_KEY:-}"
EC2_USER="${MYSQL_EXPORT_EC2_USER:-ec2-user}"
EC2_HOST="${MYSQL_EXPORT_EC2_HOST:-}"
MYSQL_USER="${MYSQL_EXPORT_MYSQL_USER:-admin}"
MYSQL_PASS="${MYSQL_EXPORT_MYSQL_PASS:-}"
MYSQL_HOST="${MYSQL_EXPORT_MYSQL_HOST:-}"
OUT_DIR="${MYSQL_EXPORT_OUT_DIR:-~/Desktop/mysql_exports}"

########################################
# Parse command-line flags
########################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-key)   SSH_KEY="$2";      shift 2;;
    --ec2-user)  EC2_USER="$2";     shift 2;;
    --ec2-host)  EC2_HOST="$2";     shift 2;;
    --mysql-user) MYSQL_USER="$2";  shift 2;;
    --mysql-pass) MYSQL_PASS="$2";  shift 2;;
    --mysql-host) MYSQL_HOST="$2";  shift 2;;
    --out)       OUT_DIR="$2";      shift 2;;
    -h|--help)   usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

########################################
# Validation
########################################
if [[ -z "${SSH_KEY}" ]]; then
  echo "Error: --ssh-key is required (or set MYSQL_EXPORT_SSH_KEY)." >&2
  exit 1
fi

if [[ -z "${EC2_HOST}" ]]; then
  echo "Error: --ec2-host is required (or set MYSQL_EXPORT_EC2_HOST)." >&2
  exit 1
fi

if [[ -z "${MYSQL_PASS}" ]]; then
  echo "Error: --mysql-pass is required (or set MYSQL_EXPORT_MYSQL_PASS)." >&2
  exit 1
fi

if [[ -z "${MYSQL_HOST}" ]]; then
  echo "Error: --mysql-host is required (or set MYSQL_EXPORT_MYSQL_HOST)." >&2
  exit 1
fi

########################################
# Derived paths
########################################
# Resolve leading ~ to $HOME for OUT_DIR so it always becomes an absolute path
if [[ "${OUT_DIR}" =~ ^~(/.*)?$ ]]; then
  OUT_DIR="${OUT_DIR/#~/${HOME}}"
fi

TIMESTAMP="$(date +%F-%H%M%S)"
REMOTE_DIR="/tmp/mysql_exports_${TIMESTAMP}"
LOCAL_DIR="${OUT_DIR}/${EC2_HOST}_${TIMESTAMP}"

########################################
# Begin export
########################################
echo ""
echo "📤 ============ MYSQL DATABASE EXPORT ============"
echo "▶️  Starting MySQL export from ${EC2_HOST}"
echo "📋 MySQL host: ${MYSQL_HOST}"
echo "👤 MySQL user: ${MYSQL_USER}"
echo "📁 Output directory: ${LOCAL_DIR}"

# Run the remote export and capture the exit status
echo ""
echo "🔧 ============ REMOTE EXPORT PROCESS ============"
if ! ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${EC2_USER}@${EC2_HOST}" \
  "sudo bash -s '${REMOTE_DIR}' '${MYSQL_USER}' '${MYSQL_PASS}' '${MYSQL_HOST}'" <<'EOSSH'
#!/bin/bash
REMOTE_DIR="$1"
MYSQL_USER="$2"
MYSQL_PASS="$3"
MYSQL_HOST="$4"

export MYSQL_PWD="${MYSQL_PASS}"

# Create export directory ownered by the invoking user (ec2-user)
echo "📁 Creating remote directory: ${REMOTE_DIR}"
mkdir -p "${REMOTE_DIR}"
chown "$(whoami)":"$(whoami)" "${REMOTE_DIR}"

# Test MySQL connection first
echo "🔗 Testing MySQL connection..."
if ! mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -e "SELECT 1;" >/dev/null 2>&1; then
  echo "❌ ERROR: Cannot connect to MySQL. Please check credentials and host."
  exit 1
fi
echo "✅ MySQL connection successful"

# Obtain list of non-system databases
echo "📋 Getting database list..."
DATABASES=$(mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" --skip-column-names -e "SHOW DATABASES;")

if [[ -z "${DATABASES}" ]]; then
  echo "⚠️  WARNING: No databases found or no access to SHOW DATABASES"
  exit 1
fi

echo "📊 Found databases to export:"
EXPORT_DBS=()
for DB in ${DATABASES}; do
  case "${DB}" in
    information_schema|performance_schema|mysql|sys)
      continue ;; # skip system schemas
  esac
  EXPORT_DBS+=("${DB}")
  echo "   • ${DB}"
done

if [[ ${#EXPORT_DBS[@]} -eq 0 ]]; then
  echo "⚠️  WARNING: No user databases found to export"
  exit 1
fi

echo ""
echo "🗄️  ============ DATABASE DUMPING ============"
DUMP_COUNT=0
TOTAL_DBS=${#EXPORT_DBS[@]}

for DB in "${EXPORT_DBS[@]}"; do
  ((DUMP_COUNT_DISPLAY = DUMP_COUNT + 1))
  echo "[${DUMP_COUNT_DISPLAY}/${TOTAL_DBS}] 💾 Dumping \"${DB}\"..."
  if mysqldump -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -p"${MYSQL_PASS}" \
    --complete-insert \
    --set-gtid-purged=OFF \
    "${DB}" > "${REMOTE_DIR}/${DB}.sql"; then
    echo "✅ Successfully dumped ${DB}"
    ((DUMP_COUNT++))
  else
    echo "❌ ERROR: Failed to dump ${DB}"
  fi
done

echo ""
echo "📊 Export summary: ${DUMP_COUNT}/${TOTAL_DBS} databases exported successfully"

# Check if any files were actually created
if [[ ${DUMP_COUNT} -eq 0 ]]; then
  echo "❌ ERROR: No databases were successfully dumped"
  exit 1
fi

# List the created files
echo ""
echo "📋 Created files:"
ls -la "${REMOTE_DIR}/"
EOSSH
then
  echo "❌ Remote export failed. Check the error messages above."
  exit 1
fi

########################################
# Copy dumps to local machine
########################################

echo ""
echo "📥 ============ LOCAL FILE TRANSFER ============"
echo "📁 Copying dumps to local directory: ${LOCAL_DIR}"
mkdir -p "${LOCAL_DIR}"
scp -i "${SSH_KEY}" -o StrictHostKeyChecking=no -r "${EC2_USER}@${EC2_HOST}:${REMOTE_DIR}/" "${LOCAL_DIR}/"
echo "✅ Files copied successfully"

########################################
# Remote cleanup
########################################

echo ""
echo "🧹 Cleaning up temporary files from remote instance..."
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${EC2_USER}@${EC2_HOST}" \
  "sudo rm -rf ${REMOTE_DIR}"
echo "✅ Remote cleanup completed"

echo ""
echo "🎉 ============ EXPORT COMPLETED ============"
echo "📁 SQL files are available in: ${LOCAL_DIR}"
echo ""
echo "📋 Next steps:"
echo "   • Review the exported SQL files"
echo "   • Import them to your target database using:"
echo "     mysql -u username -p database_name < backup_file.sql"
