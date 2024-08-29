
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
echo "SMTP Password: (hidden for security)"

# Create sasl_passwd file with credentials and region
echo "$SES_REGION $SMTP_USERNAME:$SMTP_PASSWORD" | sudo tee /etc/postfix/sasl_passwd > /dev/null

# Generate sasl_passwd.db from sasl_passwd
sudo postmap /etc/postfix/sasl_passwd

# Secure file permissions
sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

# Reload postfix service
sudo systemctl reload postfix

# Send Email notification (optional, modify details as needed)
# ... (rest of the script for sending email notification remains the same)

# Send Email
hostname=$(hostname)
ip_address=$(hostname -I | awk '{print $1}')

from="DevOps@firminiq.com"
to="awsalert.staging@ohiomron.com"
subject="Testing------------ US DEV - SMTP Credentials Updated $hostname"
body="SMTP Credentials has been updated for server: (IP: $ip_address)"

sendmail -v -f "$from" "$to" <<EOF
Subject: $subject
From: $from
To: $to

$body

Best regards,
The DevOps Team
EOF

