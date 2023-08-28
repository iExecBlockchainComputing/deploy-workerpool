#!/usr/bin/python3

import yaml
from yaml.loader import SafeLoader

import re

STACK_DEPLOY_SRC = "../stack-deploy"

# CORE
print( "= Compose Core")
with open("%s/common/core_prod/docker-compose.yml" % STACK_DEPLOY_SRC) as file:
  core_compose = yaml.load(file, Loader=SafeLoader)

## tee order-publishers
tee_core_compose = {'version': core_compose['version']}
tee_core_compose['services'] = {}

for service_name in core_compose['services'].copy():
    #print(service_name)
    service = core_compose['services'][service_name]
    #print(service)
    if service_name.startswith('order-publisher'):
      if 'environment' in service:
        #print(service['environment'])
        for var in service['environment']:
          if var.startswith('TAG='):
            if not re.match("TAG=0x0+$", var):
              #print(var)
              print("%s is deleted" % service_name)
              core_compose['services'].pop(service_name)
              tee_core_compose['services'][service_name] = service

# ## Corriger les env pour joindre le CHAIN_ADAPTER (plus utile depuis qu'on supporte le HTTPS par défaut)
# for index,var in enumerate(core_compose['services']['core']['environment']):
#   if re.match("^IEXEC_CORE_CHAIN_ADAPTER_PORT=", var):
#     for index2,var2 in enumerate(core_compose['services']['blockchain-adapter']['environment']):
#       if re.match("^VIRTUAL_PORT=", var2):
#         newvar = "IEXEC_CORE_CHAIN_ADAPTER_PORT=%s" % var2.split('=')[1]
#     core_compose['services']['core']['environment'][index] = newvar
#     print("changed %s to %s" % (var,newvar))
#   if re.match("^IEXEC_CORE_CHAIN_ADAPTER_PROTOCOL=", var):
#     newvar = "IEXEC_CORE_CHAIN_ADAPTER_PROTOCOL=%s" % 'http'
#     core_compose['services']['core']['environment'][index] = newvar
#     print("changed %s to %s" % (var,newvar))

to_remove = []
for index,var in enumerate(core_compose['services']['core']['environment']):
  # Ne pas bloquer la version du worker sur le core
  if re.match("^IEXEC_CORE_REQUIRED_WORKER_VERSION=", var):
    to_remove.append(var)

for var in to_remove:
  core_compose['services']['core']['environment'].remove(var)
  print("no more %s" % var)

## save files
with open('./core/docker-compose.yml', 'w') as file:
  yaml.dump(core_compose, file, width=1000)
  
with open('./features/tee/core/docker-compose-tee.yml', 'w') as file:
  yaml.dump(tee_core_compose, file, width=1000)


# WORKER
print( "= Compose Worker")
with open("%s/common/worker_prod/docker-compose.yml" % STACK_DEPLOY_SRC) as file:
  worker_compose = yaml.load(file, Loader=SafeLoader)

to_remove = []
for index,var in enumerate(worker_compose['services']['worker_prod']['environment']):
  # ## Fix env to let the worker connect to the core (plus utile depuis qu'on supporte le HTTPS par défaut)
  # if re.match("^IEXEC_CORE_PORT=", var):
  #   newvar = "IEXEC_CORE_PORT=%s" % core_compose['services']['core']['ports'][0].split(':')[0]
  #   worker_compose['services']['worker']['environment'][index] = newvar
  #   print("changed %s to %s" % (var,newvar))
  # if re.match("^IEXEC_CORE_PROTOCOL=", var):
  #   newvar = "IEXEC_CORE_PROTOCOL=%s" % 'http'
  #   worker_compose['services']['worker']['environment'][index] = newvar
  #   print("changed %s to %s" % (var,newvar))
  ## Deactivate dev logger
  if re.match("^IEXEC_DEVELOPER_LOGGER_ENABLED=", var):
    newvar = "IEXEC_DEVELOPER_LOGGER_ENABLED=%s" % 'False'
    worker_compose['services']['worker_prod']['environment'][index] = newvar
    print("changed %s to %s" % (var,newvar))
  ## No SGX
  if re.match("^IEXEC_WORKER_SGX_DRIVER_MODE=", var):
    newvar = "IEXEC_WORKER_SGX_DRIVER_MODE=%s" % 'NONE'
    worker_compose['services']['worker_prod']['environment'][index] = newvar
    print("changed %s to %s" % (var,newvar))
  ## Remove variables related to SGX-Scontain 
  if re.match("^IEXEC_WORKER_SCONTAIN_REGISTRY_USERNAME=", var):
    to_remove.append(var)
  if re.match("^IEXEC_WORKER_SCONTAIN_REGISTRY_PASSWORD=", var):
    to_remove.append(var)
    
  #print("debug [%s] = %s" % (index, var))

for var in to_remove:
  worker_compose['services']['worker_prod']['environment'].remove(var)
  print("no more %s" % var)


## save files
with open('./worker/docker-compose.yml', 'w') as file:
  yaml.dump(worker_compose, file, width=1000)