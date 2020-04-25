#!/bin/bash -xe
set -x
exec > >(tee /var/log/phantom-config-data.log|logger -t phantom-config ) 2>&1
echo BEGIN
date '+%Y-%m-%d %H:%M:%S'
rm -rf /var/cache/yum/x86_64/7/timedhosts.txt
cd /tmp
echo "Install AWS CLI Tools"
yum install unzip -y -q
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -f awscliv2.zip
echo "Wait for Phantom REST API to become available."
while [[ "$(curl -s -o /dev/null -w "%{http_code}" https://127.0.0.1/rest/system_info -k -u "admin:$(curl -s http://instance-data/latest/meta-data/instance-id)")" != "200" ]]; do printf "Waiting for Phantom to become available\n"; sleep 30; done
echo "Connect Phantom REST API to Splunk for External Search"
curl -k -u "admin:$(curl 'http://169.254.169.254/latest/meta-data/instance-id')" "https://127.0.0.1/rest/system_settings" -H 'Content-Type: application/json' -d '{"search_settings": {"status": "Automatic", "elastic_search": {"enabled": false}, "splunk": {"local": {"enabled": "false", "rest": {"use_ssl": true, "verify_ssl": false, "port": 5122, "client_auth": false}, "host": "127.0.0.1", "user": {"admin": {"username": "admin", "password": "c9yW3J+IGRTsajSbtDbGTkIKI/Lmob6yaK79SPLDDiY="}, "search": {"username": "phantomsearch", "password": "/voQDqQCbRoX9ZDKK1pk3HNfd9ktfPYNEYe2/2PtF9c="}, "delete": {"username": "phantomdelete", "password": "v26PV6rs1RBBZKiwJu9i4B3iRHpYnfbAOEjgFGhzZSs="}}, "hec": {"use_ssl": true, "token": "bfd7af27-7f0c-4790-9472-f8832343fa6f", "client_auth": false, "verify_ssl": false, "port": 5121}, "type": "standalone"}, "remote": {"enabled": true, "rest": {"use_ssl": true, "verify_ssl": false, "port": "8089"}, "host": "'$(cat "/tmp/test.txt")'", "user": {"search": {"username": "phantomsearchuser", "password": "phantomsearchpass"}, "delete": {"username": "phantomdeleteuser", "password": "phantomdeletepass"}}, "hec": {"use_ssl": true, "token": "8106a7ac-7856-4be2-a005-942c82768932", "verify_ssl": false, "port": "8088"}, "type": "standalone"}}}}'
#curl -k -u "admin:$(curl 'http://169.254.169.254/latest/meta-data/instance-id')" "https://127.0.0.1/rest/asset" -H 'Content-Type: application/json' -d '{ "product_version": "", "disabled": false, "id": 7, "_pretty_secondary_roles": [], "_pretty_primary_roles": [], "_pretty_secondary_owners": [], "version": 1, "type": "generic", "product_name": "Generator", "action_whitelist": {}, "description": "", "tags": [], "_pretty_primary_owners": [], "primary_voting": 0, "secondary_voting": 0, "configuration": { "limit_status_to_new": true, "create_artifacts": 10, "create_containers": 10, "event_severity": "Random", "ingest": { "container_label": "events", "start_time_epoch_utc": null }, "_reserved_environment_variables": {}, "event_sensitivity": "Random", "event_status": "Random", "artifact_count_override": false }, "product_vendor": "Generic", "effective_user": 2, "name": "jalapenobusiness", "token": null, "validation": {}, "tenants": [], "_pretty_effective_user": "automation" }'
echo "Check for VT API Key and create asset."
source env.txt
export $(cut -d= -f1 env.txt)
if [[ ! -z "${VT_KEY}" ]]; then
  curl -k -u "admin:$(curl 'http://169.254.169.254/latest/meta-data/instance-id')" "https://127.0.0.1/rest/asset" -H 'Content-Type: application/json' -d "{\"action_whitelist\":{},\"configuration\":{\"apikey\":\"${VT_KEY}\",\"rate_limit\":true},\"disabled\": false, \"type\": \"reputation\", \"description\":\"Auto configured by CloudFormation\",\"name\":\"phantom-vt-config\",\"product_name\":\"VirusTotal\",\"product_vendor\":\"VirusTotal\", \"tags\":[]}"
fi
echo "Configure Generator App"
curl -k -u "admin:$(curl 'http://169.254.169.254/latest/meta-data/instance-id')" "https://127.0.0.1/rest/asset" -H 'Content-Type: application/json' -d '{ "disabled": false, "type": "generic", "product_name": "Generator", "description": "Asset to generate example events.", "tags": ["phantom-config"], "configuration": { "limit_status_to_new": true, "create_artifacts": 10, "create_containers": 10, "event_severity": "Random", "ingest": { "container_label": "events", "start_time_epoch_utc": null }, "event_sensitivity": "Random", "event_status": "Random", "artifact_count_override": false }, "product_vendor": "Generic", "name": "phantom-generator" }'
echo "Activating Onboarding Demonstration Playbook"
curl -k -u "admin:$(curl 'http://169.254.169.254/latest/meta-data/instance-id')" "https://127.0.0.1/rest/playbook/30" -H 'Content-Type: application/json' -d '{ "active": true, "cancel_runs": false }'
echo "TEST - Disabling Initial Onboarding"
curl -k -u "admin:$(curl 'http://169.254.169.254/latest/meta-data/instance-id')" "https://127.0.0.1/rest/user_settings" -H 'Content-Type: application/json' -d '{ "redirect_onboarding": false, "show_onboarding": false }'
echo "TEST - Disabling EULA, adding Company Name, changing Instance Name, configuring FQDN"
psql -d phantom -c "UPDATE system_settings SET administrator_contact = 'newadmin@localhost', company_name = 'Splunk', system_name = '${INAME}', eula_accepted = true, fqdn = '$(curl -s http://instance-data/latest/meta-data/network/interfaces/macs/$(curl -s http://instance-data/latest/meta-data/network/interfaces/macs)local-ipv4s)' WHERE system_settings.id = 1;"
echo "Install Completed"
touch phantom-config-complete
echo END