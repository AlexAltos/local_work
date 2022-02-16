#!/bin/bash 

NAMEP=community
GITCLONE_web=git@gitlab/backend_web_laravel.git
GITCLONE_admin=git@gitlab/backend_admin_laravel.git

PATHHTML="/var/www/html"
HOSTSIN="/etc/hosts"

NAMEPROJECT_web="gc.local.web"
NAMEPROJECT_admin="gc.local.admin"

var=0
truthRegExp="Y|y|Д|д|E|e|L|l|н|Н"
RED='\033[0;31m'      # ${RED}      красный цвет знаков
GREEN='\033[32m'      # ${GREEN}    зелёный
NORMAL='\033[0m'      # ${NORMAL}   все атрибуты по умолчанию
BOLD='\033[1m'        # ${BOLD} жирный текст 





function GITCLONESTEP {
    echo -e "\ngit clone: $1"
    git clone $1 $PATHHTML/$2
    echo ""
}



echo     "======================================================="
echo -en "BUILD Project: Local ${BOLD}${GREEN} $NAMEP ${NORMAL}\n"
echo     "======================================================="

# Проверяем, есть ли доступ до репозитория
echo -e "\n● ▶ Step 1: Сheck access repository"
for folder in $GITCLONE_web  $GITCLONE_admin ; do
    if git ls-remote $folder &>/dev/null ; then 
        echo -en  "$folder - ${BOLD}${GREEN} [ ✔ ]${NORMAL}\n" ;
    else 
        echo -en "${RED}$folder - !!not ok!! ${NORMAL}\n"
        ((var++));
    fi
done;

if [[ $var -gt 0 ]] ; then 
    echo -en "\n${RED} ---- Not all repositories available  ${NORMAL}\n"
fi
read -p "Continue?"


echo -e "\n● ▶ Step 2: preparation"
echo "stop nginx---apache2---docker"
sudo service nginx stop || true
sudo service apache2 stop || true
sudo systemctl disable apache2 || true
sudo systemctl disable nginx || true
#sudo docker stop $(docker ps -aq) &>/dev/null



# Создание папок и прав
echo -e "\n● ▶ Step 3: Creating directories"
for folder in /volumes  /var/www /var/www/html; do
    if ! [ -d $folder ]; then        
        sudo mkdir $folder || true
        sudo chown $USER:"пользователи домена@geos.local" $folder
        sudo chmod 777 $folder
        echo "$folder - mkdir"
    else 
        echo "$folder - [ ✔ ]"
        sudo chmod 777 $folder
    fi
done;


echo -e "\n● ▶ Step 4: Clone repository: $GITCLONE"
# Проверка присутсвия проекта. Зачистить и обновить
for folder in "$GITCLONE_web $NAMEPROJECT_web"  "$GITCLONE_admin $NAMEPROJECT_admin" ; do
    set -- $folder # Разбиение переменной на множество аргументов (позиционных параметров).

    echo -en "${BOLD}${GREEN}$1 ${NORMAL}\n"
    echo -en "${BOLD}${GREEN}$PATHHTML/$2  ${NORMAL}\n"

    if  [ -d "$PATHHTML/$2" ]; then
        echo "-->> EXIST"
        echo -e "\nDell and clone NEW?"
        echo "[Yes: ($truthRegExp)] [Skip: [Enter]]"

        read DECREE
        if [[ "$DECREE" =~ $truthRegExp ]]; then
            sudo rm -rf "$PATHHTML/$2" || true

            echo "▶ $PATHHTML/$2 --- was removed"    
            GITCLONESTEP $1 $2
        fi
    else 
        
        GITCLONESTEP $1 $2
    fi
done;


#Добавляем имя в /etc/hosts
echo -e "\n▶ Step 5: Add SERVER_NAME in Local HOSTS"
for NAME in $NAMEPROJECT_web $NAMEPROJECT_admin $HOSTS_web $HOSTS_admin; do
    if grep $NAME $HOSTSIN; then
        echo "HOSTS is present" 
    else echo "Add: $NAME" && sudo bash -c "echo -e '\n127.0.0.1 $NAME' >> $HOSTSIN"
    fi
done;



echo -e "\n● ▶ Step 6: Start app "
#for NAME in $NAMEPROJECT_web $NAMEPROJECT_admin; do
for NAME in $NAMEPROJECT_web $NAMEPROJECT_admin ; do    
    echo -en "\n==> ${BOLD}${GREEN}$NAME ${NORMAL}\n"
    # даем рута на весь раздел
    echo -e "---> chmod 777 $NAME"
    sudo chmod -R 777 "$PATHHTML/$NAME"

    # копировать локальный энвик в корень для данноего приложения
    echo -e "---> copy .deploy/.local/.env --> dir"
    cp /var/www/html/$NAME/.deploy/.local/.env /var/www/html/$NAME/.env

    echo -e "---> start docker-compose"
    sudo docker-compose -f /var/www/html/$NAME/.deploy/.local/docker-compose.yml down
    sudo docker-compose -f /var/www/html/$NAME/.deploy/.local/docker-compose.yml pull
    sudo docker-compose -f /var/www/html/$NAME/.deploy/.local/docker-compose.yml up -d --force-recreate    
done;


sleep 10


echo -e "\n● ▶ Step 7: Start browser"
#Запуск браузера с линком проекта
LINK_WEB="http://$NAMEPROJECT_web:8080/common/languages"
LINK_ADMIN="http://$NAMEPROJECT_admin:8090/api/employee-users/list"

for NAME in $LINK_WEB $LINK_ADMIN; do
    echo $NAME
    xdg-open $NAME
done;


echo -e "\n===> INFO <==="  
echo -e "\nRestart docker:"  
for NAME in $NAMEPROJECT_web $NAMEPROJECT_admin ; do 
    echo "sudo docker-compose -f /var/www/html/$NAME/.deploy/.local/docker-compose.yml up -d --force-recreate"
done;

