# starter_scale

**Step 1:**

a. Replace creds/org1.json and creds/org2.json with connection profiles of corresponding orgs

b. Replace the corresonding section in network.json with your API network credentials


Generate admin certs upload them to the peers and sync the channel

```
./helioapis.sh
```

you will see a succesful message something like the following 

```
========= A D M I N   C E R T S   A R E   S Y N C E D  O N   C H A N N E L =============
```

execute the pte test setup by issuing the following command:

```
./ptedriver.sh
```
**This will install & instantiates the chaincode**

Go to the directory `src/github.com/hyperledger/fabric-test/tools/PTE`
modify config.json to change the required params like chnanel name , chaincode path, payload size etc., and then run the following commands

```
node genPteConfigFiles.js "transaction"

./pte_driver.sh inputFiles/invoke.txt
```



