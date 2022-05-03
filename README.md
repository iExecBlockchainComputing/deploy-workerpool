# Table of contents

- [Table of contents](#table-of-contents)

- [Context](#context)

- [Requirements](#requirements)

- [Configuration](#configuration)

- [Deployment](#core-setup)

- [Status Checking](#status-checking)

# Context

This repository contains the necessary files to set up a scheduler (also known as core) and its workers.

  

The folllowing considerations must be taken into account :

  

- Only workepools for standard tasks (non TEE) are in the scope of this README.

  

- Services are exposed in HTTP by default, it is highly recommended configure SSL by installing the corresponding server certificates.

  

- Services must be connected to the [Bellecour](https://bellecour.iex.ec) iExec sidechain.

  

# Requirements

  

Server (minimal)

- One t2.medium AWS EC2 (or equivalent) server with 2 CPU, 4 GB of RAM and 16 GB of memory.

 
Software

- NodeJS

- [iExec SDK](https://www.npmjs.com/package/iexec)

- Docker & Docker-compose

  
  

# Configuration

  

### Scheduler Registration

  
  

- Open an empty directory

- Initialize your iExec workspace in this directory :

   <pre> iexec init --skip-wallet </pre> 

  

- Edit the "chain.json" file and change the "default" field from "viviani" to "bellecour"
<pre>
    ./$ cat chain.json
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
</pre> 
- Create a wallet for you scheduler (keep your password safe) :

    <pre>iexec wallet create --keystoredir $PWD </pre>

  

- Optionally you can import an existing wallet with the command :

    <pre>iexec wallet import your_private_key </pre>

  

- Rename the generated file as 'core_wallet.json' :

    <pre>mv UTC--* core_wallet.json</pre>

  

- Localy initialize you workerpool registration :

    <pre>iexec workerpool init --wallet-file "core_wallet.json" --keystoredir "$PWD"</pre>

  

- Once the workerpool has been registred correclty, a message will appear :

  

    <pre>Deployed new workerpool at address 0xabc...</pre>

  

You may also consult the workerpool metadata using the [explorer.](https://explorer.iex.ec/bellecour/workerpool/workerpooladdress)

  

Keep in mind that the workerpool address corresponds to the registration address and not the wallet owner address

  

- Edit the "iexec.json" file and change the "workerpool.description" field from the 'my-workerpool' default value.<br>

- This field will appear publicly on the blockchain and the marketplace.

- The "owner" field must match the public address of the "core_wallet.json" wallet file.

    <pre>./$ cat iexec.json
    
    ...
    
    "workerpool": {
    "owner": "0x6DdF0Bf919f108376136a64219B395117229BaF6",
    "description": "changeme"
    }
    
    ...
    
    </pre>

  

- Register your workerpool on the blockchain to get its "workerpool address" :<br>

    <pre>./$ iexec workerpool deploy --wallet-file "core_wallet.json" --keystoredir "$PWD" --chain bellecour
    
    ℹ Using chain bellecour [chainId: 134]
    
    ? Using wallet core_wallet.json
    
    Please enter your password to unlock your wallet [hidden]
    
    ✔ Deployed new workerpool at address 0x3c611ad1cAe35D563a5567a04475B0c31503bf4B
    
    </pre>

 
If using a "private" workerpool (all orders cost 0 RLC), the following section can be skipped :

  

- Send some RLC to the wallet "core_wallet.json" using you favorite tool (metamask/iexec cli/...)<br>

CHANGE THE "--to" ADDRESS BY YOUR OWN.

    <pre>iexec wallet send-RLC "10" --to "0x6DdF0Bf919f108376136a64219B395117229BaF6" --wallet-file ${YOUR_WALLET_FILE} --keystoredir ${YOU_WALLET_DIR}</pre>

  

- Send this amount to the iExec account of the wallet

    <pre>iexec account deposit "100000000" --wallet-file core_wallet.json --keystoredir $PWD
    
    </pre>

  
  

## Deployment

- Create 2 servers (or deploy  1 worker and 1 scheduler in one machine) :

- Server 1 will host Core services (scheduler)

- It should have a static IP or a DNS name.

- Server 2 hosts 1 to n workers

  

In this example, we will assume that server 1 is at ```"192.168.20.122"```

  

### Core (Scheduler)

  

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

- The ```"ORDER_PUBLISHER_REQUESTER_RESTRICT"``` is the address of the wallet is able to buy the orders.<br>

If set to ```"0x000000000000000000000000000000000000000"```, any one can use you order an run task on your workerpool.

  

One combination can be :

- set ```"ORDER_PUBLISHER_REQUESTER_RESTRICT"``` to some wallet you own

- set ```"ORDER_PRICE"``` to ```0```.

You will publish workerpool orders to run tasks as free, but only for your wallet.<br>

No one (but you) will be able to use you workerpool, and you will not have to bower with RLC staking.

If the ```"IEXEC_WORKER_OVERRIDE_AVAILABLE_CPU_COUNT"``` directive is removed, the service will automatically take up to n-1 available CPUs in the machine.

- When you're satistied by your configuration :

```"docker-compose up -d"```

  

- You can check 2 services:

- Blockchain Adapter as configuration manager :

```"http://192.168.20.122:13010/config/chain"```

- Core status :

```"http://192.168.20.122:7001/metrics"```

  

Both of then return a json file (metrics and configuration).

  

Congratulations, you know how to run a scheduler.

Let's add a worker to be fully functional

  

### Worker

  

You may create as many workers as you want, on the same server or one different one.

- Connect to "Server 2"

- Create the worker directory :

<pre>mkdir /opt/worker</pre>

- Populate this directory with :

- 2 files from this git repo : ```".env"``` and ```"worker_std/docker-compose.yml"```

- Create a new wallet with the same procedure used for the core.<br>

- Each worker will have its own wallet.

<pre>iexec wallet create --keystoredir $PWD

mv UTC--* worker_wallet.json

</pre>

- Stake some RLC to this wallet (if orders are not set to 0)

- Reuse the core ```".env"``` file

- set your ```"WORKER_NAME"```, should be unique.

- set the ```"PROD_WALLET_PASSWORD"``` to the wallet's password of this worker.

- You can remove the ```"#####<Core config>"``` parts

  

- Start your worker :

```"docker-compose up -d"```

  

# Status checking

- Reload the core status page, you should see 1 alive worker.

    <pre> curl http://192.168.20.122:7001/metrics

    </pre>

- You can also see the workerpool orders published on the marketplace, this is done by the order-publisher-std service in the core docker-compose file.

    <pre>iexec orderbook workerpool 0x3c611ad1cAe35D563a5567a04475B0c31503bf4B --requester 0x0123456789000000000000000000000000000000
    
    ℹ Using chain bellecour [chainId: 134]
    
    ℹ Workerpoolorders details (1 to 1 of 1):
    
    -
    orderHash: 0x8baea41297c249255ea9bb1584fb0093b1319ff253171d364151da5816576341
 
    price: 0   
    remaining: 1
    category: 0
    requesterrestrict: 0x0123456789000000000000000000000000000000
    ✔ No more results
    ℹ Trade in the browser at https://market.iex.ec
    
    </pre>

