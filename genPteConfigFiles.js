var config = require('./config.json');
const fs = require('fs');
const path = require('path');

let ccDeployTemplate = {
  'channelID': '',
  'chaincodeID': 'samplecc',
  'chaincodeVer': 'v0',
  'transType': 'install',
  'TLS': 'enabled',
  'channelOpt': {
    'name': 'firstchannel',
    'action': 'create',
    'orgName': [
      'org1',
      'org2'
    ]
  },
  'deploy': {
    'chaincodePath': 'github.com/hyperledger/fabric-test/chaincodes/samplecc/go',
    'fcn': 'init',
    'args': []
  },
  'SCFile': [
    {
      'ServiceCredentials': 'config-chan1-TLS.json'
    }
  ]
}

ccDeployTemplate.chaincodeID = process.env.CHAINCODE || config.chaincode;
ccDeployTemplate.chaincodeVer = process.env.VERSION || config.cc_version;
ccDeployTemplate.chaincodePath = process.env.CCPATH || config.cc_path;
ccDeployTemplate.channelOpt.name = process.env.CHANNEL || config.channel;
ccDeployTemplate.channelOpt.orgName = [];
if (process.env.ORGS) {
  ccDeployTemplate.channelOpt.orgName.push(process.env.ORGS.split(','));
} else if (config.orgs) {
  let orgs = config.orgs.split(',');
  for (let i = 0; i < orgs.length; i++) {
    ccDeployTemplate.channelOpt.orgName.push(orgs[i]);
  }
}
///Write this to install.json
// console.log(ccDeployTemplate);
if (process.argv.length >= 2 && process.argv[2] == "deploy") {
  fs.writeFileSync(path.join(__dirname, process.env.CFG_DIR, 'install.json'), JSON.stringify(ccDeployTemplate, null, 4), 'utf-8')
}

ccDeployTemplate.transType = 'instantiate';
ccDeployTemplate.timeoutOpt = {};
ccDeployTemplate.timeoutOpt.preConfig = '120000';
ccDeployTemplate.timeoutOpt.request = '180000';
if (config.deploy_args && config.deploy_args.length > 0) {
  ccDeployTemplate.deploy.args = config.deploy_args;
}


///Write this to install.json
// console.log(ccDeployTemplate);
if (process.argv.length >= 2 && process.argv[2] == "deploy") {
  fs.writeFileSync(path.join(__dirname, process.env.CFG_DIR, 'instantiate.json'), JSON.stringify(ccDeployTemplate, null, 4), 'utf-8')
}

let transactionCfg = {
  "channelID": "",
  "chaincodeID": "samplecc",
  "chaincodeVer": "v0",
  "logLevel": "ERROR",
  "invokeCheck": "FALSE",
  "transMode": "Constant",
  "transType": "Invoke",
  "invokeType": "Move",
  "targetPeers": "OrgAnchor",
  "nProcPerOrg": "10",
  "nRequest": "0",
  "runDur": "600",
  "TLS": "enabled",
  "channelOpt": {
    "name": "firstchannel",
    "action": "create",
    "orgName": [
      "org1"
    ]
  },
};

transactionCfg.chaincodeID = process.env.CHAINCODE || config.chaincode;
transactionCfg.chaincodeVer = process.env.VERSION || config.cc_version;
transactionCfg.chaincodePath = process.env.CCPATH || config.cc_path;
transactionCfg.channelOpt.name = process.env.CHANNEL || config.channel;
transactionCfg.channelOpt.orgName = [];
if (config.transaction_orgs) {
  let orgs = config.transaction_orgs.split(',');
  for (let i = 0; i < orgs.length; i++) {
    transactionCfg.channelOpt.orgName.push(orgs[i]);
  }
}
transactionCfg.transMode = process.env.TRANS_MODE || config.transactionMode;
transactionCfg.transType = process.env.TRANS_TYPE || config.transactionType;
transactionCfg.invokeType = process.env.INVOKE_TYPE || config.invokeType;
transactionCfg.targetPeers = process.env.TARGET_PEERS || config.targetPeers;
if (config.targetPeers == "List") {
  transactionCfg.listOpt = config.listOpt;
}

transactionCfg.nProcPerOrg = process.env.PROCESSES || config.processes;
transactionCfg.nRequest = process.env.REQUESTS || config.requests;
transactionCfg.runDur = process.env.DURATION || config.duration;
transactionCfg.ccOpt = config.ccOpt;
transactionCfg.invoke = config.invoke;
transactionCfg.eventOpt = config.eventOpt;
transactionCfg.ccType =  process.env.CC_TYPE || config.ccType;
switch (config.transactionMode) {
  case 'Constant':
    transactionCfg.constantOpt = config.constantOpt;
    break;
  case 'Burst':
    transactionCfg.burstOpt = config.burstOpt;
    break;
  case 'Mix':
    transactionCfg.mixOpt = config.mixOpt;
    break;
  default:
    break;
}
transactionCfg.SCFile = [];
var scFile = { ServiceCredentials : process.env.SC_FILE || config.SCFile}
transactionCfg.SCFile.push(scFile);
// console.log(JSON.stringify(transactionCfg));
if (process.argv.length >= 2 && process.argv[2] == "transaction") {
  fs.writeFileSync(path.join(__dirname, process.env.CFG_DIR, 'invoke.json'), JSON.stringify(transactionCfg, null, 4), 'utf-8');
}