#!/bin/bash

# Parameter name where credentials are stored in SSM Parameter Store
SSM_PARAMETER_NAME="ODS-6247"
SES_REGION="[email-smtp.us-west-2.amazonaws.com]:587"

# Get credentials from SSM Parameter Store with decryption
CREDENTIALS=$(aws ssm get-parameter --name "$SSM_PARAMETER_NAME" --with-decrypt --query Parameter.Value --output text)

# Extract username and password (modify if format differs)
IFS=':' read -r SMTP_USERNAME SMTP_PASSWORD <<< "$CREDENTIALS"

echo "New Credentials"
echo "SMTP Username: $SMTP_USERNAME"
echo "SMTP Password: (Hidden for security)"

# Create sasl_passwd file with credentials and region
echo "$SES_REGION $SMTP_USERNAME:$SMTP_PASSWORD" | sudo tee /etc/postfix/sasl_passwd > /dev/null

# Generate sasl_passwd.db from sasl_passwd and Secure file permissions
sudo postmap /etc/postfix/sasl_passwd
sudo rm /etc/postfix/sasl_passwd
sudo chown root:root /etc/postfix/sasl_passwd.db
sudo chmod 0600 /etc/postfix/sasl_passwd.db
sudo systemctl reload postfix


# Send Email
hostname=$(hostname)
ip_address=$(hostname -I | awk '{print $1}')

from="DevOps@firminiq.com"
to="awsalert.staging@ohiomron.com"
subject="Test Parameter Store ---- US STG - SMTP Credentials Updated $hostname"
body="SMTP Credentials has been updated for server: (IP: $ip_address)"

sendmail -v -f "$from" "$to" <<EOF
Subject: $subject
From: $from
To: $to

$body

Best regards,
The DevOps Team
EOF