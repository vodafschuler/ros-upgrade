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
bullet="*"	 # Bullet Char

# Configuration
port="22"
username="admin"
password="\"\""
wd=80
repo="https://download.mikrotik.com/routeros"  # Add your actual repo URL
rosver="7.18.2"                 # Set your target version
reboot="no"                     # Default no reboot
adds_pkgs=()
excluded_pkgs=("routeros" "kernel")  

# Usage information
usage() {
     echo
     echo -e "  ${Bold}Upgrade RouterOS using remote command${NC}"
     echo
     echo -e "    Usage: $0 ${Blue}-f <filename>${NC} [options]"
     #echo -e "       or: $0 ${Blue}<hostname1> [hostname2] [hostname3]${NC} [options]"
     echo -e "       or: $0 [-u ${Italic}<username>${NC}] [-p ${Italic}<password>${NC}] [-P ${Italic}<ssh-port>${NC}] [-r ${Italic}<repo-url>${NC}] [-v ${Italic}<version>${NC}] [-R ${Italic}<yes/no>${NC}]"
     echo -e "           ${Blue}hostname1 [hostname2] [hostname3]${NC}"
     echo
     echo "  Options:"
     echo -e "      ${Yellow}-f filename${NC}   File containing list of hosts (format: IP Description)"
     echo -e "      ${Yellow}-u username${NC}   SSH username (default: admin)"
     echo -e "      ${Yellow}-p password${NC}   SSH password"
     echo -e "      ${Yellow}-P port${NC}       SSH port (default: 22)"
     echo -e "      ${Yellow}-r repo-url${NC}   Repository URL (default: https://download.mikrotik.com/routeros)"
     echo -e "      ${Yellow}-v version${NC}    RouterOS target version (default: 7.18.2)"
     echo -e "      ${Yellow}-R [yes/no]${NC}    Auto reboot after upgrade (default: no, use -R alone for yes)"
     echo -e "      ${Yellow}-a packages${NC}   Additional packages to install (comma-separated)"
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
        -R) 
            if [[ $2 == "yes" || $2 == "no" ]]; then
                reboot="$2"
                shift 2
            else
                reboot="yes"
                shift
            fi
            ;;
	-a)
	    if [ -n "$2" ]; then
	        IFS=',' read -r -a adds_pkgs <<< "$2"
		rosaddon="yes"
	    else
	        echo -e "    ${Red}Error: -a requires package list (e.g., -a pkg1,pkg2)${NC}"
	        exit 1
	    fi
	    shift 2
	    ;;
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

# Validate reboot option
if [[ "$reboot" != "yes" && "$reboot" != "no" ]]; then
    echo -e "    ${Red}Error: -R option must be either 'yes' or 'no'${NC}"
    usage
fi

# Function to check if host is online
check_host_online() {
    local host=$1
    local max_attempts=6
    local attempt=0
    local online=0
    
    echo -ne "    ${Yellow}Waiting for host to come back online...${NC}"
    
    while [[ $attempt -lt $max_attempts ]]; do
        sleep 4
        if ping -c 1 -W 2 "$host" &> /dev/null; then
            online=1
            break
        fi
        attempt=$((attempt + 1))
	echo -ne "${Yellow}.${NC}"
    done
    
    if [[ $online -eq 1 ]]; then
        echo -e "    ${Green}Host is back online${NC}"
        return 0
    else
        echo -e "\n    ${Red}Host did not come back online after $max_attempts attempts${NC}"
        return 1
    fi
}

# Function to print separator line
print_separator() {
    printf '%*s\n' $wd | tr ' ' '-'
}

# Main processing
printf '%*s\n' $wd | tr ' ' '='

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
    if rosinfo=$(sshpass -p "$password" ssh -n -p "$port" -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" "$username@$host" "/sys identity print ; /sys resource print ; /sys package print" 2>&1); then
        # Extract system information
        rosid=$(echo "$rosinfo" | awk -F': ' '/^[[:space:]]*name:/ {sub(/\r/,"",$2); print $2}' | head -n1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        arch=$(echo "$rosinfo" | awk -F': ' '/^[[:space:]]*architecture-name:/ {sub(/\r/,"",$2); print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        rosbn=$(echo "$rosinfo" | awk -F': ' '/^[[:space:]]*board-name:/ {sub(/\r/,"",$2); print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        rosvn=$(echo "$rosinfo" | awk -F': ' '/^[[:space:]]*version:/ {sub(/\r/,"",$2); print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
	additional_pkgs=("${adds_pkgs[@]}")

	while read -r line; do
	    if [[ "$line" =~ ^[0-9]+\ +[a-zA-Z0-9-]+\ +[0-9.]+ ]]; then
	        pkg_name=$(echo "$line" | awk '{print $2}')
	        skip=0
	        for excluded in "${excluded_pkgs[@]}"; do
	            [[ "$pkg_name" == "$excluded" ]] && skip=1 && break
	        done
	        [[ $skip -eq 0 ]] && additional_pkgs+=("$pkg_name")
	    fi
	done <<< "$(echo "$rosinfo" | grep -A10 'Columns: NAME, VERSION, BUILD-TIME, SIZE')"

        if [ -z "$arch" ]; then
            echo -e "    ${Red}Host ${Blue}${host} ${Red}not Valid${NC}"
        else
            # Display device info
            echo -e "\n  ${Green}Device Information:${NC}"
            echo -e "    Identity        : ${Bold}${rosid}${NC}"
            echo -e "    IP Address      : ${Bold}${host}${NC}"
            echo -e "    Board Model     : ${Bold}${rosbn}${NC}"
            echo -e "    Arch            : ${Bold}${arch}${NC}"

            # Prepare architecture suffix
            if [ "$arch" == "x86_64" ]; then
                arch=""
            elif [ "$arch" == "powerpc" ]; then
                arch="-ppc"
            else
                arch="-${arch}"
            fi

	    # Upgrade process - only if target version is newer
	    echo -e "\n  ${Purple}Version Check:${NC}"
            echo -e "    Version         : ${Bold}${rosvn}${NC}"
            echo -e "    Upgrade Version : ${Bold}${rosver}${NC}"
	    if [ ${#additional_pkgs[@]} -gt 0 ]; then
                # Remove duplicates and update additional_pkgs array
                declare -A seen
                unique_pkgs=()
                for pkg in "${additional_pkgs[@]}"; do
                    if [[ -z "${seen[$pkg]}" ]]; then
                        unique_pkgs+=("$pkg")
                        seen["$pkg"]=1
                    fi
                done
                additional_pkgs=("${unique_pkgs[@]}")

	        formatted_pkgs=$(printf " ${bullet} %s\n                     " "${additional_pkgs[@]}" | sed '$ s/\n$//')
	        echo -ne "    Add-on Packages :${Bold}${formatted_pkgs%%$'\n'}${NC}"
	    fi

	    # Convert version numbers to comparable format
	    current_ver=$(echo "$rosvn" | awk -F. '{ printf("%03d%03d%03d\n", $1,$2,$3); }')
	    target_ver=$(echo "$rosver" | awk -F. '{ printf("%03d%03d%03d\n", $1,$2,$3); }')
	    if [[ "$target_ver" > "$current_ver" ]]; then
		rosinstall="yes"
	    fi
	    if [[ "$rosinstall" == "yes" ]] || [[ "$rosaddon" == "yes" ]]; then
                if [[ "$rosinstall" == "yes" ]]; then
                    url="${repo}/${rosver}/routeros-${rosver}${arch}.npk"
                    echo -e "\n  ${Yellow}Starting upgrade process (new version available)...${NC}"
                    echo -e "    Download URL: ${Blue}${url}${NC}"

                    echo -ne "    ${Yellow}Downloading upgrade package...${NC}"
                    # Start progress display in background
                    progress_pid=""
                    (
                        while true; do
                            echo -ne "${Yellow}.${NC}"
                            sleep 1
                        done
                    ) & progress_pid=$!
                    # Execute download command
                    rosexec="sshpass -p ${password} ssh -p ${port} -o \"StrictHostKeyChecking no\" ${username}@${host} 'tool fetch url=\"${url}\"'"
                    rosupg=$(eval "$rosexec" 2>&1)
                    download_status=$?
                    # Stop progress display
                    kill $progress_pid 2>/dev/null
                    wait $progress_pid 2>/dev/null

                    # Check download status
                    if [ $download_status -eq 0 ]; then
                        echo -e "    ${Green}Download completed${NC}"
                        upgrade_success=true
                    else
                        echo -e "    ${Red}Download failed${NC}"
                        echo -e "    ${Yellow}Error details:${NC}"
                        echo "$rosupg" | sed 's/^/      /'
                        upgrade_success=false
                    fi

                    # Continue with file verification if download was successful
                    if [ "$upgrade_success" = true ]; then
                        echo -ne "    ${Yellow}Verifying downloaded file...${NC}"
                        file_check="sshpass -p ${password} ssh -p ${port} -o \"StrictHostKeyChecking no\" ${username}@${host} 'file print where name=\"${url##*/}\"'"
                        file_result=$(eval "$file_check")

                        if [[ "$file_result" == *"${url##*/}"* ]]; then
                            echo -e "    ${Green}File verification passed${NC}"
                        else
                            echo -e "    ${Red}File verification failed${NC}"
                            echo -e "    ${Yellow}File check result:${NC}"
                            echo "$file_result" | sed 's/^/      /'
                            upgrade_success=false
                        fi
                    fi
                fi

                # Check if we have additional packages to install
                if [[ "$rosaddon" == "yes" ]]; then
                    if [ ${#additional_pkgs[@]} -gt 0 ]; then
	                if [[ "$rosinstall" != "yes" ]]; then
			    echo -e ""
			fi
                        echo -e "  ${Yellow}Processing additional packages...${NC}"
                        for pkg in "${additional_pkgs[@]}"; do
                            echo -e "    Additional package: ${Cyan}${pkg}${NC}"
                            pkg_url="${repo}/${rosver}/${pkg}-${rosver}${arch}.npk"
                            echo -e "    Package URL: ${Blue}${pkg_url}${NC}"
                            # Download package
                            echo -ne "    ${Yellow}Downloading package...${NC}"
                            pkg_exec="sshpass -p ${password} ssh -p ${port} -o \"StrictHostKeyChecking no\" ${username}@${host} 'tool fetch url=\"${pkg_url}\"'"
                            pkg_result=$(eval "$pkg_exec" 2>&1)
                            if [ $? -eq 0 ]; then
                                echo -e "    ${Green}Download successful${NC}"
                                upgrade_success=true
                            else
                                echo -e "    ${Red}Download failed${NC}"
                                echo -e "    ${Yellow}Error details:${NC}"
                                echo "$pkg_result" | sed 's/^/      /'
                                upgrade_success=false
                            fi
                        done
                    fi
                fi

                if [ "$upgrade_success" = true ]; then
                    if [[ "$reboot" == "yes" ]]; then
                        echo -e "  ${Bold}Now Rebooting Device${NC}"
			reboot_exec="sshpass -p ${password} ssh -p ${port} -o \"StrictHostKeyChecking no\" ${username}@${host} 'system reboot' >/dev/null 2>&1"
			eval "$reboot_exec"
                    	# Verify host comes back online after reboot
                    	if check_host_online "$host"; then
	                    # Check for missing packages in logs
        	            log_check="sshpass -p ${password} ssh -p ${port} -o \"StrictHostKeyChecking no\" ${username}@${host} 'log print where message~\"missing package\"'"
                	    missing_package=$(eval "$log_check" | awk -F'package' '{print $2}' | awk '{print $1}' | sed 's/[^a-zA-Z0-9-]//g')
	                    if [ -n "$missing_package" ]; then
                    		echo -e "    ${Red}Upgrade Failed !!!${NC}"
        	                echo -e "    ${NC}Missing package detected: ${Red}${Bold}${missing_package}${NC}"
                	    else
			        roscek=$(sshpass -p "$password" ssh -p "$port" -o "StrictHostKeyChecking no" "$username@$host" "system resource print" 2>&1)
			        rosvnupd=$(echo "$roscek" | awk -F': ' '/^[[:space:]]*version:/ {sub(/\r/,"",$2); print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                                echo -e "    ${Green}Upgrade Successful to version ${NC}${Bold}$rosvnupd${NC}"
                        	upgrade_success=true
	                    fi
                    	else
                            echo -e "    ${Red}Upgrade Failed !!! (Device did not come back online)${NC}"
                            upgrade_success=false
                        fi
                    else
                        echo -e "  ${Cyan}Upgrade Pending! (Reboot skipped)${NC}"
                        echo -e "  ${Yellow}Remember to reboot manually to complete the upgrade${NC}"
                    fi
                else
                    echo -e "  ${Red}Upgrade Failed !!!${NC}"
                fi

	    elif [[ "$target_ver" == "$current_ver" ]]; then
	        echo -e "\n  ${Green}Device already running target version ${rosver}${NC}"
	    else
	        echo -e "\n  ${Yellow}Device version ${rosvn} is newer than target ${rosver}${NC}"
	        echo -e "  ${Yellow}Skipping upgrade${NC}"
	    fi
        fi

    else
        echo -e "    ${Red}SSH Connection Failed to ${host}${NC}"
        echo -e "    Error message: ${rosinfo}"
    fi
    print_separator
done

echo -e "  ${Green}Processing complete for all devices.${NC}"
printf '%*s\n' $wd | tr ' ' '='
