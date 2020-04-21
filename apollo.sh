#! /bin/bash

include () {
  if [ ! -f mainnet.env ]; then
    echo "No configuration found, proceeding to setup helper..."
    cp mainnet.example.env mainnet.env
    cp example.pwd .pwd
    echo Welcome to Rupaya Apollo initial configuration helper!
    read -p "Please enter the name you want to use for your node:"
    NODENAME=$REPLY
    sed -i "/NAME/s/=.*/=${NODENAME}/" mainnet.env # Append coinbase
    read -s -p "Please input a strong password to secure your account:"
    echo $REPLY > .pwd # Save to .pwd file
  fi
  echo "Configuration file found"
  source mainnet.env
}

include

initGenesis() {
  if [ ! -d ${DATADIR}/${NAME}/rupx ]; then
    echo "No genesis found, creating genesis block..."
    rupaya --datadir ${DATADIR}/${NAME} init ./config/chain/mainnet/main.json
    echo
    echo "${GREEN} Rupaya genesis file initialized ${NC}"
    echo
  fi
}

checkCoinbase() {
  accounts=$(rupaya --datadir ${DATADIR}/${NAME} account list | awk -F'[{}]' '{print $2}')
  if [ -z "$accounts" ]
  then
    echo
    echo "No accounts found!"
    read -p "Would you like to (I)mport an existing account or (C)reate a new one (I/C)? "
    if [[ $REPLY =~ ^[Ii]$ ]]
    then
      import
    else
      createNewAccount
    fi
  else
    echo "Account $accounts has been found"
    accounts=$(rupaya --datadir ${DATADIR}/${NAME} account list | awk -F'[{}]' '{print $2}')
    get_coinbase=$(echo $accounts | awk '{print $1;}')
    sed -i "/COINBASE/s/=.*/=${get_coinbase}/" mainnet.env # Append coinbase
  fi
}

import() {
  read -s -p "Enter the private key of the account you want to import:"
  if [ ${#REPLY} -lt 64 ]
  then
    echo "Your private key seems too short. Please start again."
    exit
  else
    echo $REPLY > .tmp
    rupaya --datadir ${DATADIR}/${NAME} --password .pwd account import .tmp
    rm .tmp
    echo
    echo "Private key successfully imported!"
    echo
    accounts=$(rupaya --datadir ${DATADIR}/${NAME} account list | awk -F'[{}]' '{print $2}')
    get_coinbase=$(echo $accounts | awk '{print $1;}')
    sed -i "/COINBASE/s/=.*/=${get_coinbase}/" mainnet.env # Append coinbase
    echo "All accounts found in keystore: "
    echo
    echo $accounts
    echo
    echo "To remove all excess accounts, please remove them from ${DATADIR}${NAME}/keystore"
  fi
}

createNewAccount() {
  rupaya --datadir ${DATADIR}/${NAME} --password .pwd account new
  echo
  get_all_coinbases=$(rupaya --datadir ${DATADIR}/${NAME} account list | awk -F'[{}]' '{print $2}' )
  get_coinbase=$(echo $get_all_coinbases | awk '{print $1;}')
  echo
  echo Address created: $get_coinbase
  sed -i "/COINBASE/s/=.*/=${get_coinbase}/" mainnet.env # Append coinbase
}

stop() {
  echo Stopping rupaya node ${PID}
  kill -SIGINT ${PID}
  echo Rupaya node ${PID} stopped.
}

force () {
  echo Stopping all rupaya nodes...
  killall -HUP rupaya
  echo All rupaya nodes stopped.
}

run() {
  # Use this for now.
  get_all_coinbases=$(rupaya --datadir ${DATADIR}/${NAME} account list | awk -F'[{}]' '{print $2}' )
  get_coinbase=$(echo $get_all_coinbases | awk '{print $1;}')

  rupaya \
    --bootnodes "enode://504e40653c81b62634aae3c75cb0804f933fa05006dc9f63e50dda178a9b6fcd7de2360fcf77ccca93fe7e016d9e636b440c1db6d00053c2517130c240bed107@167.172.48.132:30301" --syncmode "full" --gcmode "archive" \
    --datadir ${DATADIR}/${NAME} --networkid 77 --port $PORT \
    --announce-txs \
    --rpc --rpccorsdomain "*" --rpcaddr 0.0.0.0 --rpcport 7050 --rpcvhosts "*" \
    --ws --wsaddr 0.0.0.0 --wsport 8050 --wsorigins "*" \
    --unlock "$get_coinbase" --password ./.pwd \
    --ethstats "$NAME:universal-gas-lighter-refill@stats.rupx.io" \
    --mine --store-reward --verbosity 1 >${DATADIR}/${NAME}/log.txt 2>&1 &
  process_id=$!

  sed -i "/PID/s/=.*/=${process_id}/" mainnet.env # Write process ID to config for logs
  echo Rupaya started with process id $process_id
}

update() {
  git pull
}

log() {
  echo Showing log file. Ctrl+C to exit
  tail -f -n 2 ${DATADIR}/${NAME}/log.txt
}

clean() {
  read -p "This will completely remove any existing data and accounts! Are you sure? (Y/N) "
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    force
    mkdir -p ./Archive
    find ./networks/ -name "UTC*" -exec cp {} "./Archive/" \;
    rm -rf ${DATADIR}
  else
    echo "canceled by user."
    exit
  fi
}

start() {
  sed -i "/COINBASE/s/=.*/=/" mainnet.env
  initGenesis
  checkCoinbase
  wait
  run
}


if [ $# -eq 0 ]
then
  echo "No arguments supplied"
fi


case "$1" in
  start ) start ;;
  import ) import ;;
  stop ) stop ;;
  force-close ) force ;;
  update ) update ;;
  clean ) clean ;;
  log ) log ;;
esac
