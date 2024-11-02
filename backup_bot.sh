#!/bin/sh


LOGROTATE_CONF="/etc/logrotate.d/backup-bot"
LOGFILE="/var/log/backup-bot/bot.log"
LOG_DIR="/var/log/backup-bot"
GITLAB_BACKUP_DIR="/var/opt/gitlab/backups"
MINIO_BUCKET="minio_server/gitlab-backup"
CURRENT_TIME=$(date '+%Y-%m-%d-%H-%M-%S')
GITLAB_BACKUP_NAME="$GITLAB_BACKUP_DIR/$CURRENT_TIME"_gitlab_backup.tar
BOT_BACKUP_NAME="$GITLAB_BACKUP_DIR/$CURRENT_TIME"-gitlab.tar

LOGROTATE_CONF_CONTENT=$(cat << EOF
$LOG_DIR/*.log {
    rotate 5
    weekly
    missingok
    notifempty
    compress
    create 644 root root
}
EOF
)

if [ ! -e "$LOGROTATE_CONF" ]; then
  echo "$LOGROTATE_CONF_CONTENT" > $LOGROTATE_CONF 
fi


if [ ! -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
fi


exec 3>&1 1>>"$LOGFILE" 2>&1


log() {
  echo "[$(date '+%Y-%m-%d-%H-%M-%S')]" "$*"
}

log "Starting script execution" 


NUM_FILES=$(ls -1 "$GITLAB_BACKUP_DIR"/* | wc -l)
if [ "$NUM_FILES" -ne 0 ]; then
  # Remove all files in the directory
  rm -rf "$GITLAB_BACKUP_DIR"/* && log "remove old files" || exit 1
fi


gitlab-rake gitlab:backup:create BACKUP=$CURRENT_TIME && log "Backup $GITLAB_BACKUP_NAME is done." || exit 1 
 
tar -zcf $BOT_BACKUP_NAME $GITLAB_BACKUP_NAME /etc/gitlab/gitlab-secrets.json /etc/gitlab/gitlab.rb && log "compress backup is done." || exit 1

rm $GITLAB_BACKUP_NAME 

# Initialize the MinIO client
# mc config host add $NAME $MINIO_ENDPOINT $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
# mc alias list

# Upload the file to MinIO
mc cp --insecure $BOT_BACKUP_NAME $MINIO_BUCKET && log "upload $(basename $BOT_BACKUP_NAME) to minio" || exit 1

log "finish task."
