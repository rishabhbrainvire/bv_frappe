# #!/bin/bash

BASE_DIR="/home/frappe"
BACKUP_DIR="$BASE_DIR/backup-bench"
INSTANCE_DIR="$BASE_DIR/frappe-bench/apps/frappe"

echo "🔍 Checking for existing Frappe instance..."

start_bench() {
  echo "🚀 Starting bench..."
  cd "$BASE_DIR/frappe-bench"
  bench start
} 

copy_from_backup() {
  echo "📁 Copying frappe-bench from backup..."
  cp -r "$BACKUP_DIR/frappe-bench" "$BASE_DIR/"
}

create_new_instance() {
  echo "🛠️ Creating new bench instance..."
  cd "$BASE_DIR"

  export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"
  
  bench init --skip-redis-config-generation frappe-bench
  cd frappe-bench

  echo "🔧 Configuring container services..."
  bench set-mariadb-host mariadb
  bench set-redis-cache-host redis://redis:6379
  bench set-redis-queue-host redis://redis:6379
  bench set-redis-socketio-host redis://redis:6379

  echo "🧹 Cleaning up Procfile..."
  sed -i '/redis/d' ./Procfile
  sed -i '/watch/d' ./Procfile


  echo "⬇️ Getting ERPNEXT app..."
  bench get-app erpnext

  echo "⬇️ Getting HRMS app..."
  bench get-app hrms

  echo "⬇️ Getting CRM app..."
  bench get-app crm 


  echo "🌐 Creating new site..."
  bench new-site frappecrm.brainvire.net \
    --force \
    --mariadb-root-password 123 \
    --admin-password admin \
    --no-mariadb-socket

  echo "📦 Installing apps..."
  # ERP gets setup automatically
  bench --site frappecrm.brainvire.net install-app hrms
  bench --site frappecrm.brainvire.net install-app crm
  bench --site frappecrm.brainvire.net set-config developer_mode 1
  bench --site frappecrm.brainvire.net set-config mute_emails 1
  bench --site frappecrm.brainvire.net set-config server_script_enabled 1
  bench --site frappecrm.brainvire.net clear-cache
  bench use frappecrm.brainvire.net

  echo "💾 Backing up frappe-bench to $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  rm -rf "$BACKUP_DIR/frappe-bench"  # optional cleanup
  cp -r "$BASE_DIR/frappe-bench" "$BACKUP_DIR/"
}

# Main Logic
if [ -d "$INSTANCE_DIR" ]; then
  echo "✅ Existing bench instance found."
  start_bench
else
  echo "❌ No bench instance found."
  if [ -d "$BACKUP_DIR/frappe-bench/apps/frappe" ]; then
    echo "📦 Found backup. Restoring frappe-bench..."
    copy_from_backup
    echo "⏳ Waiting 5 seconds before starting bench..."
    sleep 5
    start_bench
  else
    echo "🔧 No backup found. Bootstrapping new instance..."
    create_new_instance
    start_bench
  fi
fi
