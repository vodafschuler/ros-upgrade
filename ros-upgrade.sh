#!/bin/bash
## Mikrotik RouterOS Upgrade Script
## Description: Script to upgrade multiple Mikrotik devices from a list
## If you haven't seen the Bash script before, it's worth a look. It truly IS terrifying.
## If this code works, it was written by si bloon. If not, I don't know who wrote it.
## If you're reading this, that means you have been screwed.
## I am so, so sorry for you. God speech.
## si bloon.

# Text Formatting
Bold='\033[1m'           # Bold
Italic='\033[3m'         # Italic
Black='\033[1;30m'       # Black
Red='\033[1;31m'         # Red
Green='\033[1;32m'       # Green
Yellow='\033[1;33m'      # Yellow
Blue='\033[1;34m'        # Blue
Purple='\033[1;35m'      # Purple
Cyan='\033[1;36m'        # Cyan
White='\033[1;37m'       # White
NC='\033[0m'             # No Color

# Configuration
port="22"
username="admin"
password="\"\""
wd=80
repo="https://download.mikrotik.com/routeros"  # Add your actual repo URL
rosver="7.18.2"                                # Set your target version

# Usage information
usage() {
     echo
     echo -e "  ${Bold}Upgrade RouterOS using remote command${NC}"
     echo
     echo -e "    Usage: $0 ${Blue}-f <filename>${NC} [options]"
     #echo -e "       or: $0 ${Blue}<hostname1> [hostname2] [hostname3]${NC} [options]"
     echo -e "       or: $0 [-u ${Italic}<username>${NC}] [-p ${Italic}<password>${NC}] [-P ${Italic}<ssh-port>${NC}] [-r ${Italic}<repo-url>${NC}] [-v ${Italic}<version>${NC}]"
     echo -e "           ${Blue}hostname1 [hostname2] [hostname3]${NC}"
     echo
     echo "  Options:"
     echo -e "      ${Yellow}-f filename${NC}   File containing list of hosts (format: IP Description)"
     echo -e "      ${Yellow}-u username${NC}   SSH username (default: admin)"
     echo -e "      ${Yellow}-p password${NC}   SSH password"
     echo -e "      ${Yellow}-P port${NC}       SSH port (default: 22)"
     echo -e "      ${Yellow}-r repo-url${NC}   Repository URL (default: https://download.mikrotik.com/routeros)"
     echo -e "      ${Yellow}-v version${NC}    RouterOS target version (default: 7.18.2)"
     echo -e "      ${Yellow}-h${NC}            Show this help message"
     echo
     exit 1
}

# Parse command line options and hosts
positional_args=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -u) username="$2"; shift 2 ;;
        -p) password="$2"; shift 2 ;;
        -P) port="$2"; shift 2 ;;
        -r) repo="$2"; shift 2 ;;
        -v) rosver="$2"; shift 2 ;;
        -f) route_file="$2"; shift 2 ;;
        -h) usage ;;
        --) shift; positional_args+=("$@"); break ;;
        -*) echo -e "    ${Red}Unknown option: $1${NC}" >&2; usage ;;
        *) positional_args+=("$1"); shift ;;
    esac
done

# Set hosts from positional arguments
hosts=("${positional_args[@]}")

# Validate required parameters
# Mode file atau host langsung
if [ -n "$route_file" ]; then
    # Mode file - validate file
    if [ ! -f "$route_file" ]; then
        echo -e "    ${Red}Error: File '$route_file' not found!${NC}"
        exit 1
    fi
    mapfile -t file_hosts < <(grep -v '^---' "$route_file" | awk '{print $1}')
    hosts=("${file_hosts[@]}")
elif [ ${#hosts[@]} -eq 0 ]; then
    echo -e "    ${Red}Error: Either -f <filename> or host list required${NC}"
    usage
fi

# Function to print separator line
print_separator() {
    printf '%*s\n' $wd | tr ' ' '-'
}

# Main processing
print_separator

total_hosts=${#hosts[@]}
for ((i=0; i<$total_hosts; i++)); do
    host="${hosts[$i]}"
    
    echo -e "  ${Cyan}Processing Host   : ${Bold}$host${NC}"
    # Get description from file if available
    if [ -n "$route_file" ] && [ -f "$route_file" ]; then
        line=$(grep "^$host" "$route_file" 2>/dev/null)
        if [ -n "$line" ]; then
            id=$(echo "$line" | sed -E 's/^[[:space:]]*[^[:space:]]+[[:space:]]+//')
            echo -e "    ${Yellow}Description     : $id${NC}"
        fi
    fi

    # SSH execution with error handling
    if rosinfo=$(sshpass -p "$password" ssh -n -p "$port" -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" "$username@$host" "/sys identity print ; /sys resource print" 2>&1); then
        # Extract system information
        rosid=$(echo "$rosinfo" | awk -F': ' '/^[[:space:]]*name:/ {sub(/\r/,"",$2); print $2}' | head -n1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        arch=$(echo "$rosinfo" | awk -F': ' '/^[[:space:]]*architecture-name:/ {sub(/\r/,"",$2); print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        rosbn=$(echo "$rosinfo" | awk -F': ' '/^[[:space:]]*board-name:/ {sub(/\r/,"",$2); print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        rosvn=$(echo "$rosinfo" | awk -F': ' '/^[[:space:]]*version:/ {sub(/\r/,"",$2); print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ -z "$arch" ]; then
            echo -e "    ${Red}Host ${Blue}${host} ${Red}not Valid${NC}"
        else
            # Display device info
            echo -e "\n  ${Green}Device Information:${NC}"
            echo -e "    Identity        : ${Bold}${rosid}${NC}"
            echo -e "    IP Address      : ${Bold}${host}${NC}"
            echo -e "    Board Model     : ${Bold}${rosbn}${NC}"
            echo -e "    Arch            : ${Bold}${arch}${NC}"
            echo -e "    Version         : ${Bold}${rosvn}${NC}"
            echo -e "    Upgrade Version : ${Bold}${rosver}${NC}"

            # Prepare architecture suffix
            if [ "$arch" == "x86_64" ]; then
                arch=""
            elif [ "$arch" == "powerpc" ]; then
                arch="-ppc"
            else
                arch="-${arch}"
            fi

            # Upgrade process
            url="${repo}/${rosver}/routeros-${rosver}${arch}.npk"
            echo -e "\n  ${Yellow}Starting upgrade process...${NC}"
            echo -e "    Download URL: ${Blue}${url}${NC}"

            #rosexec="sshpass -p ${password} ssh -p ${port} -o \"StrictHostKeyChecking no\" ${username}@${host} 'tool fetch url=\"${url}\" ; system reboot ;' && echo \"y\""
            rosexec="sshpass -p ${password} ssh -p ${port} -o \"StrictHostKeyChecking no\" ${username}@${host} 'tool fetch url=\"${url}\"' "
            rosupg=$(eval "$rosexec")

            if [ -z "$rosupg" ]; then
                echo -e "    ${Red}Upgrade Failed${NC}"
            else
                echo -e "    ${Green}Upgrade Successful!${NC}"
                echo -e "    ${Bold}Now Rebooting Device${NC}"
            fi
        fi
    else
        echo -e "    ${Red}SSH Connection Failed to ${host}${NC}"
        echo -e "    Error message: ${rosinfo}"
    fi

    print_separator
done

echo -e "    \n${Green}Processing complete for all devices.${NC}"
