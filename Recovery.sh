#!/bin/bash

BACKUP_DIR="/etc/postfix/backup"
TARGET_FILE="/etc/postfix/sasl_passwd.db"

# Find the most recent backup file
BACKUP_FILE=$(ls -t ${BACKUP_DIR}/sasl_passwd.db* 2>/dev/null | head -n1)

# Check if backup exists
if [ -z "$BACKUP_FILE" ]; then
    echo "No backup files found in $BACKUP_DIR"
    exit 1
fi

echo "Using most recent backup file: $BACKUP_FILE"

# Check if target file exists and remove it
if [ -f "$TARGET_FILE" ]; then
    echo "Found existing SMTP configuration file. Removing it..."
    sudo rm -f "$TARGET_FILE"
    if [ $? -ne 0 ]; then
        echo "Failed to remove existing configuration file"
        exit 1
    fi
    echo "Existing configuration file removed successfully"
fi

# Restore from backup
echo "Copying backup file to postfix directory..."
sudo cp "$BACKUP_FILE" "$TARGET_FILE"
if [ $? -ne 0 ]; then
    echo "Failed to copy backup file"
    exit 1
fi

# Set proper permissions
sudo chown root:root "$TARGET_FILE"
sudo chmod 0600 "$TARGET_FILE"
sudo systemctl reload postfix

echo "SMTP configuration restored from backup: $BACKUP_FILE"

# Send notification email about recovery
hostname=$(hostname)
current_date=$(date +"%m-%d-%Y")
from="DevOps@firminiq.com"
to="awsalert.staging@ohiomron.com"
subject="US-STG-INFO-SES - SMTP Recovery Performed for - $hostname | $current_date"

body="Hi Team,

SMTP configuration has been restored from backup on server: $hostname
Backup file used: $BACKUP_FILE
Previous configuration was removed and replaced with latest backup.

Sincerely,
Connected Health R&D Team

This message is intended for designated recipients only. If you are not the authorized recipient, or you were not expecting this message, or if you have received this message in error, please delete all copies of this message. Any unauthorized use or distribution of this message is prohibited."        

    if ! sendmail -v -f "$from" "$to" <<EOF
Subject: $subject
From: $from
To: $to
Content-Type: text/plain; charset=UTF-8

$body
EOF
    then
        echo "Failed to send confirmation email"
        return 1
    fi

    echo "Confirmation email sent successfully"
