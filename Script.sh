#!/bin/bash

# Set strict error handling
set -euo pipefail

# Constants
SECRET_ID="usstg-ses-smtp-user-credentials"
SES_REGION="[email-smtp.us-west-2.amazonaws.com]:587"
BACKUP_DIR="/etc/postfix/backup"
BACKUP_FILE="${BACKUP_DIR}/sasl_passwd.db.$(date +%Y%m%d_%H%M%S)"
REGION="us-west-2"

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

##################################### Step-1 - Create Backup ################################
#############################################################################################

create_backup() {
    log_info "Starting backup process..."
    
    if ! mkdir -p "$BACKUP_DIR"; then
        log_error "Failed to create backup directory"
        return 1
    fi

    if [ -f /etc/postfix/sasl_passwd.db ]; then
        if ! cp /etc/postfix/sasl_passwd.db "$BACKUP_FILE"; then
            log_error "Failed to create backup"
            return 1
        fi
        log_info "Backup created at $BACKUP_FILE"
    else
        log_info "No existing configuration to backup"
    fi
}

################################### Step-2 - Update New Postfix Credentials #################
##############################################################################################

update_credentials() {
    log_info "Updating SMTP credentials..."
    
    # Get secret value
    SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query "SecretString" --region $REGION --output text)
    if [ $? -ne 0 ]; then
        log_error "Failed to retrieve secret value"
        return 1
    fi
    
    # Extract credentials
    SMTP_USERNAME=$(echo "$SECRET_VALUE" | grep -o '"Username":"[^"]*' | sed 's/"Username":"//') 
    if [ -z "$SMTP_USERNAME" ]; then
        log_error "Failed to extract SMTP username"
        return 1
    fi

    SMTP_PASSWORD=$(echo "$SECRET_VALUE" | grep -o '"Password":"[^"]*' | sed 's/"Password":"//') 
    if [ -z "$SMTP_PASSWORD" ]; then
        log_error "Failed to extract SMTP password"
        return 1
    fi

    log_info "Retrieved new credentials"
    log_info "SMTP Username: $SMTP_USERNAME"
    
    # Update postfix configuration
    if ! echo "$SES_REGION $SMTP_USERNAME:$SMTP_PASSWORD" | sudo tee /etc/postfix/sasl_passwd > /dev/null; then
        log_error "Failed to write new credentials"
        return 1
    fi

    if ! sudo postmap /etc/postfix/sasl_passwd; then
        log_error "Failed to update postfix map"
        return 1
    fi

    if ! sudo chown root:root /etc/postfix/sasl_passwd.db; then
        log_error "Failed to change ownership of sasl_passwd.db"
        return 1
    fi

    if ! sudo chmod 0600 /etc/postfix/sasl_passwd.db; then
        log_error "Failed to set permissions on sasl_passwd.db"
        return 1
    fi

    if ! sudo systemctl reload postfix; then
        log_error "Failed to reload postfix"
        return 1
    fi

    if ! sudo rm /etc/postfix/sasl_passwd; then
        log_error "Failed to remove temporary credentials file"
        return 1
    fi
    
    log_info "Postfix configuration updated successfully"
}

################################## Step-3 - Send Confirmation Email #########################
#############################################################################################

send_confirmation() {
    log_info "Sending confirmation email..."
    
    hostname=$(hostname)
    if [ $? -ne 0 ]; then
        log_error "Failed to get hostname"
        return 1
    fi

    ip_address=$(hostname -I | awk '{print $1}')
    if [ $? -ne 0 ]; then
        log_error "Failed to get IP address"
        return 1
    fi

    current_date=$(date +"%m-%d-%Y")

from="DevOps@firminiq.com"
to="awsalert.staging@ohiomron.com"
subject="US-STG-ALERT-SES - SMTP Credentials Updated For - $hostname | $current_date"

body="Hi Team,

SMTP Credentials have been updated for server: $hostname on $current_date
Please refer to detailed runbook at - https://omronhealthcare-ohi.atlassian.net/wiki/spaces/ODS/pages/3185213441/ODS-Alert-Runbook+AWS+Non-Compliant+IAM+SES+Users

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
        log_error "Failed to send confirmation email"
        return 1
    fi

    log_info "Confirmation email sent successfully"
}

# Main execution
main() {
    log_info "Starting SMTP credential update process..."
    
    create_backup || exit 1
    update_credentials || exit 1
    send_confirmation || exit 1
    
    log_info "SMTP credential update completed successfully"
}

# Execute main function
main