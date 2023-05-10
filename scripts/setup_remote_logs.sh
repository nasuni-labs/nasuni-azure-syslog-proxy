#!/bin/sh
echo "Setting up remote log configuration for rsyslog"
printf '$template RemoteLogs,"/var/log/remote-logs/%%HOSTNAME%%/%%PROGRAMNAME%%.log"\n*.*?RemoteLogs\n& stop\' > /etc/rsyslog.d/10-remote.conf

sed '/#module(load="imudp") # needs to be done just once/s/^#//' -i /etc/rsyslog.conf
sed '/#input(type="imudp" port="514")/s/^#//' -i /etc/rsyslog.conf
sed '/#module(load="imtcp") # needs to be done just once/s/^#//' -i /etc/rsyslog.conf
sed '/#input(type="imtcp" port="514")/s/^#//' -i /etc/rsyslog.conf

systemctl restart rsyslog