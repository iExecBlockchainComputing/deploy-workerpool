# Table of contents

- [Table of contents](#table-of-contents)

- [Context](#context)

- [Requirements](#requirements)

- [Configuration](#configuration)
    - [Core (Scheduler) Registration](#core-scheduler-registration)
    - [Customization](#Customization)

- [Deployment](#Deployment)
    - [Core (Scheduler) service deployment](#Core-Scheduler-service-deployment)
    - [Worker service deployment](#Worker-service-deployment)

- [Status Checking](#status-checking)

- [Going further (unsupported yet)](#Going-further-unsupported-yet)

# Context

This repository contains the necessary files to set up a scheduler (also known as core) and its workers.

  

The folllowing considerations must be taken into account :

  

- Only workepools for standard tasks (non TEE) are in the scope of this README.

  

- Services are exposed in HTTP by default, it is highly recommended configure SSL by installing the corresponding server certificates.

  

- Services must be connected to the [Bellecour](https://bellecour.iex.ec) iExec sidechain.

  

# Requirements

Server (minimal)

- t2.medium AWS EC2 (or equivalent) server with 2 CPU, 4 GB of RAM and 16 GB of memory.

Server (minimal recommended)

- t2.xlarge AWS EC2 (or equivalent) server with 4 CPU, 16 GB of RAM and 16 GB of memory.

 
Software

- NodeJS

- [iExec SDK](https://www.npmjs.com/package/iexec)

- Docker & Docker-compose



# Configuration

## Core (Scheduler) Registration

- Open an empty directory

- Initialize your iExec workspace in this directory :

<pre>
   iexec init --skip-wallet 
</pre> 

  

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

- Create a wallet for you scheduler (keep the core's wallet password safe) :

<pre>
    iexec wallet create --keystoredir $PWD 
    mv UTC--* core_wallet.json
</pre>

  

- Optionally, instead of creating a new wallet, you can import an existing wallet with the command :

<pre>
    iexec wallet import your_private_key 
</pre>

    
- Create a wallet for you worker (keep the worker's wallet password safe) :

<pre>
    iexec wallet create --keystoredir $PWD 
    mv UTC--* worker_wallet.json
</pre>

  

- Localy initialize you workerpool registration :

<pre>
    iexec workerpool init --wallet-file "core_wallet.json" --keystoredir "$PWD"
</pre>

  

- Edit the "iexec.json" file and change the "workerpool.description" field from the 'my-workerpool' default value. This field will appear publicly on the blockchain and the marketplace.

- Make sure the "owner" field of iexec.json file matches the "address" field of the "core_wallet.json" file.

<pre>
    ./$ jq .workerpool iexec.json 
        
    "workerpool": {
        "owner": "0x6DdF0Bf919f108376136a64219B395117229BaF6",
        "description": "my-workerpool"
    }
</pre>

  

- Register your workerpool on the blockchain to get its workerpool address :<br>

<pre>
    ./$ iexec workerpool deploy --wallet-file "core_wallet.json" --keystoredir "$PWD"
    
    ℹ Using chain bellecour [chainId: 134]
    
    ? Using wallet core_wallet.json
    
    Please enter your password to unlock your wallet [hidden]
    
    ✔ Deployed new workerpool at address 0xabc...
    
</pre>


Save your workerpool (deployment) address for later use (you might also find it in the deployed.json)
  

You may now consult the workerpool metadata by typing your workerpool address into the search area on the [explorer](https://explorer.iex.ec/bellecour/).

  

Keep in mind that the workerpool address corresponds to your workerpool registration address and not the wallet owner address. 

 
If using a free workerpool (workerpool orders with price = 0 RLC), you can jump to the next section ([Deployment](#Deployment)) by
skiping puting and staking some RLC on the core's and worker's wallets (next step). 
  

- First, put some RLC to the core's and worker's wallets using you favorite tool (metamask/iexec cli/...). Obviously, you need some RLC on another wallet for this.  

Example using the iexec CLI :

<pre>
    iexec wallet send-RLC "10" --to ${DEST_WALLET_ADDRESS} --wallet-file ${YOUR_OTHER_WALLET_WITH_RLC_FILE} --keystoredir ${DIRECTORY_OF_YOUR_OTHER_WALLET_WITH_RLC}
</pre>

  

- Then stake this amount of RLC to the iExec account of the wallets

<pre>
    iexec account deposit "100000000" --wallet-file core_wallet.json --keystoredir "$PWD"
    iexec account deposit "100000000" --wallet-file worker_wallet.json --keystoredir "$PWD"
</pre>

  

## Customization

- Copy / clone this repo locally

- Before spreading files, your need to customize a minimal set of variables in the .env file : 

<pre>
    PROD_CHAIN_ADAPTER_PASSWORD
    PROD_GRAFANA_ADMIN_PASSWORD
    PROD_MONGO_PASSWORD
    PROD_CORE_WALLET_PASSWORD
    PROD_WALLET_PASSWORD
    PROD_CORE_HOST
    PROD_CHAIN_ADAPTER_HOST
    PROD_GRAFANA_HOST
    WORKER_AVAILABLE_CPU
    PROD_POOL_ADDRESS
</pre>

See how those variables are used in */docker-compose.yml and find the detailed corresponding documentation at https://github.com/iExecBlockchainComputing/iexec-worker/ and https://github.com/iExecBlockchainComputing/iexec-core/ (Remember to adapt the branch or tag according to the version you are using). 

Basicly, replace the wallets passwords with the corresponding ones and for the other passwords, generate some strong new ones. The Core server exposes 3 services binded to services "core", "grafana" and "chain-adapter", then replace the PROD_CORE_HOST, PROD_GRAFANA_HOST and the PROD_CHAIN_ADAPTER_HOST by the Core server static IP or a DNS name. Finally, replace the PROD_POOL_ADDRESS with your previously generated workerpool address.

You may also want to customize some other variables for further uses but this is not detailed here. Only pay attention to WORKERPOOL_PRICE and ORDER_PUBLISHER_REQUESTER_RESTRICT which names are explicit enough. You might also want to adapt the WORKER_AVAILABLE_CPU to control the number on paralel tasks your worker can run (defaults to: TOTAL_WORKER_CPU - 1). For your own convenience, adapting the GRAFANA_HOME_NAME might be good to match you Workerpool public description from step [Core (Scheduler) Registration](#Core-Scheduler-Registration). 
  

# Deployment

- Create 2 servers (or deploy both worker and scheduler on the same server but in two different directories by adapting this procedure a little bit **on your own**) 

- The Core server will host the Core services (scheduler). It should have a static IP or a DNS name.

- The Worker server will host the worker services. 


## Core (Scheduler) service deployment

We will copy files and start the core services onto the Core server : 

- Copy the customized .env and core directory in the ```"/opt"``` directory (or somewhere you'd rather install the core services)

- Copy the previously created ```"core_wallet.json"``` into ```"/opt/core/wallet.json"```  

- For security issues, you *could* delete the worker-specific part in the .env file

- Start the core services with ```"docker-compose up -d"``` from the core directory

- You can check 3 services:

- Blockchain Adapter exposes the blockchain configuration :

```"http://$PROD_CHAIN_ADAPTER_HOST:13010/config/chain"```

- Core metrics :

```"http://$PROD_CORE_HOST:7001/metrics"```

- Grafana (core) metrics dashboard :

```"http://$PROD_CORE_HOST:7000/"```

  
Congratulations, you know how to run a scheduler.

Let's add a worker to complete the workerpool. 

  

## Worker service deployment

You may create as many workers as you want by repeating and adapting all the worker-specific procedures (wallet creation, server creation and service deployment) but you'll have to do it **on your own**.

We will copy files and start the worker services onto the Worker server : 

- Copy the customized .env and worker directory in the ```"/opt"``` directory (or somewhere you'd rather install the worker services)

- Copy the previously created ```"worker_wallet.json"``` into ```"/opt/worker/wallet-0.json"```  

- For security issues, you could delete the core-specific part in the .env file

- Start the worker services with ```"docker-compose up -d"``` from the worker directory
  

# Status checking

## Worker should join the workerpool 

- Reload the core pages, you should see 1 alive worker.

```"http://$PROD_CORE_HOST:7001/metrics"```

```"http://$PROD_CORE_HOST:7000/"```

## The Core server should publish workerpool orders

The order-publisher-std service should publish workerpool orders on the marketplace (within some minutes). You can check those orders by running an iExec CLI command inside this container : <pre>docker-compose exec -T "order-publisher-std" sh -c 'iexec orderbook workerpool "$WORKERPOOL" --chain "$CHAIN" --tag "$TAG"'</pre> 

You can check the service logs to see orders being published : <pre>docker-compose logs "order-publisher-std"</pre>
  

## Order manual management

- Have a look at the [CLI Documentation](https://github.com/iExecBlockchainComputing/iexec-sdk/blob/master/CLI.md#SDK-CLI-for-Workerpools)
- Basically, you can restric who can use you workerpool by publishing specific a workerpool order
<pre>iexec workerpool publish --help

  iexec workerpool publish --wallet-file "core_wallet.json" --keystoredir "$PWD" --chain goerli --requester-restrict 0x0123456789000000000000000000000000000000 --category 1 --price 0 --volume 1 0x3c611ad1cAe35D563a5567a04475B0c31503bf4B
</pre>

- You can unpublish all your workerpoolorders using
<pre>
  iexec workerpool unpublish --all 0x3c611ad1cAe35D563a5567a04475B0c31503bf4B --wallet-file "core_wallet.json" --keystoredir "$PWD"
</pre>


# Going further (unsupported yet)

This tutorial doesn't go into further support for more features like the sub-directories under features directory.  

Although not fully supported, those features basicly work by:
1. copying the files to the Worker and/or Core server (see $ROLE/docker-compose-${FEATURE}.yml files)
1. adapting some variables used in thoses new compose files (see $ROLE/.env-$FEATURE files)
1. using docker-compose command with multiple compose files like ```"docker-compose -f docker-compose.yml -f docker-compose-${FEATURE}.yml up -d"``` or fusionning compose files properly (for Advanced users). 

Some feature-specific operations might be necessary. 

Some features can be combined (HTTPS + TEE) but some obviously can not (HTTP AND HTTPS). 

## Reverse-proxy with HTTP

It helps not dealing with unusual ports but instead, offers some DNS names customization. 

Copy files and add the environment variable PROD_GRAFANA_HOST for the Core services. 

From the core service, you should, as a security issue, also remove from core/docker-compose.yml the ports redirections since the reverse-proxy is here for it. 
      - 7001:13000
      - 7000:3000
      - 13010:13010

## Reverse-proxy with HTTPS

Same as [Reverse-proxy with HTTP](#Reverse-proxy-with-HTTP) but the Nginx reverse-proxy will also use Letsencrypt to generate HTTPS certificates for the DNS names so those DNS names must be public and you should provide a valid administrators email address. 

## TEE 

In order to provide the SGX Scone device (/dev/isgx), you should install the Scone SGX drivers on the Worker server : 
<pre>
    curl -fssl https://raw.githubusercontent.com/SconeDocs/SH/master/install_sgx_driver.sh | bash
</pre>

There also are 2 mandatory variables which will make the worker able to download the pre and post compute images : for Scontain username and password, create an account at https://gitlab.scontain.com/users/sign_up. 

You may also need to read the [Scontain documentation](https://sconedocs.github.io/). 

When the worker service starts, pay attention to its logs and check if the SGX mode is correctly detected.