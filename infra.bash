#!/bin/bash -e

STACK='v8'
# Possibilité de changer entre $STACK et staging$STACK en cas de changement non encore propagés en prod sur la branche $STACK
VERSION="staging$STACK"

echo "= Init and reset"
cd "$(dirname "$0")"

: ${STACK_DEPLOY_SRC:=../stack-deploy}

cd "$STACK_DEPLOY_SRC"
git checkout $VERSION
git pull
cd -

rm -rf core worker 

echo "= Copie Stack-deploy"
# Lire stack-deploy/Jenkinsfile pour refaire la copie des fichier pour core_prod et worker_prod : 
## core_prod
### copies
cp -a "$STACK_DEPLOY_SRC/common/common/." core
cp -a "$STACK_DEPLOY_SRC/common/core_prod/." core
cp -a "$STACK_DEPLOY_SRC/config-$STACK-bellecour/core_prod/." core
# Supporter les scripts de order-deploy manuel ou pas ? non pour l'instant (cf README)
rm -rf core/order-deploy

### générer le .env final 
"$STACK_DEPLOY_SRC/script.env" $STACK-bellecour core_prod "$PWD/core/.env"

## worker_prod
### copies
cp -a "$STACK_DEPLOY_SRC/common/common/." worker
cp -a "$STACK_DEPLOY_SRC/common/worker_prod/." worker
cp -a "$STACK_DEPLOY_SRC/config-$STACK-bellecour/worker_prod/." worker

### générer le .env final 
"$STACK_DEPLOY_SRC/script.env" $STACK-bellecour worker_prod "$PWD/worker/.env"
./worker/scripts/individualize.sh 0

echo "= Confidentialité et anonymisation"
rm vars_to_customize.txt
# Retirer les infos confidentielles de iExec : 
function rm_value {
    # efface la valeur des variables .*$1.* dans les .env de core et worker
    # puis ajoute ces variables à vars_to_customize.txt
    local VAR="${1:?"Il me faut la variable pour laquelle supprimer la valeur"}"
    local VALUE="$(grep -h "$VAR" {core,worker}/.env | sort -u | tail -n-1 | cut -d'=' -f2)"
    case "$VALUE" in 
        0x*) DEFAULT_REPLACE=0x012345678900000000000000000-your-hexa-address ;; 
        *iex.ec) DEFAULT_REPLACE=${VALUE%iex.ec}yourdomain ;; 
        *) DEFAULT_REPLACE=changeme ;; 
    esac
    sed -i -e 's/\('"$VAR"'.*\)=.*$/\1='"${2:-$DEFAULT_REPLACE}"'/' {core,worker}/.env
    grep -h "$VAR" {core,worker}/.env | sort -u >> vars_to_customize.txt 
    [ ${PIPESTATUS[0]} = 0 ] || echo "pas trouvé $VAR"
}
rm -rf core/*wallet* worker/*wallet* {core,worker}/{jenkins.groovy,menage.bash,scripts,volumes.env}
rm_value PASSWORD 

# Anonymiser core et worker
rm_value PROD_CORE_HOST
rm_value PROD_CHAIN_ADAPTER_HOST
rm_value PROD_GRAFANA_HOST
rm_value PROD_PLATFORM_REGISTRY_HOST
rm_value PROD_POOL_ADDRESS 0xyour-workerpool-address
rm_value WORKER_AVAILABLE_CPU 1
rm_value WORKERPOOL_DESCRIPTION "My workerpool description"
rm_value LETSENCRYPT_ADMIN_EMAIL

cat vars_to_customize.txt

# modifier les docker-compose.yml
./infra-copy-compose-files.py

echo "= Remaniement des .env"
# Trier les variables communes ou core-specific ou worker-specific
cut -d'=' -f1 core/.env     | grep -v '#' | sort -u > core_vars
cut -d'=' -f1 worker/.env   | grep -v '#' | sort -u > worker_vars

function get_vars {
    THIS="${1:?core ou worker}"
    touch common.env ${THIS}.env

    for VAR in $(cat "${THIS}_vars") ; do 
        # si la variable est utilisée dans le docker-compose.yml on la traite (sinon, on n'en fait rien)
        if grep -q "\${\?$VAR" "${THIS}/docker-compose.yml"; then 
            # si pas déjà intégrée au common on la traite (sinon, on n'en fait rien)
            if ! grep -q "^$VAR=" common.env; then 
                VAR_VALUE="$(grep "^$VAR=" "${THIS}/.env" | tail -n-1)" # retourne la ligne VAR=VALUE entière 
                # si variable commune 
                if grep -q "\${\?$VAR" core/docker-compose.yml && grep -q "\${\?$VAR" worker/docker-compose.yml ; then
                # Comparer les valeurs ? mais qu'en ferait-on ?
                    echo "$VAR_VALUE" >> common.env
                else
                # si variable spécifique ${THIS}
                    echo "$VAR_VALUE" >> "${THIS}.env"
                fi
            fi
        fi 
    done
}
rm core.env worker.env common.env 2>/dev/null || true
get_vars core 
get_vars worker  # Worker en premier pour récupérer le WORKER_TAG avec la bonne version...

cat >.env <<EOF
# common core and worker
$(cat common.env)

# core specific
$(cat core.env)

# worker specific
$(cat worker.env)

EOF

rm {core,worker}/.env{,.bash} core_vars worker_vars core.env worker.env common.env

ln -s ../.env core/
ln -s ../.env worker/

ls -l .env {core,worker}/.env 

# Adaptation manuelles du .env : 
# WALLET=wallet-0.json descendu dans la section worker
# TODO: renommer les variables en WORKER_WALLET et WORKER_WALLET_PASSWORD dans stack-deploy

echo "= Détails en dur"
sed -i -e 's/Wallet is mandatory and should come with individualize.sh/Wallet is mandatory/' worker/docker-compose.yml
sed -i -e '/SCONTAIN_REGISTRY_PASSWORD=/d' vars_to_customize.txt
sed -i -e 's/bellecour2.iex.ec/bellecour.iex.ec/g' .env

echo fini OK