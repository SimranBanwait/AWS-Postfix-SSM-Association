#!/bin/bash

SECRET_ID="ODS-6247"
SES_REGION="[email-smtp.us-west-2.amazonaws.com]:587"

SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query "SecretString" --output text)

SMTP_USERNAME=$(echo "$SECRET_VALUE" | grep -o '"Username":"[^"]*' | sed 's/"Username":"//')
SMTP_PASSWORD=$(echo "$SECRET_VALUE" | grep -o '"Password":"[^"]*' | sed 's/"Password":"//')

echo "New Credentials"
echo "SMTP Username: $SMTP_USERNAME"
echo "SMTP Password: (Hidden for security)"


echo "$SES_REGION $SMTP_USERNAME:$SMTP_PASSWORD" | sudo tee /etc/postfix/sasl_passwd > /dev/null

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
subject="Test Secret Manager ---- US STG - SMTP Credentials Updated $hostname"
body="SMTP Credentials has been updated for server: $hostname (IP: $ip_address)"

sendmail -v -f "$from" "$to" <<EOF
Subject: $subject
From: $from
To: $to

$body

Best regards,
The DevOps Team
EOF

