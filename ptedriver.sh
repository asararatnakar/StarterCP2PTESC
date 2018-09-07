#!/bin/bash
echo "########################################################################"
echo "#                                                                      #"
echo "#                     P T E -  P E R F  T E S T                        #"
echo "#                                                                      #"
echo "########################################################################"

function log() {
    printf "${PROG}  ${1}\n" | tee -a run.log
}


export GOPATH=$PWD
mkdir -p src/github.com/hyperledger
cd src/github.com/hyperledger
if [ ! -e fabric-test ]; then
  git clone https://github.com/hyperledger/fabric-test
fi

cd fabric-test/tools/PTE

git checkout release-1.1 && git pull origin release-1.1

rm -rf inputFiles node_modules/ package-lock.json tmp.json
npm install

for dest_file in config-chan1-TLS.json genPteConfigFiles.js config.json
do
  cp ${GOPATH}/${dest_file} .
done

mkdir -p inputFiles

export PROG="SampleCC"
export CFG_DIR=inputFiles
log "Generate PTE Config files in dir: ${CFG_DIR}"

#### genetate txt files
echo "sdk=node ${CFG_DIR}/install.json" >& ${CFG_DIR}/install.txt
echo "sdk=node ${CFG_DIR}/instantiate.json" >& ${CFG_DIR}/instantiate.txt
echo "sdk=node ${CFG_DIR}/invoke.json" >& ${CFG_DIR}/invoke.txt
echo "sdk=node ${CFG_DIR}/query.json" >& ${CFG_DIR}/query.txt

node genPteConfigFiles.js "deploy"
node genPteConfigFiles.js "transaction"

./pte_driver.sh inputFiles/install.txt
./pte_driver.sh inputFiles/instantiate.txt

