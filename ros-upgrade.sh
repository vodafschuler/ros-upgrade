#!/bin/bash
## If you haven't seen the Bash script before, it's worth a look. It truly IS terrifying.
## If this code works, it was written by si bloon. If not, I don't know who wrote it.
## If you're reading this, that means you have been screwed.
## I am so, so sorry for you. God speech.
## si bloon.

## repository for routeros to download package
## you can use your own site (local network)
## important NO SLASH at end of repo
repo="https://download.mikrotik.com/routeros"

## routeros version to upgrade
rosver="7.6"

Bold='\033[1m'           # Bold
Italic='\033[3m'         # Italic
Black='\033[1;30m'       # Black
Red='\033[1;31m'         # Red
Green='\033[1;32m'       # Green
Yellow='\033[1;33m'      # Yellow
Blue='\033[1;34m'        # Blue
Purple='\033[1;35m'      # Purple
Cyan='\033[1;36m'        # Cyan
White='\033[1;37m'       # Whit
NC='\033[0m'             # No Color

# Usage
usage()
{
   # Display Usage
   echo
   echo -e "${Bold}Upgrade RouterOS using remote command${NC}"
   echo
   echo -e "Usage: $0 [-u ${Italic}<username>${NC}] [-p ${Italic}<password>${NC}] [-P ${Italic}<ssh-port>${NC}] [-r ${Italic}<repo-url>${NC}] [-v ${Italic}<version>${NC}]"
   echo -e "       ${Blue}hostname1 [hostname2] [hostname3]${NC}"
   echo "options:"
   echo "   -u username   Provide username as argument (default \"admin\")"
   echo "   -p password   Provide password as argument (security unwise)"
   echo "   -P ssh-port   Provide ssh service port (default 22)"
   echo "   -r repo-url   Repository Site (default https://download.mikrotik.com/routeros)"
   echo "   -v version    RouterOS version to upgrade"
   echo "      hostname   Hostname list, list for multiple hostname"
   echo "   -h            Print this Help."
   echo
   exit 1
}

username="admin"
password="\"\""
port="22"

while getopts hr:u:p:P: flag
do
    case "${flag}" in
        u) username=${OPTARG};;
        p) password=${OPTARG};;
        P) port=${OPTARG};;
        v) rosver=${OPTARG};;
        r) repo=${OPTARG};;
        h) usage
        exit 0;;
        *) usage
        exit 1;;
    esac
done
shift "$((OPTIND-1))"

if [ -z "$1" ]
then
  usage
  exit 0
else
  hosts=("$@")
fi

echo "==============================================================================="
for host in "${hosts[@]}"
do
  rosinfo=`sshpass -p ${password} ssh -p ${port} -o "StrictHostKeyChecking no" ${username}@${host} "sys identi pr ; sys resource pr"`

  arch=`echo "$rosinfo" | grep archi | cut -d ":" -f 2`
  rosid=`echo "$rosinfo" | grep " name:" | cut -d ":" -f 2`
  rosbn=`echo "$rosinfo" | grep "board-name:" | cut -d ":" -f 2`
  rosvn=`echo "$rosinfo" | grep "version:" | cut -d ":" -f 2`
  arch="${arch//[$'\t\r\n ']}"
  rosid="${rosid//[$'\t\r\n']}"
  rosbn="${rosbn//[$'\t\r\n']}"
  rosvn="${rosvn//[$'\t\r\n']}"
  if [ -z "$arch" ]
  then
    echo -e "${Red}Host ${Blue}${host} ${Red}not Valid${NC}"
  else
    echo -e "Updating :${Bold}${rosid}${NC}"
    echo -e "IP       : ${Bold}${host}${NC}"
    echo -e "Mikrotik :${Bold}${rosbn} ${NC}(${Bold}${arch}${NC})"
    echo -e "Version  :${Bold}${rosvn} ${NC}Upgrade to ${Bold}${rosver}${NC}"
    if [ $arch == "x86_64" ]
    then
      arch=""
    elif [ $arch == "powerpc" ]
    then
      arch="-ppc"
    else
      arch="-${arch}"
    fi

    url="${repo}/${rosver}/routeros-${rosver}${arch}.npk"
    rosexec="sshpass -p ${password} ssh -p ${port} -o \"StrictHostKeyChecking no\" ${username}@${host} 'tool fetch url=\"${url}\" ; system reboot ;' && echo \"y\""

    rosupg=`echo -ne $(eval $rosexec)`
    if [ -z "$rosupg" ]
    then
      echo -e "${Red}Upgrade Failed"
    else
      echo -e "${Green}Upgrade Succesfuly...${NC}"
      echo -e "${Bold}Now Rebooting Device${NC}"
    fi
  fi
  echo "==============================================================================="
done

exit 0
