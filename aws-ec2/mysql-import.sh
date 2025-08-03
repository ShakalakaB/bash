#!/usr/bin/env bash
# mysql-import.sh
#
# Description:
#   Import SQL files from a local directory into a MySQL instance.
#   Supports both direct MySQL connections and connections via EC2 instances.
#   All connection details are fully configurable via command-line flags or
#   environment variables so the same script can be reused across accounts.
#
# Usage examples:
#   # Direct connection to MySQL (local or remote)
#   MYSQL_IMPORT_SQL_DIR="./mysql_exports/ec2-host_2024-01-15_10-30-45" \
#   MYSQL_IMPORT_MYSQL_PASS="supersecret" \
#   ./mysql-import.sh
#
#   # Via EC2 instance (copies files and executes remotely)
#   ./mysql-import.sh \
#     --sql-dir ./mysql_exports/ec2-host_2024-01-15_10-30-45 \
#     --ssh-key ~/.ssh/my-key.pem \
#     --ec2-host ec2-1-2-3-4.compute.amazonaws.com \
#     --mysql-host database-1.caubw1tslulz.us-east-1.rds.amazonaws.com \
#     --mysql-user admin \
#     --mysql-pass supersecret
#
#   # Direct connection to remote MySQL
#   ./mysql-import.sh \
#     --sql-dir ./mysql_exports/ec2-host_2024-01-15_10-30-45 \
#     --mysql-host database-1.caubw1tslulz.us-east-1.rds.amazonaws.com \
#     --mysql-user admin \
#     --mysql-pass supersecret
#
# Supported environment variables (all prefixed with MYSQL_IMPORT_):
#   SQL_DIR        Local directory containing SQL dump files (required)
#   SSH_KEY        SSH private key (path) used to connect to the EC2 instance
#   EC2_USER       OS user on the instance (default: ec2-user)
#   EC2_HOST       Public DNS / IP of the instance (optional)
#   MYSQL_USER     MySQL user (default: admin)
#   MYSQL_PASS     MySQL password (required)
#   MYSQL_HOST     MySQL hostname (default: localhost)
#   MYSQL_PORT     MySQL port (default: 3306)
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
  --sql-dir DIR         Local directory containing SQL dump files (required)
  --ssh-key PATH        Path to SSH private key for EC2 access (optional)
  --ec2-user USER       Username for SSH (default: ec2-user)
  --ec2-host HOST       Public DNS or IP of the EC2 instance (optional)
  --mysql-user USER     MySQL username (default: admin)
  --mysql-pass PASS     MySQL password (required)
  --mysql-host HOST     MySQL host (default: localhost)
  --mysql-port PORT     MySQL port (default: 3306)
  --force               Drop existing databases before import
  -h, --help            Show this help message

All options may also be supplied via environment variables, see script header.

Examples:
  # Direct import to local MySQL
  $0 --sql-dir ./exports --mysql-pass secret

  # Direct import to remote MySQL  
  $0 --sql-dir ./exports --mysql-host db.example.com --mysql-pass secret

  # Import via EC2 instance
  $0 --sql-dir ./exports --ssh-key ~/.ssh/key.pem --ec2-host ec2-host.com --mysql-pass secret
USAGE
}

########################################
# Defaults (can be overridden via env)
########################################
SQL_DIR="${MYSQL_IMPORT_SQL_DIR:-}"
SSH_KEY="${MYSQL_IMPORT_SSH_KEY:-}"
EC2_USER="${MYSQL_IMPORT_EC2_USER:-ec2-user}"
EC2_HOST="${MYSQL_IMPORT_EC2_HOST:-}"
MYSQL_USER="${MYSQL_IMPORT_MYSQL_USER:-admin}"
MYSQL_PASS="${MYSQL_IMPORT_MYSQL_PASS:-}"
MYSQL_HOST="${MYSQL_IMPORT_MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_IMPORT_MYSQL_PORT:-3306}"
FORCE_DROP=false

########################################
# Parse command-line flags
########################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sql-dir)    SQL_DIR="$2";      shift 2;;
    --ssh-key)    SSH_KEY="$2";      shift 2;;
    --ec2-user)   EC2_USER="$2";     shift 2;;
    --ec2-host)   EC2_HOST="$2";     shift 2;;
    --mysql-user) MYSQL_USER="$2";   shift 2;;
    --mysql-pass) MYSQL_PASS="$2";   shift 2;;
    --mysql-host) MYSQL_HOST="$2";   shift 2;;
    --mysql-port) MYSQL_PORT="$2";   shift 2;;
    --force)      FORCE_DROP=true;   shift;;
    -h|--help)    usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

########################################
# Validation
########################################
if [[ -z "${SQL_DIR}" ]]; then
  echo "Error: --sql-dir is required (or set MYSQL_IMPORT_SQL_DIR)." >&2
  exit 1
fi

if [[ ! -d "${SQL_DIR}" ]]; then
  echo "Error: SQL directory '${SQL_DIR}' does not exist." >&2
  exit 1
fi

if [[ -z "${MYSQL_PASS}" ]]; then
  echo "Error: --mysql-pass is required (or set MYSQL_IMPORT_MYSQL_PASS)." >&2
  exit 1
fi

# If SSH_KEY is provided, EC2_HOST must also be provided
if [[ -n "${SSH_KEY}" && -z "${EC2_HOST}" ]]; then
  echo "Error: --ec2-host is required when using --ssh-key." >&2
  exit 1
fi

# Validate SSH key exists if provided
if [[ -n "${SSH_KEY}" && ! -f "${SSH_KEY}" ]]; then
  echo "Error: SSH key file '${SSH_KEY}' does not exist." >&2
  exit 1
fi

########################################
# Derived paths
########################################
TIMESTAMP="$(date +%F-%H%M%S)"
REMOTE_DIR="/tmp/mysql_imports_${TIMESTAMP}"

########################################
# Find SQL files
########################################
echo ""
echo "📥 ============ MYSQL DATABASE IMPORT ============"
echo "📁 SQL directory: ${SQL_DIR}"

# Find all .sql files in the directory (portable method)
SQL_FILES=()
while IFS= read -r -d '' file; do
  SQL_FILES+=("$file")
done < <(find "${SQL_DIR}" -name "*.sql" -type f -print0 | sort -z)

TOTAL_FILES=${#SQL_FILES[@]}

if [[ ${#SQL_FILES[@]} -eq 0 ]]; then
  echo "❌ Error: No .sql files found in ${SQL_DIR}" >&2
  exit 1
fi

echo "📋 Found ${#SQL_FILES[@]} SQL file(s) to import:"
for sql_file in "${SQL_FILES[@]}"; do
  db_name=$(basename "${sql_file}" .sql)
  echo "   • ${db_name} ($(basename "${sql_file}"))"
done

########################################
# Begin import
########################################
echo ""
echo "📥 Starting MySQL import..."
echo "📋 MySQL host: ${MYSQL_HOST}:${MYSQL_PORT}"
echo "👤 MySQL user: ${MYSQL_USER}"

if [[ -n "${SSH_KEY}" ]]; then
  ########################################
  # Remote import via EC2
  ########################################
  echo "🔧 Import method: Via EC2 instance (${EC2_HOST})"
  
  echo ""
  echo "📤 ============ COPYING FILES TO EC2 ============"
  echo "📁 Copying SQL files to ${EC2_HOST}:${REMOTE_DIR}..."
  
  # Copy SQL files to EC2
  scp -i "${SSH_KEY}" -o StrictHostKeyChecking=no -r "${SQL_DIR}" "${EC2_USER}@${EC2_HOST}:${REMOTE_DIR}"
  echo "✅ Files copied successfully"
  
  echo ""
  echo "🔧 ============ REMOTE IMPORT PROCESS ============"
  
  # Execute import on EC2
  if ! ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${EC2_USER}@${EC2_HOST}" \
    "sudo bash -s '${REMOTE_DIR}' '${MYSQL_USER}' '${MYSQL_PASS}' '${MYSQL_HOST}' '${MYSQL_PORT}' '${FORCE_DROP}'" <<'EOSSH'
#!/bin/bash
REMOTE_DIR="$1"
MYSQL_USER="$2"
MYSQL_PASS="$3"
MYSQL_HOST="$4"
MYSQL_PORT="$5"
FORCE_DROP="$6"

export MYSQL_PWD="${MYSQL_PASS}"

# Test MySQL connection first
echo "🔗 Testing MySQL connection..."
if ! mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -e "SELECT 1;" >/dev/null 2>&1; then
  echo "❌ ERROR: Cannot connect to MySQL. Please check credentials and host."
  exit 1
fi
echo "✅ MySQL connection successful"

# Find SQL files in the copied directory
echo "📋 Processing SQL files..."
SQL_FILES=($(find "${REMOTE_DIR}" -name "*.sql" -type f | sort))
TOTAL_FILES=${#SQL_FILES[@]}

if [[ ${#SQL_FILES[@]} -eq 0 ]]; then
  echo "❌ ERROR: No SQL files found in ${REMOTE_DIR}"
  exit 1
fi

echo ""
echo "🗄️  ============ DATABASE IMPORT ============"
IMPORT_COUNT=0
TOTAL_FILES=${#SQL_FILES[@]}

for sql_file in "${SQL_FILES[@]}"; do
  db_name=$(basename "${sql_file}" .sql)
  ((IMPORT_COUNT_DISPLAY = IMPORT_COUNT + 1))
  
  echo ""
  echo "[${IMPORT_COUNT_DISPLAY}/${TOTAL_FILES}] 📥 Importing \"${db_name}\"..."
  
  # Check if database exists
  DB_EXISTS=$(mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
    --skip-column-names -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${db_name}';" 2>/dev/null || echo "")
  
  if [[ -n "${DB_EXISTS}" ]]; then
    if [[ "${FORCE_DROP}" == "true" ]]; then
      echo "⚠️  Database '${db_name}' exists, dropping due to --force flag..."
      mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
        -e "DROP DATABASE \`${db_name}\`;"
    else
      echo "⚠️  Database '${db_name}' already exists, skipping import"
      echo "    Use --force to drop and recreate existing databases"
      continue
    fi
  fi
  
  # Create database
  echo "📊 Creating database '${db_name}'..."
  mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
    -e "CREATE DATABASE \`${db_name}\`;"
  
  # Import SQL file
  echo "💾 Importing SQL file..."
  file_size=$(wc -c < "${sql_file}" | tr -d ' ')
  if [[ ${file_size} -gt 10485760 ]]; then  # > 10MB
    echo "📦 Large file detected ($(numfmt --to=iec ${file_size})), this may take a while..."
  fi
  
  if mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
    "${db_name}" < "${sql_file}"; then
    echo "✅ Successfully imported ${db_name}"
    ((IMPORT_COUNT++))
  else
    echo "❌ ERROR: Failed to import ${db_name}"
    # Don't exit on individual failures, continue with other databases
  fi
done

echo ""
echo "📊 Import summary: ${IMPORT_COUNT}/${TOTAL_FILES} databases imported successfully"

# List successfully imported databases
if [[ ${IMPORT_COUNT} -gt 0 ]]; then
  echo ""
  echo "📋 Successfully imported databases:"
  for sql_file in "${SQL_FILES[@]}"; do
    db_name=$(basename "${sql_file}" .sql)
    # Check if database now exists
    DB_EXISTS=$(mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
      --skip-column-names -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${db_name}';" 2>/dev/null || echo "")
    if [[ -n "${DB_EXISTS}" ]]; then
      # Get table count
      TABLE_COUNT=$(mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
        --skip-column-names -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='${db_name}';" 2>/dev/null || echo "0")
      echo "   ✅ ${db_name} (${TABLE_COUNT} tables)"
    fi
  done
fi
EOSSH
  then
    echo "✅ Remote import completed successfully"
  else
    echo "❌ Remote import failed. Check the error messages above."
    exit 1
  fi
  
  ########################################
  # Remote cleanup
  ########################################
  echo ""
  echo "🧹 Cleaning up temporary files from remote instance..."
  ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${EC2_USER}@${EC2_HOST}" \
    "sudo rm -rf ${REMOTE_DIR}"
  echo "✅ Remote cleanup completed"

else
  ########################################
  # Direct import (local or remote MySQL)
  ########################################
  echo "🔧 Import method: Direct MySQL connection"
  
  echo ""
  echo "🔧 ============ CONNECTION TEST ============"
  echo "🔗 Testing MySQL connection..."
  
  export MYSQL_PWD="${MYSQL_PASS}"
  
  if ! mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -e "SELECT 1;" >/dev/null 2>&1; then
    echo "❌ ERROR: Cannot connect to MySQL. Please check credentials and connection." >&2
    exit 1
  fi
  echo "✅ MySQL connection successful"
  
  echo ""
  echo "🗄️  ============ DATABASE IMPORT ============"
  IMPORT_COUNT=0
  TOTAL_FILES=${#SQL_FILES[@]}
  
  for sql_file in "${SQL_FILES[@]}"; do
    db_name=$(basename "${sql_file}" .sql)
    ((IMPORT_COUNT_DISPLAY = IMPORT_COUNT + 1))
    
    echo ""
    echo "[${IMPORT_COUNT_DISPLAY}/${TOTAL_FILES}] 📥 Importing \"${db_name}\"..."
    
    # Check if database exists
    DB_EXISTS=$(mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
      --skip-column-names -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${db_name}';" 2>/dev/null || echo "")
    
    if [[ -n "${DB_EXISTS}" ]]; then
      if [[ "${FORCE_DROP}" == "true" ]]; then
        echo "⚠️  Database '${db_name}' exists, dropping due to --force flag..."
        mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
          -e "DROP DATABASE \`${db_name}\`;"
      else
        echo "⚠️  Database '${db_name}' already exists, skipping import"
        echo "    Use --force to drop and recreate existing databases"
        continue
      fi
    fi
    
    # Create database
    echo "📊 Creating database '${db_name}'..."
    mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
      -e "CREATE DATABASE \`${db_name}\`;"
    
    # Import SQL file
    echo "💾 Importing SQL file..."
    file_size=$(wc -c < "${sql_file}" | tr -d ' ')
    if [[ ${file_size} -gt 10485760 ]]; then  # > 10MB
      echo "📦 Large file detected ($(numfmt --to=iec ${file_size})), this may take a while..."
    fi
    
    if mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
      "${db_name}" < "${sql_file}"; then
      echo "✅ Successfully imported ${db_name}"
      ((IMPORT_COUNT++))
    else
      echo "❌ ERROR: Failed to import ${db_name}"
      # Don't exit on individual failures, continue with other databases
    fi
  done
  
  ########################################
  # Summary for direct import
  ########################################
  echo ""
  echo "📊 Import summary: ${IMPORT_COUNT}/${TOTAL_FILES} databases imported successfully"
  
  if [[ ${IMPORT_COUNT} -gt 0 ]]; then
    echo ""
    echo "📋 Successfully imported databases:"
    for sql_file in "${SQL_FILES[@]}"; do
      db_name=$(basename "${sql_file}" .sql)
      # Check if database now exists
      DB_EXISTS=$(mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
        --skip-column-names -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${db_name}';" 2>/dev/null || echo "")
      if [[ -n "${DB_EXISTS}" ]]; then
        # Get table count
        TABLE_COUNT=$(mysql -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" \
          --skip-column-names -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='${db_name}';" 2>/dev/null || echo "0")
        echo "   ✅ ${db_name} (${TABLE_COUNT} tables)"
      fi
    done
  fi
fi

########################################
# Final summary
########################################
echo ""
echo "🎉 ============ IMPORT COMPLETED ============"

if [[ ${IMPORT_COUNT:-0} -lt ${TOTAL_FILES} ]]; then
  failed_count=$((TOTAL_FILES - ${IMPORT_COUNT:-0}))
  echo "⚠️  ${failed_count} database(s) failed to import. Check the error messages above."
fi

echo ""
echo "📋 Next steps:"
echo "   • Verify your imported data"
echo "   • Update application connection strings if needed"
echo "   • Consider running ANALYZE TABLE on imported tables for optimal performance"
