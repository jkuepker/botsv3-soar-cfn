#!/bin/bash -xe
set -x
exec > >(tee /var/log/splunk-config-data.log|logger -t splunk-config ) 2>&1
echo BEGIN
date '+%Y-%m-%d %H:%M:%S'
cd /tmp
while [[ "$(curl -s -o /dev/null -w "%{http_code}" https://127.0.0.1:8089/services/authentication/users -k -u "admin:SPLUNK-$(curl -s http://instance-data/latest/meta-data/instance-id)")" != "200" ]]; do printf "Waiting for Splunk to become available\n"; sleep 10; done
wget "https://webaccessible-jkuepker.s3.amazonaws.com/splunk-app-for-phantom-reporting_100.tgz"
wget "https://webaccessible-jkuepker.s3.amazonaws.com/phantom-remote-search_1014.tgz"
wget "https://webaccessible-jkuepker.s3.amazonaws.com/phantom_hec_inputs.conf"
wget "https://webaccessible-jkuepker.s3.amazonaws.com/user-prefs.conf"
su splunk -c "tar -zxvf phantom-remote-search_1014.tgz -C /opt/splunk/etc/apps/"
su splunk -c "tar -zxvf splunk-app-for-phantom-reporting_100.tgz -C /opt/splunk/etc/apps/"
su splunk -c "mkdir -p /opt/splunk/etc/apps/splunk_httpinput/local"
su splunk -c "cp phantom_hec_inputs.conf /opt/splunk/etc/apps/splunk_httpinput/local/inputs.conf"
su splunk -c "cp user-prefs.conf /opt/splunk/etc/system/local/user-prefs.conf"
wget -nv https://webaccessible-jkuepker.s3.amazonaws.com/botsv3apps.tgz
tar zxf botsv3apps.tgz
cd /tmp/botsv3apps
wget -nv https://botsdataset.s3.amazonaws.com/botsv3/botsv3_data_set.tgz
chown -R splunk:splunk /tmp/botsv3apps
echo "install BOTS v3 apps"
for f in *.tgz; do su splunk -c "tar -zxf "$f" -C /opt/splunk/etc/apps/"; done
systemctl restart Splunkd
while [[ "$(curl -s -o /dev/null -w "%{http_code}" https://127.0.0.1:8089/services/authentication/users -k -u "admin:SPLUNK-$(curl -s http://instance-data/latest/meta-data/instance-id)")" != "200" ]]; do printf "Waiting for Splunk to become available\n"; sleep 10; done
iid=$(curl "http://169.254.169.254/latest/meta-data/instance-id") su splunk -c '/opt/splunk/bin/splunk add user phantomsearchuser -password $iid -role phantomsearch -full-name "Phantom Search" -force-change-pass false -auth "admin:SPLUNK-$iid"'
iid=$(curl "http://169.254.169.254/latest/meta-data/instance-id") su splunk -c '/opt/splunk/bin/splunk add user phantomdeleteuser -password $iid -role phantomdelete -full-name "Phantom Delete" -force-change-pass false -auth "admin:SPLUNK-$iid"'