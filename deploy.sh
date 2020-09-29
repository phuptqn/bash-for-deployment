#!/bin/bash

Blue='\033[0;34m'
Red='\033[0;31m'
NoColor='\033[0m'

ServerList=()
AttributeList=(host user userHome branch src dest excludeFile sshKey)

ServerList+=(devel)
devel_host="remote_ip"
devel_user="remote_user"
devel_userHome="remote_user_home_dir"
devel_branch="git_branch_name"
devel_src="local_source_code_dir"
devel_dest="remote_source_code_dir"
devel_excludeFile=".rsync-ignore"
devel_sshKey="ssh_priv_key_path"

printf "${Blue}+ Choose a server to deploy?${NoColor}\n"
for K in ${!ServerList[@]}; do
  printf "$(($K + 1)) - ${Red}${ServerList[$K]}${NoColor}\n"
done

read InputServerIndex

InputServerName=${ServerList[$(($InputServerIndex - 1))]}
Host="${InputServerName}_host"
Host=${!Host}

if [ -z "$Host" ]; then
  printf "${Red}- Invalid selection!${NoColor}\n"
  exit 0
fi

declare -A Server
for K in ${!AttributeList[@]}; do
  Key=${AttributeList[$K]}
  Field="${InputServerName}_${Key}"
  Server[$Key]=${!Field}
done

dest_existed() {
  if ssh -i ${Server[sshKey]} ${Server[user]}@${Server[host]} "[ -d ${Server[dest]} ]"; then
    echo 'true'
  else
    echo 'false'
  fi
}
create_dest() {
  if [[ $(dest_existed) == 'false' ]]; then
    ssh -i ${Server[sshKey]} ${Server[user]}@${Server[host]} "mkdir -p ${Server[dest]}"
  fi
}
git_pull() {
  git pull origin ${Server[branch]}
}
deploy() {
  Cmd="rsync"
  if ! command -v ${Cmd} &> /dev/null; then
    Cmd="rsync.exe"
  fi

  ${Cmd} -avHPe ssh ${Server[src]} -e "ssh -i ${Server[sshKey]}" ${Server[user]}@${Server[host]}:${Server[dest]} --exclude-from ${Server[excludeFile]}
}
restart_server() {
  ssh -i ${Server[sshKey]} ${Server[user]}@${Server[host]} "[ -s '${Server[userHome]}/.nvm/nvm.sh' ] && \. '${Server[userHome]}/.nvm/nvm.sh' && pm2 reload all"
}

printf "\n"
printf "${Blue}+ Prepare to deploy to ${Red}${InputServerName}${Blue}...${NoColor}\n"
create_dest
printf "${Blue}+ Pulling code from ${Red}${Server[branch]}${Blue}...${NoColor}\n"
git_pull
printf "\n${Blue}+ Start deploying code to ${Red}${InputServerName}${Blue}...${NoColor}\n"
deploy
printf "\n${Blue}+ Restarting server ${Red}${InputServerName}${Blue}...${NoColor}\n"
restart_server
printf "\n${Blue}= Completed deploying to ${Red}${InputServerName}${Blue}!${NoColor}\n"

printf "${Blue}= Exiting...${NoColor}\n\n"
exit 0

$SHELL