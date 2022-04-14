# Table of contents
- [Table of contents](#table-of-contents)
- [Context](#context)
- [Restrictions and recommandations](#restrictions-and-recommandations)
- [Deploy my workerpool](#deploy-my-workerpool)
  - [Core setup](#core-setup)
    - [Core Registration](#core-registration)
    - [Docker Config](#docker-config)
      - [Docker for core](#docker-for-core)
      - [Docker for worker](#docker-for-worker)
   
# Context
Here a repository to help you:
- To deploy a scheduler and its workers
- To register them on the iExec sidechain
- To publish "Workerpool Orders" and run task


The scheduler (also named "core") is to 

# Restrictions and recommandations
- Only standard task, no SGX definition in this example.
- Pay attention to the "workerpool orders" you will publish
- All web services are exposed in HTTP and not HTTPS, we encourage you to setup a HTTPS endpoint if you plan to expose these services to anyone.
- You will be connected to the main iExec sidechain : bellecour (see : https://blockscout-bellecour.iex.ec/ or https://bellecour.iex.ec)

# Deploy my workerpool
You should instal the iExec sdk CLI : https://github.com/iExecBlockchainComputing/iexec-sdk
## Core setup
### Core Registration
- Open an empty directory
  
- Initialize your iExec workspace in this directory :
  <pre>iexec init --skip-wallet </pre>

- Edit the "chain.json" and change the "default" field from "viviani" to "bellecour"
  <pre>./$ cat chain.json 
  {
    "default": "bellecour",
    "chains": {
      "goerli": {},
      "viviani": {},
      "mainnet": {},
      "bellecour": {},
      "enterprise": {},
      "enterprise-testnet": {}
    }
  }</pre>

- Create a wallet for you scheduler (keep your password safe) :
  <pre>iexec wallet create --keystoredir $PWD </pre>

- Rename the generated file as 'core_wallet.json' :
  <pre>mv UTC--* core_wallet.json</pre>

- Localy initialize you workerpool registration :
  <pre>iexec workerpool init --wallet-file "core_wallet.json" --keystoredir "$PWD"</pre>

- Edit the "iexec.json" file and change the "workerpool.description" field to something better than 'my-workerpool'.<br>
  - This field will appears publicly on the blockchain and the marketplace.
  - Your "owner" will be different, and should match the public address of the "core_wallet.json" wallet file.
  <pre>./$ cat iexec.json
  ...
    "workerpool": {
    "owner": "0x6DdF0Bf919f108376136a64219B395117229BaF6",
    "description": "demo-1"
  }
  ...
  </pre>

- Register you workerpool on the blockchain to get its "workerpool address" :<br>
  <pre>./$ iexec workerpool deploy --wallet-file "core_wallet.json" --keystoredir "$PWD" --chain bellecour
  ℹ Using chain bellecour [chainId: 134]
  ? Using wallet core_wallet.json
  Please enter your password to unlock your wallet [hidden]
  ✔ Deployed new workerpool at address 0x3c611ad1cAe35D563a5567a04475B0c31503bf4B
  </pre>

- Send some RLC to the wallet "core_wallet.json" using you favorite tool (metamask/iexec cli/...)<br>
  CHANGE THE "--to" ADDRESS BY YOUR OWN.
  <pre>iexec wallet send-RLC "10" --to "0x6DdF0Bf919f108376136a64219B395117229BaF6" --wallet-file ${YOUR_WALLET_FILE} --keystoredir ${YOU_WALLET_DIR}</pre>

- Send this amount to the iExec account of the wallet
  <pre>iexec account deposit "100000000" --wallet-file core_wallet.json --keystoredir $PWD
  </pre>

-  Have a coffe, you're not done yet :-)

### Docker Config
- Create 2 servers : 
  - Server 1 will host Core services
    - Docker should be installed
    - It should have a static IP or a DNS name.
  - Server 2 will host a worker
    - Docker should be installed<br>
  Later, you can add as many workers as you want.

  During this example, we will assume that server 1 is at ```"192.168.20.122"```

#### Docker for core

- Connect to your "Server 1"
- Create the core directory :
  <pre>mkdir /opt/core</pre>
- Populate this directory with :
  - the previously created ```"core_wallet.json"```
  - 2 files from this git repo : ```".env"``` and ```"core_std/docker-compose.yml"```

- Update some variables in the ```".env"``` file :
  
| Variables|Value|
|----------|-----|
|PROD_CHAIN_ADAPTER_HOST | 192.168.20.122|
|PROD_CHAIN_ADAPTER_PROTOCOL | http |
|PROD_CHAIN_ADAPTER_PORT| 13010|
|PROD_CORE_HOST|192.168.20.122|
|PROD_CORE_PROTOCOL|http|
|PROD_CORE_PORT|7001|
|PROD_CHAIN_ADAPTER_PASSWORD| changeme|
|PROD_CORE_WALLET_PASSWORD| changeme|
|PROD_GRAFANA_ADMIN_PASSWORD| changeme|
|PROD_MONGO_PASSWORD|changeme|
|PROD_POOL_ADDRESS|0x3c611ad1cAe35D563a5567a04475B0c31503bf4B|

- Each password should be randmly generated.<br>
- The ```"PROD_CORE_WALLET_PASSWORD"``` is the password of the ```"core_wallet.json"``` file<br>
- The ```"PROD_POOL_ADDRESS"``` is resulting from the ```"iexec workerpool deploy"``` command
- The ```"ORDER_PUBLISHER_REQUESTER_RESTRICT"``` is the adresse of the wallet who will be able to buy the orders.<br>
If set to ```"0x000000000000000000000000000000000000000"```, any one can use you order an run task on your workerpool.

One combination can be : 
- set ```"ORDER_PUBLISHER_REQUESTER_RESTRICT"``` to some wallet you own
- set ```"ORDER_PRICE"```  to ```0```.
  You will publish workerpool orders to run tasks as free, but only for your wallet.<br>
  No one (but you) will be able to use you workerpool, and you will not have to bower with RLC staking.

- When you're satify by your configuration :
```"docker-compose up -d"```

- You can check 2 services:
  - Blockchain Adapter as configuration manager :
  ```"http://192.168.20.122:13010/config/chain"```
  - Core status :
  ```"http://192.168.20.122:7001/metrics"```

  Both of then should give you nice json.

  Congratulation, you now how a running scheduler.
  Let's add a worker to be fully functionnal

#### Docker for worker
You can create as many worker as you want, on the same server or one different one.
- Connect to your "Server 2"
- Create the worker directory :
  <pre>mkdir /opt/worker</pre>
- Populate this directory with :
  - 2 files from this git repo : ```".env"``` and ```"worker_std/docker-compose.yml"```
  
  -  create a new wallet like you did for the core.<br>
  Each worker have its own wallet.
  <pre>iexec wallet create --keystoredir $PWD
  mv UTC--* worker_wallet.json
  </pre>
  - Stake some RLC to this wallet like before.
- Reuse the core ```".env"``` file
  - set your ```"WORKER_NAME"```, should be unique.
  - set the ```"PROD_WALLET_PASSWORD"``` to the wallet's password of this worker.
  - You can remove the ```"#####<Core config>"``` parts

- Start your worker : 
```"docker-compose up -d"```

- Reload the core status page, you should see 1 alive worker.
  <pre> curl http://192.168.20.122:7001/metrics
  </pre>
  
