#!/bin/bash

Blue='\033[0;34m'
Red='\033[0;31m'
NoColor='\033[0m'

ServersDir="./servers"
ServerList=()

if [ ! -d "$ServersDir" ]; then
  printf "${Red}- No servers found!${NoColor}\n"
  exit 0
fi

if [ ! -f "$ServersDir"/* ]; then
  printf "${Red}- No servers found!${NoColor}\n"
  exit 0
fi

for Entry in "$ServersDir"/*; do
  while IFS=/ read -ra EntrySplit; do
    ServerList+=("${EntrySplit[-1]}")
  done <<< "$Entry"
done

if [[ "${#ServerList[@]}" == 1 ]]; then
  InputServerName=${ServerList[0]}
else
  printf "${Blue}+ Choose a server to deploy?${NoColor}\n"
  for K in ${!ServerList[@]}; do
    printf "$(($K + 1)) - ${Red}${ServerList[$K]}${NoColor}\n"
  done

  read InputServerIndex
  InputServerName=${ServerList[$(($InputServerIndex - 1))]}
fi

if [ -z "$InputServerName" ]; then
  printf "${Red}- Invalid selection!${NoColor}\n"
  exit 0
fi

while IFS== read -r key value; do
  value=${value::-1} # remove last character
  declare "${key}"=$value
done < "$ServersDir/$InputServerName"

dest_existed() {
  if ssh -i ${SSH_KEY} -p ${PORT} ${USER}@${HOST} "[ -d ${DEST} ]"; then
    echo 'true'
  else
    echo 'false'
  fi
}
create_dest() {
  if [[ $(dest_existed) == 'false' ]]; then
    ssh -i ${SSH_KEY} -p ${PORT} ${USER}@${HOST} "mkdir -p ${DEST}"
  fi
}
git_pull() {
  git pull origin ${GIT_BRANCH}
}
deploy() {
  Cmd="rsync"
  if ! command -v ${Cmd} &> /dev/null; then
    Cmd="rsync.exe"
  fi

  ${Cmd} -avHPe ssh ${SRC} -e "ssh -i ${SSH_KEY} -p ${PORT}" ${USER}@${HOST}:${DEST} --exclude-from ${EXCLUDE_FILE}
}
restart_server() {
  ssh -i ${SSH_KEY} -p ${PORT} ${USER}@${HOST} "[ -s '${USER_HOME}/.nvm/nvm.sh' ] && \. '${USER_HOME}/.nvm/nvm.sh' && pm2 reload all"
}

printf "\n"
printf "${Blue}+ Prepare to deploy to ${Red}${InputServerName}${Blue}...${NoColor}\n"
create_dest
printf "\n${Blue}+ Pulling code from ${Red}${GIT_BRANCH}${Blue}...${NoColor}\n"
git_pull
printf "\n${Blue}+ Start deploying code to ${Red}${InputServerName}${Blue}...${NoColor}\n"
deploy
printf "\n${Blue}+ Restarting server ${Red}${InputServerName}${Blue}...${NoColor}\n"
restart_server
printf "\n${Blue}= Completed deploying to ${Red}${InputServerName}${Blue}!${NoColor}\n"

printf "${Blue}= Exiting...${NoColor}\n\n"
exit 0

$SHELL