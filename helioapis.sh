#!/usr/bin/env bash

export PATH=$PATH:$PWD/bin/

# source ./starter_scale_test.cfg
DATESTR=$(date +%Y-%m-%d" "%H:%M:%S" "%p)
PROG="[hfrd-apis]"
LOGFILE="$(pwd)/logs/starter_scale_test.log"
ARCH=`uname -s | grep Darwin`
if [ "$ARCH" == "Darwin" ]; then
	OPTS="-it"
else
	OPTS="-i"
fi
function log() {
	printf "${PROG}  ${1}\n" | tee -a run.log
}

function checkKubeConfig(){
	kubectl get po > /dev/null 2>&1
	if test "$?" != "0" ; then
		echo "!!!!! ==== export KUBECONFIG environment variable & Rerun ==== !!!!!"
		exit
	fi
}

# checkKubeConfig
####################
# Helper Functions #
####################
get_pem() {
	awk '{printf "%s\\n", $0}' creds/org"$1"admin/msp/signcerts/cert.pem
}


API_ENDPOINT=$(jq -r .org1.url creds/network.json)
NETWORK_ID=$(jq -r .org1.network_id creds/network.json)
ORG1_API_KEY=$(jq -r .org1.key creds/network.json)
ORG2_API_KEY=$(jq -r .org2.key creds/network.json)
ORG1_API_SECRET=$(jq -r .org1.secret creds/network.json)
ORG2_API_SECRET=$(jq -r .org2.secret creds/network.json)
ORG1_ENROLL_SECRET=$(jq -r '.certificateAuthorities["org1-ca"].registrar[0].enrollSecret' creds/org1.json)
ORG2_ENROLL_SECRET=$(jq -r '.certificateAuthorities["org2-ca"].registrar[0].enrollSecret' creds/org2.json)
ORG1_CA_URL=$(jq -r '.certificateAuthorities["org1-ca"].url' creds/org1.json | cut -d '/' -f 3)
ORG2_CA_URL=$(jq -r '.certificateAuthorities["org2-ca"].url' creds/org2.json | cut -d '/' -f 3)


############################################################
# STEP 1 - generate user certs and upload to remote fabric #
############################################################
# save the cert
jq -r '.certificateAuthorities["org1-ca"].tlsCACerts.pem' creds/org1.json > cacert.pem
log "Enrolling admin user for org1."
export CA_VERSION=1.1.0
export ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
if [ ! -f bin/fabric-ca-client ]; then
	curl https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric-ca/hyperledger-fabric-ca/${ARCH}-${CA_VERSION}/hyperledger-fabric-ca-${ARCH}-${CA_VERSION}.tar.gz | tar xz
else
	log "fabric-ca-client already exists ... skipping download"
fi


export FABRIC_CA_CLIENT_HOME=${PWD}/creds/org1admin
fabric-ca-client enroll --tls.certfiles ${PWD}/cacert.pem -u https://admin:${ORG1_ENROLL_SECRET}@${ORG1_CA_URL} --mspdir ${PWD}/creds/org1admin/msp
# rename the keyfile
mv creds/org1admin/msp/keystore/* creds/org1admin/msp/keystore/priv.pem
# upload the cert
BODY1=$(cat <<EOF1
{
	"msp_id": "org1",
	"adminCertName": "PeerAdminCert1",
	"adminCertificate": "$(get_pem 1)",
	"peer_names": [
		"org1-peer1"
	],
	"SKIP_CACHE": true
}
EOF1
)
log "Uploading admin certificate for org 1."
curl -s -X POST \
	--header 'Content-Type: application/json' \
	--header 'Accept: application/json' \
	--basic --user ${ORG1_API_KEY}:${ORG1_API_SECRET} \
	--data "${BODY1}" \
    ${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/certificates

# STEP 1.2 - ORG2
log "Enrolling admin user for org2."
export FABRIC_CA_CLIENT_HOME=${PWD}/creds/org2admin
fabric-ca-client enroll --tls.certfiles ${PWD}/cacert.pem -u https://admin:${ORG2_ENROLL_SECRET}@${ORG2_CA_URL} --mspdir ${PWD}/creds/org2admin/msp
# rename the keyfile
mv creds/org2admin/msp/keystore/* creds/org2admin/msp/keystore/priv.pem
# upload the cert
BODY2=$(cat <<EOF2
{
 "msp_id": "org2",
 "adminCertName": "PeerAdminCert2",
 "adminCertificate": "$(get_pem 2)",
 "peer_names": [
   "org2-peer1"
 ],
 "SKIP_CACHE": true
}
EOF2
)
log "Uploading admin certificate for org 2."
curl -s -X POST \
	--header 'Content-Type: application/json' \
	--header 'Accept: application/json' \
	--basic --user ${ORG2_API_KEY}:${ORG2_API_SECRET} \
	--data "${BODY2}" \
    ${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/certificates


##########################
# STEP 2 - restart peers #
##########################
# STEP 2.1 - ORG1
PEER="org1-peer1"
log "Stoping ${PEER}"
curl -s -X POST \
	--header 'Content-Type: application/json' \
	--header 'Accept: application/json' \
	--basic --user ${ORG1_API_KEY}:${ORG1_API_SECRET} \
	--data-binary '{}' \
	${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/nodes/${PEER}/stop

# sleep 15
log "Waiting for ${PEER} to stop..."
RESULT=""
while [[ ${RESULT} != "exited" ]]; do
	RESULT=$(curl -s -X GET \
		--header 'Content-Type: application/json' \
		--header 'Accept: application/json' \
		--basic --user ${ORG1_API_KEY}:${ORG1_API_SECRET} \
		${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/nodes/status | jq -r '.["'${PEER}'"].status')
done
log "${RESULT}"

log "Starting ${PEER}"
curl -s -X POST \
	--header 'Content-Type: application/json' \
	--header 'Accept: application/json' \
	--basic --user ${ORG1_API_KEY}:${ORG1_API_SECRET} \
	--data-binary '{}' \
	${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/nodes/${PEER}/start

log "Waiting for ${PEER} to start..."
RESULT=""
while [[ ${RESULT} != "running" ]]; do
	RESULT=$(curl -s -X GET \
		--header 'Content-Type: application/json' \
		--header 'Accept: application/json' \
		--basic --user ${ORG1_API_KEY}:${ORG1_API_SECRET} \
		${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/nodes/status | jq -r '.["'${PEER}'"].status')
done
log "${RESULT}"

# STEP 2.2 - ORG2
PEER="org2-peer1"
log "Stoping ${PEER}"
curl -s -X POST \
	--header 'Content-Type: application/json' \
	--header 'Accept: application/json' \
	--basic --user ${ORG2_API_KEY}:${ORG2_API_SECRET} \
	--data-binary '{}' \
	${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/nodes/${PEER}/stop

# sleep 15
log "Waiting for ${PEER} to stop..."
RESULT=""
while [[ $RESULT != "exited" ]]; do
	RESULT=$(curl -s -X GET \
		--header 'Content-Type: application/json' \
		--header 'Accept: application/json' \
		--basic --user ${ORG2_API_KEY}:${ORG2_API_SECRET} \
		${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/nodes/status | jq -r '.["'${PEER}'"].status')
done
log "${RESULT}"

log "Starting ${PEER}"
curl -s -X POST \
	--header 'Content-Type: application/json' \
	--header 'Accept: application/json' \
	--basic --user ${ORG2_API_KEY}:${ORG2_API_SECRET} \
	--data-binary '{}' \
	${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/nodes/${PEER}/start

log "Waiting for ${PEER} to start..."
RESULT=""
while [[ $RESULT != "running" ]]; do
	RESULT=$(curl -s -X GET \
		--header 'Content-Type: application/json' \
		--header 'Accept: application/json' \
		--basic --user ${ORG2_API_KEY}:${ORG2_API_SECRET} \
		${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/nodes/status | jq -r '.["'${PEER}'"].status')
done
log "${RESULT}"


#########################
# STEP 3 - SYNC CHANNEL #
#########################
log "Syncing the channel."
curl -s -X POST \
	--header 'Content-Type: application/json' \
  	--header 'Accept: application/json' \
  	--basic --user ${ORG1_API_KEY}:${ORG1_API_SECRET} \
  	--data-binary '{}' \
  	${API_ENDPOINT}/api/v1/networks/${NETWORK_ID}/channels/defaultchannel/sync

### TODO: This is for local testing, remove this for actual tests
export HOME=$PWD
# export GOPATH=$PWD/go
# export PTE_PATH=$PWD/go/src/github.com/hyperledger/fabric-test/tools/PTE/

python ${HOME}/scripts/2o2pp-1ch-create_SCFile.py

# Sanity check to see if the PTE config file is generated
if [[ ! -f ${HOME}/config-chan1-TLS.json ]]; then
	echo "Failed to generate config-chan1-TLS.json, cannot continue."
	exit 1
fi
echo "Now execute ptetest.sh , make sure you configure config.json"
echo "========= A D M I N   C E R T S   A R E   S Y N C E D  O N   C H A N N E L ============="
# mkdir -p ${HOME}/pteconfigs/${NETWORK_ID}/
# cp ${HOME}/scripts/config-chan1-TLS.json ${HOME}/pteconfigs/${NETWORK_ID}/config-chan1-TLS.json
