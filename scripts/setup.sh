WORKSPACE_ID=$1
SAS_TOKEN=$2


# Install required packages

dnf upgrade
dnf install rsyslog


# Get rsyslog configuration
wget $ARTIFACTS_LOCATION/configs/rsyslog.conf$SAS_TOKEN
wget $ARTIFACTS_LOCATION/configs/10-remote.conf$SAS_TOKEN

mkdir /var/log/remote-logs/
mv -f rsyslog.conf /etc/
mv 10-remote.conf /etc/rsyslog.d/


# Install Sentinel agent
# wget https://raw.githubusercontent.com/Microsoft/OMS-Agent-for-Linux/master/installer/scripts/onboard_agent.sh && sh onboard_agent.sh -w $WORKSPACE_ID -s $PRIMARYKEY -d opinsights.azure.com

# Restart rsyslog service
systemctl restart rsyslog