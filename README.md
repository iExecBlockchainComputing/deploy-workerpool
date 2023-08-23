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

This repository contains the necessary files to set up a scheduler (also known as the core service) and its workers.

  

The folllowing considerations must be taken into account:

  

- Only workepools for standard tasks (non TEE) are in the scope of this README.

  

- Services must be connected to the [https://bellecour.iex.ec](https://blockscout-bellecour.iex.ec/) iExec sidechain.

  

# Requirements

Workerpool servers:

- minimal: 2 servers with 2 CPU, and 4 GB of RAM each

- minimal recommended: 2 servers with 4 CPU, and 16 GB of RAM each

- OS recommended: Ubuntu 20.04, it should not be an issue to use another one but you might need to adapt some configuration **on your own**

- Packages: docker and its compose plugin (compose V2 as a plugin for the ```"docker compose"``` command) with the standard installation steps provided on https://docs.docker.com/compose

- Network : Make sure the core and worker can request the web with HTTP/S (80,443) and that the worker can contact the core (see the port on the testing core URLs or wide open communications between them). Also, make sure the Core server can request LetsEncrypt certificates based on the ACME HTTP-01 challenge (see the letsencrypt service companion) which basicly means to provide this server a public IP address. 

 
Software for deployment an registration (basic installation **on your own**):

- [iExec SDK CLI](https://github.com/iExecBlockchainComputing/iexec-sdk/blob/master/CLI.md), check your version with iexec -V and make sure that the major version is 8. 

- *jq* for debug convenience, installation is up to you, maybe use *cat* which should be embedded almost everywhere. 

NB: The worker server will most likely run many different docker images which will most likely consume a lot of disk space. You should manage this **on your own** with a scheduled task like cron and the command:

```console
$ docker image prune --all --force
```

It is better to prune docker images when no task is running and to restart the worker service afterwards. If you do not want to restart the worker service, make sure not to delete iexec-las, tee-worker-pre-compute and tee-worker-post-compute images in case you run a TEE worker.



# Configuration

## Core (Scheduler) Registration

- Open an empty directory

- Initialize your iExec workspace in this directory:

```console
$ iexec init --skip-wallet 
```

  

- Edit the "chain.json" file and make sure the "default" is set to "bellecour"
```console
$ cat chain.json
{
  "default": "bellecour",
  "chains": {
    "mainnet": {},
    "bellecour": {}
  }
}
```

- Create a wallet for you scheduler (keep the core's wallet password safe) and rename it accordingly:

```console
$ iexec wallet create --keystoredir ./
? Please choose a password for wallet encryption [hidden]
? Please confirm your password [hidden]
✔ Your wallet address is 0xaf1ceea065f5b9c8961ead7bbaf4e9262167c456
Wallet saved in "UTC--2022-11-14T19-26-19.749000000Z--af1ceea065f5b9c8961ead7bbaf4e9262167c456":
...
⚠ You must backup your wallet file in a safe place!

# rename the wallet
$ mv   UTC--2022-11-14T19-26-19.749000000Z--af1ceea065f5b9c8961ead7bbaf4e9262167c456    core_wallet.json
```

- Optionally, instead of creating a new wallet, you can use an existing one or import your private key with the command:

```console
$ iexec wallet import <your_private_key>
```

    
- Create a wallet for you worker (keep the worker's wallet password safe):

```console
$ iexec wallet create --keystoredir ./
...
# rename the wallet
$ mv   UTC--2022-11-14T19-27-56.277000000Z--d2e57b7121fc43169aab2e3dc37e4338ca58a303    worker_wallet.json
```


⚠ Make sure to securely save and protect these wallet files and the associated passwords. Those wallets can never be retrieved by either iExec nor anybody. It is fully under your responsability to save and protect thoses files and associated passwords even on the servers. 
  

- Localy initialize you workerpool registration:

```console
$ iexec workerpool init --wallet-file "core_wallet.json" --keystoredir ./
```

  

- Edit the "iexec.json" file and change the "workerpool.description" field from the 'my-workerpool' default value. This field will appear publicly on the blockchain and the marketplace.

- Make sure the "workerpool.owner" field of iexec.json file matches the "address" field of the "core_wallet.json" file.

```console
$ jq .workerpool iexec.json 
"workerpool": {
    "owner": "0x6DdF0Bf919f108376136a64219B395117229BaF6",
    "description": "my-workerpool"
}

$ jq .address core_wallet.json
"6DdF0Bf919f108376136a64219B395117229BaF6"
```

  

- Register your workerpool on the blockchain to get its workerpool address:

```console
$ iexec workerpool deploy --wallet-file "core_wallet.json" --keystoredir ./
    
    ℹ Using chain bellecour [chainId: 134]
    
    ? Using wallet core_wallet.json
    
    Please enter your password to unlock your wallet [hidden]
    
    ✔ Deployed new workerpool at address 0xabc...
    
```


Save your workerpool (deployment) address for later use (you might also find it in the deployed.json file)
  

You may now consult the workerpool metadata by typing your workerpool address into the search area on the [explorer](https://explorer.iex.ec/bellecour/).

  

Keep in mind that the workerpool address corresponds to your workerpool registration address and not the wallet owner address. 

 
If you want to deploy a free workerpool (workerpool orders with price = 0 RLC), you can jump to the next section ([Customization](#Customization)). You don't need to stake some RLC on the core's and worker's wallets (the end of this section). 
  

- For a non-free workerpool, first, put some RLC to the core's and worker's wallets using you favorite tool (metamask/iexec cli/...). Obviously, you need some RLC on another wallet for this.  

Example using the iexec CLI:

```console
$ iexec wallet send-RLC "10" --to ${DEST_WALLET_ADDRESS} --wallet-file ${YOUR_OTHER_WALLET_WITH_RLC_FILE} --keystoredir ${DIRECTORY_OF_YOUR_OTHER_WALLET_WITH_RLC}
```

  

- Then stake this amount of RLC to the iExec account of the wallets (core and worker)

```console
$ iexec account deposit 1 RLC --wallet-file core_wallet.json   --keystoredir "$PWD"
$ iexec account deposit 1 RLC --wallet-file worker_wallet.json --keystoredir "$PWD"
```

  

## Customization

- Copy / clone this repo locally

- Before spreading files, your need to customize a minimal set of variables in the .env file: 

<pre>
    PROD_CHAIN_ADAPTER_PASSWORD
    PROD_GRAFANA_ADMIN_PASSWORD
    PROD_MONGO_PASSWORD
    PROD_CORE_WALLET_PASSWORD
    PROD_WALLET_PASSWORD
    PROD_CORE_HOST
    PROD_CHAIN_ADAPTER_HOST
    PROD_GRAFANA_HOST
    PROD_PLATFORM_REGISTRY_HOST
    WORKER_AVAILABLE_CPU
    PROD_POOL_ADDRESS
    WORKERPOOL_DESCRIPTION
    LETSENCRYPT_ADMIN_EMAIL
</pre>

See how those variables are used in */docker-compose.yml and find the detailed corresponding documentation at https://github.com/iExecBlockchainComputing/iexec-worker/ and https://github.com/iExecBlockchainComputing/iexec-core/ (Remember to adapt the branch or tag according to the version you are using). 

Basicly, replace the wallets passwords with the corresponding ones and for the other passwords, generate some strong new ones. The Core server exposes 4 services binded to services "core", "platform-registry", "grafana" and "chain-adapter", then replace the PROD_CORE_HOST, PROD_GRAFANA_HOST, PROD_PLATFORM_REGISTRY_HOST and the PROD_CHAIN_ADAPTER_HOST by some DNS names resolved to the Core server public IP. You should also provide a valid administrators email address with ```LETSENCRYPT_ADMIN_EMAIL```. Finally, replace the PROD_POOL_ADDRESS with your previously generated workerpool address.

You may also want to customize some other variables for further uses but this is not detailed here. Only pay attention to WORKERPOOL_PRICE and ORDER_PUBLISHER_REQUESTER_RESTRICT which names are explicit enough. You might also want to adapt the WORKER_AVAILABLE_CPU to control the number on parallel tasks your worker can run (empty value defaults to: TOTAL_WORKER_CPU - 1). It might be good for your own convenience to adapt the WORKERPOOL_DESCRIPTION to match you Workerpool public description from step [Core (Scheduler) Registration](#Core-Scheduler-Registration). 

You must also pay attention to the CHAIN_LAST_BLOCK in the .env file, this helps your core service not to read the blockchain from a too old point in time and save him efforts. When you deploy your workerpool, put a very recent block number, less than 20 blocks old. You can get the last mined block at https://blockscout-bellecour.iex.ec/blocks . It might happen that the core service is lost reading a too large amount of blocks from the blockchain and then, does not see new deals. In such a case, you need to turn off the core services, set a very fresh value in .env, reset some mongo documents : Configuration and ReplayConfiguration and then turn the core services on again. If you are not interested in the mongo historical data (it's like resetting completely your workerpool), you can just wipe the mongo volume with *docker compose down -v*, set a fresh new CHAIN_LAST_BLOCK and *docker compose up -d*. 


# Deployment

- Create 2 servers (or deploy both worker and scheduler on the same server but in two different directories by adapting this procedure a little bit and **on your own**). 

- The Core server will host the Core services (scheduler). It should have a static IP for commminucations from the worker and 4 DNS names for HTTP virtual host routing. 

- The Worker server will host the worker services. It should not be exposed on the internet for obvious security reasons. 


## Core (Scheduler) service deployment

You will copy files and start the core services onto the Core server as such: 

- Copy the customized .env and core directory in the ```"/opt"``` directory (or somewhere you'd rather install the core services)

- Copy the previously created ```"core_wallet.json"``` into ```"/opt/core/wallet.json"```  

- For security issues, you *can* delete the worker-specific part in the .env file

- Start the core services with ```"docker compose up -d"``` from the core directory

- You can check 4 services:

    - Blockchain Adapter exposes the blockchain configuration (and its health):

    ```"https://$PROD_CHAIN_ADAPTER_HOST/config/chain"```
    ```"https://$PROD_CHAIN_ADAPTER_HOST/actuator/health"```

    - Core exposes metrics (and its health):

    ```"https://$PROD_CORE_HOST/metrics"```
    ```"https://$PROD_CORE_HOST/actuator/health"```

    - Grafana exposes a dashboard:

    ```"https://$PROD_GRAFANA_HOST/"```

    - The platform registry exposes some service URLs (and its health):

    ```"https://$PROD_PLATFORM_REGISTRY_HOST/chain/134"```
    ```"https://$PROD_PLATFORM_REGISTRY_HOST/actuator/health"```

  
Congratulations, you are now running your own scheduler.

Let's add a worker to complete the workerpool. 

  

## Worker service deployment

You may create as many workers as you want by repeating and adapting all the worker-specific steps (wallet creation, server creation and service deployment) but you'll have to do it **on your own**.

You will copy files and start the worker services onto the Worker server as such: 

- Copy the customized .env and worker directory in the ```"/opt"``` directory (or somewhere you'd rather install the worker services)

- Copy the previously created ```"worker_wallet.json"``` into ```"/opt/worker/wallet-0.json"```  

- For security issues, you could delete the core-specific part in the .env file

- Start the worker services with ```"docker compose up -d"``` from the worker directory
  

# Status checking

## Worker should join the workerpool 

- Reload the core metrics and dashboard, you should see 1 alive worker.

```"https://$PROD_CORE_HOST/metrics"```

```"https://$PROD_GRAFANA_HOST/"```

## The Core server should publish workerpool orders

The order-publisher-std service should publish workerpool orders on the marketplace (within some minutes). You can check those orders by running an iExec CLI command inside this container: <pre>docker compose exec -T "order-publisher-std" sh -c 'iexec orderbook workerpool "$WORKERPOOL" --chain "$CHAIN" --tag "$TAG"'</pre> 

You can check the service logs to see orders being published: <pre>docker compose logs "order-publisher-std"</pre>
  

## Order manual management

- Have a look at the [CLI Documentation](https://github.com/iExecBlockchainComputing/iexec-sdk/blob/master/CLI.md#SDK-CLI-for-Workerpools)
- Basically, you can restric who can use you workerpool by publishing specific a workerpool order
```console
$ iexec workerpool publish --wallet-file "core_wallet.json" --keystoredir "$PWD" --chain goerli --requester-restrict 0x0123456789000000000000000000000000000000 --category 1 --price 0 --volume 1 0x3c611ad1cAe35D563a5567a04475B0c31503bf4B
```

- You can unpublish all your workerpoolorders using
```console
$ iexec workerpool unpublish --all 0x3c611ad1cAe35D563a5567a04475B0c31503bf4B --wallet-file "core_wallet.json" --keystoredir "$PWD"
```


# Going further (unsupported yet)

This tutorial doesn't go into further support for more features like the sub-directories under *features* directory.  

Although not fully supported, those features basicly work by:
1. copying the files to the Worker and/or Core server (see ```$ROLE/docker-compose-${FEATURE}.yml``` files)
1. adapting some variables used in thoses new compose files (see ```$ROLE/.env-$FEATURE``` files)
1. using docker compose command with multiple compose files like ```"docker compose -f docker-compose.yml -f docker-compose-${FEATURE}.yml <compose command and args>"``` or fusionning compose files properly (for advanced users). 

Some feature-specific operations might be necessary. 

## TEE

TEE deals come in two different flavour, Scone and Gramine. As you can see in the core/docker-compose-tee.yml file, it will add 2 order-publishers, one for each flavour as you can run Gramine and Scone Tee tasks on the same servers. If you are not interested in one of them, you can just delete the corresponding service. 

On the Worker server, you need to provide the SGX devices (/dev/sgx_enclave and /dev/sgx_provision) and the worker will use them automatically. The native SGX drivers are installed by default on Linux Kernel >= 5.9, juste check the devices. 

You should also install **some** software from this guide : https://github.com/openenclave/openenclave/blob/master/docs/GettingStartedDocs/install_host_verify_Ubuntu_20.04.md :

Some packages might be needed, if not already installed : 

```console
$ sudo apt -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
```

Then, add the APT key : 

```console
$ wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | sudo apt-key add -
```

Then, install the open-enclave-hostverify package and its dependencies : 

```console
$ sudo apt -y install clang-10 libssl-dev gdb libprotobuf17 libsgx-dcap-ql libsgx-dcap-ql-dev az-dcap-client open-enclave-hostverify
```

Watch for the guide details as it might change over time.

There also are 2 mandatory variables which will make the worker able to download the iExec pre and post compute images: for Scontain username and password, create an account at https://gitlab.scontain.com/users/sign_up. 

You may also need to read the [Scontain documentation](https://sconedocs.github.io/). 

When the worker service starts, pay attention to its logs and check if the SGX mode is correctly detected.
