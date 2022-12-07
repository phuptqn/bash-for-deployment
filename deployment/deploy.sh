#!/bin/bash
set -e

InputEnv=$1

Blue='\033[0;34m'
Red='\033[0;31m'
NoColor='\033[0m'

ServersDir="./servers"
ServerList=()
IsCiCd=true
CiCdStateText="CI/CD"

#master here

if [ ! -d "$ServersDir" ]; then
  printf "${Red}- No servers found!${NoColor}\n"
  exit 0
fi

serverFiles=("$ServersDir"/*)
if [ ! -f "$serverFiles" ]; then
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

  if [ -z "$InputEnv" ]; then
    printf "${Blue}+ Choose a server to deploy?${NoColor}\n"
    for K in ${!ServerList[@]}; do
      printf "$(($K + 1)) - ${Red}${ServerList[$K]}${NoColor}\n"
    done

    read InputServerIndex
    InputServerName=${ServerList[$(($InputServerIndex - 1))]}
  else
    InputServerName="${InputEnv}.env"
  fi

fi

if [ -z "$InputServerName" ]; then
  printf "${Red}- Invalid selection!${NoColor}\n"
  exit 0
fi

while IFS=$'\r\n' read -r Line; do
  IFS='=' read -ra LineParts <<< "$Line"
  declare "${LineParts[0]}"="${LineParts[1]}"
done < "$ServersDir/$InputServerName"

init_CI_CD() {
  if [ -z "$CI" ]; then
    # NOT in ci/cd
    IsCiCd=false
    CiCdStateText="MANUAL"

    # use local SSH
    SSH_KEY=" -i ${SSH_KEY}"
  else
    # use ssh key in CI/CD
    SSH_KEY=""
  fi
}

dest_existed() {
  if ssh${SSH_KEY} -p ${PORT} ${USER}@${HOST} "[ -d ${DEST} ]"; then
    echo 'true'
  else
    echo 'false'
  fi
}

create_dest() {
  if [[ $(dest_existed) == 'false' ]]; then
    ssh${SSH_KEY} -p ${PORT} ${USER}@${HOST} "mkdir -p ${DEST}"
  fi
}

git_pull() {
  git stash save "Switched to ${GIT_BRANCH} to deploy at $(date)"
  git checkout ${GIT_BRANCH}
  git pull origin ${GIT_BRANCH}
}

update_cache_version() {
  CurrentDate=`date +"%Y%m%d-%H%M%S"`
  CurrentTz=`date +"%z"`
  CurrentTz="${CurrentTz:1}"
  CurrentTz="${CurrentTz::-2}"

  echo "${CurrentDate}${CurrentTz}" > ../cache-version.txt
}

deploy() {
  Cmd="rsync"
  if ! command -v ${Cmd} &> /dev/null; then
    Cmd="./rsync.exe"
  fi
  
  update_cache_version

  ${Cmd} -avHPe ssh ${SRC} -e "ssh${SSH_KEY} -p ${PORT}" ${USER}@${HOST}:${DEST} --exclude-from ${EXCLUDE_FILE}
}

restart_server_staging() {
  ssh${SSH_KEY} -p ${PORT} ${USER}@${HOST} "[ -s '${USER_HOME}/.nvm/nvm.sh' ] && \. '${USER_HOME}/.nvm/nvm.sh' && pm2 reload api-abc"
}

######################################################################################################
##################################### Execute the functions ##########################################
######################################################################################################

init_CI_CD

printf "\n"

printf "${Blue}= Deployment state: ${Red}${CiCdStateText}${Blue}${NoColor}\n\n"

printf "${Blue}+ Prepare to deploy to ${Red}${InputServerName}${Blue}...${NoColor}\n"
create_dest

if [[ "$IsCiCd" = false ]]; then
  printf "\n${Blue}+ Pulling code from ${Red}${GIT_BRANCH}${Blue}...${NoColor}\n"
  # only pull the code on local
  git_pull
fi

# printf "\n${Blue}+ Building source code for ${Red}${InputServerName}${Blue}...${NoColor}\n"
# npm run build

printf "\n${Blue}+ Start deploying code to ${Red}${InputServerName}${Blue}...${NoColor}\n"
deploy

# printf "\n${Blue}+ Restarting server ${Red}${InputServerName}${Blue}...${NoColor}\n"
# ${RESTART_SERVER_FUNC}

printf "\n${Blue}= Completed deploying to ${Red}${InputServerName}${Blue}!${NoColor}\n"

printf "${Blue}= Exiting...${NoColor}\n\n"
exit 0

$SHELL
