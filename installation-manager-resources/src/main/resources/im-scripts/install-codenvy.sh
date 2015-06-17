#!/bin/bash

# bash <(curl -L -s https://start.codenvy.com/install-single)
#
# allowed options:
# --multi
# --silent
# --version=<VERSION TO INSTALL>
# --hostname=<CODENVY HOSTNAME>
# --systemAdminName=<SYSTEM ADMIN NAME>
# --systemAdminPassword=<SYSTEM ADMIN PASSWORD>
set -e

unset HOST_NAME
unset SYSTEM_ADMIN_NAME
unset SYSTEM_ADMIN_PASSWORD

setRunOptions() {
    START_TIME=`date +%s`
    DIR="${HOME}/codenvy-im"
    ARTIFACT="codenvy"
    CODENVY_TYPE="single"
    SILENT=false
    VERSION=`curl -s https://codenvy.com/update/repository/properties/${ARTIFACT} | sed 's/.*"version":"\([^"].*\)".*/\1/'`
    for var in "$@"; do
        if [[ "$var" == "--multi" ]]; then
            CODENVY_TYPE="multi"
        elif [[ "$var" == "--silent" ]]; then
            SILENT=true
        elif [[ "$var" =~ --version=.* ]]; then
            VERSION=`echo "$var" | sed -e "s/--version=//g"`
        elif [[ "$var" =~ --hostname=.* ]]; then
            HOST_NAME=`echo "$var" | sed -e "s/--hostname=//g"`
        elif [[ "$var" =~ --systemAdminName=.* ]]; then
            SYSTEM_ADMIN_NAME=`echo "$var" | sed -e "s/--systemAdminName=//g"`
        elif [[ "$var" =~ --systemAdminPassword=.* ]]; then
            SYSTEM_ADMIN_PASSWORD=`echo "$var" | sed -e "s/--systemAdminPassword=//g"`
        fi
    done
    CONFIG="codenvy-${CODENVY_TYPE}-server.properties"

    if [[ ${CODENVY_TYPE} == "single" ]] && [[ ! -z ${HOST_NAME} ]] && [[ ! -z ${SYSTEM_ADMIN_PASSWORD} ]] && [[ ! -z ${SYSTEM_ADMIN_NAME} ]]; then
        SILENT=true
    fi
}

downloadConfig() {
    curl -s -o ${CONFIG} https://codenvy.com/update/repository/public/download/codenvy-${CODENVY_TYPE}-server-properties/${VERSION}
}

validateOS() {
    if [ -f /etc/redhat-release ]; then
        OS="Red Hat"
    else
        printLn  "Operation system isn't supported."
        exit 1
    fi
    OS_VERSION=`cat /etc/redhat-release | sed 's/.* \([0-9.]*\) .*/\1/' | cut -f1 -d '.'`

    if [ "${VERSION}" == "3.1.0" ] && [ "${OS_VERSION}" != "6" ]; then
        printLn "Codenvy 3.1.0 can be installed onto CentOS 6.x only"
        exit 1
    fi

    if [ "${CODENVY_TYPE}" == "multi" ] && [ "${OS_VERSION}" != "7" ]; then
        printLn "Codenvy multi-node can be installed onto CentOS 7.x only"
        exit 1
    fi
}

# $1 - command name
installPackageIfNeed() {
    command -v $1 >/dev/null 2>&1 || { # check if requered command had been already installed earlier
        sudo yum install $1 -y -q
    }
}

preconfigureSystem() {
    sudo yum clean all &> /dev/null
    installPackageIfNeed curl

    validateOS
    setRunOptions "$@"

    [ ! -f ${CONFIG} ] && downloadConfig
}

installJava() {
    wget -q --no-cookies --no-check-certificate --header 'Cookie: oraclelicense=accept-securebackup-cookie' 'http://download.oracle.com/otn-pub/java/jdk/8u45-b14/jre-8u45-linux-x64.tar.gz' --output-document=jre.tar.gz

    tar -xf jre.tar.gz -C ${DIR}
    mv ${DIR}/jre1.8.0_45 ${DIR}/jre

    rm jre.tar.gz
}

installIm() {
    IM_URL="https://codenvy.com/update/repository/public/download/installation-manager-cli"
    IM_FILE=$(curl -sI  ${IM_URL} | grep -o -E 'filename=(.*)[.]tar.gz' | sed -e 's/filename=//')

    curl -s -o ${IM_FILE} -L ${IM_URL}

    mkdir ${DIR}/codenvy-cli
    tar -xf ${IM_FILE} -C ${DIR}/codenvy-cli

    sed -i "2iJAVA_HOME=${HOME}/codenvy-im/jre" ${DIR}/codenvy-cli/bin/codenvy
}

clearLine() {
    echo -en "\033[2K"                  # clear line
}

cursorUp() {
    echo -en "\e[1A"
}

printPrompt() {
    clearLine
    echo -en "\e[94m[CODENVY]\e[0m "    # with blue color
}

print() {
    printPrompt; echo -n "$1"
}

printLn() {
    printPrompt; echo "$1"
}

askProperty() {
    read VALUE
    echo ${VALUE}
}

insertProperty() {
    sed -i s/$1=.*/$1=$2/g ${CONFIG}
}

updateHostsFile() {
    [ -z ${HOST_NAME} ] && HOST_NAME=`grep host[_url]*=.* ${CONFIG} | cut -f2 -d '='`

    if ! sudo grep -Eq "127.0.0.1.*puppet" /etc/hosts; then
        echo '127.0.0.1 puppet' | sudo tee --append /etc/hosts > /dev/null
    fi
    if ! sudo grep -Fq "${HOST_NAME}" /etc/hosts; then
        echo "127.0.0.1 ${HOST_NAME}" | sudo tee --append /etc/hosts > /dev/null
    fi
}

askAndInsertProperty() {
    PROMPT=$1
    VARIABLE=$2
    
    print "${PROMPT}: "
    read VALUE

    insertProperty "${VARIABLE}" ${VALUE}
}

executeIMCommand() {
    ${DIR}/codenvy-cli/bin/codenvy $1 $2 $3 $4 $5 $6 $7 $8 $9
}

pressAnyKeyToContinueAndClearConsole() {
    if [[ ${SILENT} == false ]]; then
        printLn  "Press any key to continue"
        read -n1 -s
        clear
    fi
}

pressAnyKeyToContinue() {
    if [[ ${SILENT} == false ]]; then
        printLn  "Press any key to continue"
        read -n1 -s
    fi
}

pressYKeyToContinue() {
    if [[ ${SILENT} == false ]]; then
        print  "Continue installation [y/N]: "
        read ANSWER
        [ ! "${ANSWER}" == "y" ] && exit 1
    fi
}

printPreInstallInfo_single() {
    availableRAM=`cat /proc/meminfo | grep MemTotal | awk '{tmp = $2/1024/1024; printf"%0.1f",tmp}'`
    availableDiskSpace=`sudo df -h ${HOME} | tail -1 | awk '{print $2}'`
    availableCores=`grep -c ^processor /proc/cpuinfo`

    printLn "Welcome. This program installs a single node Codenvy On-Prem."
    printLn ""
    printLn "Checking for system pre-requisites..."
    printLn ""
    printLn "RESOURCE      : RECOMMENDED : AVAILABLE"
    printLn "RAM           : 8 GB        : ${availableRAM} GB"
    printLn "CPU           : 4 cores     : ${availableCores} cores"
    printLn "Disk Space    : 300 GB      : ${availableDiskSpace} GB"
    printLn ""
    printLn "Sizing Guide       : http://docs.codenvy.com/onpremises"
    printLn "Configuration File : "${CONFIG}
    pressAnyKeyToContinueAndClearConsole

    printLn ""

    if [[ ${SILENT} == true ]]; then
        [ ! -z "${SYSTEM_ADMIN_NAME}" ] && insertProperty "admin_ldap_user_name" ${SYSTEM_ADMIN_NAME}
        [ ! -z "${SYSTEM_ADMIN_PASSWORD}" ] && insertProperty "system_ldap_password" ${SYSTEM_ADMIN_PASSWORD}
        [ ! -z "${HOST_NAME}" ] && insertProperty "host_url" ${HOST_NAME}
    else
        [ -z "${SYSTEM_ADMIN_NAME}" ] && printLn "System admin user name : will prompt for entry"
        [ -z "${SYSTEM_ADMIN_PASSWORD}" ] && printLn "System admin password  : will prompt for entry"
        [ -z "${HOST_NAME}" ] && printLn "Codenvy DNS hostname   : will prompt for entry"

        printLn ""
        pressAnyKeyToContinue
        printLn ""

        if [ -z "${SYSTEM_ADMIN_NAME}" ]; then
            print "System admin user name: "
            SYSTEM_ADMIN_NAME=$(askProperty)
        fi

        if [ -z "${SYSTEM_ADMIN_PASSWORD}" ]; then
            print "System admin password: "
            SYSTEM_ADMIN_PASSWORD=$(askProperty)
        fi

        if [ -z "${HOST_NAME}" ]; then
            print "Codenvy DNS hostname: "
            HOST_NAME=$(askProperty)
        fi

        insertProperty "admin_ldap_user_name" ${SYSTEM_ADMIN_NAME}
        insertProperty "system_ldap_password" ${SYSTEM_ADMIN_PASSWORD}
        insertProperty "host_url" ${HOST_NAME}

        printLn ""
    fi

    updateHostsFile

    pressYKeyToContinue
}

printPreInstallInfo_multi() {
    availableRAM=`cat /proc/meminfo | grep MemTotal | awk '{tmp = $2/1024/1024; printf"%0.1f",tmp}'`
    availableDiskSpace=`sudo df -h ${HOME} | tail -1 | awk '{print $2}'`
    availableCores=`grep -c ^processor /proc/cpuinfo`

    printLn "Welcome. This program installs a multi-node Codenvy On-Prem."
    printLn ""
    printLn "Checking for system pre-requisites..."
    printLn ""
    printLn "Recommended resources for the nodes:"
    printLn "RAM         : 1 GB"
    printLn "Disk Space  : 14 GB"
    printLn "OS          : CentOS 7"
    printLn ""
    printLn "Recommended requirements for the runners:"
    printLn "RAM         : 1.5 GB"
    printLn "Disk Space  : 50 GB"
    printLn "OS          : CentOS 7"
    printLn ""
    printLn "Sizing Guide       : http://docs.codenvy.com/onpremises"
    printLn "Configuration File : "${CONFIG}
    pressAnyKeyToContinueAndClearConsole

    printLn ""

    if [[ ${SILENT} == true ]]; then
        [ ! -z ${SYSTEM_ADMIN_NAME} ] && insertProperty "admin_ldap_user_name" ${SYSTEM_ADMIN_NAME}
        [ ! -z ${SYSTEM_ADMIN_PASSWORD} ] && insertProperty "system_ldap_password" ${SYSTEM_ADMIN_PASSWORD}
        [ ! -z ${HOST_NAME} ] && insertProperty "host_url" ${HOST_NAME}

        HOST_NAME=`grep host[_url]*=.* ${CONFIG} | cut -f2 -d '='`
        PUPPET_MASTER_HOST_NAME=`grep puppet_master_host_name=.* ${CONFIG} | cut -f2 -d '='`
        DATA_HOST_NAME=`grep data_host_name=.* ${CONFIG} | cut -f2 -d '='`
        API_HOST_NAME=`grep api_host_name=.* ${CONFIG} | cut -f2 -d '='`
        BUILDER_HOST_NAME=`grep builder_host_name=.* ${CONFIG} | cut -f2 -d '='`
        RUNNER_HOST_NAME=`grep runner_host_name=.* ${CONFIG} | cut -f2 -d '='`
        DATASOURCE_HOST_NAME=`grep datasource_host_name=.* ${CONFIG} | cut -f2 -d '='`
        ANALYTICS_HOST_NAME=`grep analytics_host_name=.* ${CONFIG} | cut -f2 -d '='`
        SITE_HOST_NAME=`grep site_host_name=.* ${CONFIG} | cut -f2 -d '='`

        printLn "Codenvy DNS hostname                    : "${HOST_NAME}
        printLn "Codenvy Puppet Master node DNS hostname : "${PUPPET_MASTER_HOST_NAME}
        printLn "Codenvy Data node DNS hostname          : "${DATA_HOST_NAME}
        printLn "Codenvy API node DNS hostname           : "${API_HOST_NAME}
        printLn "Codenvy Builder node DNS hostname       : "${BUILDER_HOST_NAME}
        printLn "Codenvy Runner node DNS hostname        : "${RUNNER_HOST_NAME}
        printLn "Codenvy Datasource node DNS hostname    : "${DATASOURCE_HOST_NAME}
        printLn "Codenvy Analytics node DNS hostname     : "${ANALYTICS_HOST_NAME}
        printLn "Codenvy Site node DNS hostname          : "${SITE_HOST_NAME}
        printLn ""

    else
        [ -z ${SYSTEM_ADMIN_NAME} ] && printLn "System admin user name : will prompt for entry"
        [ -z ${SYSTEM_ADMIN_PASSWORD} ] && printLn "System admin password  : will prompt for entry"
        printLn "Codenvy nodes' DNS hostnames : will prompt for entry"

        printLn ""
        pressAnyKeyToContinue
        printLn ""

        if [ -z "${SYSTEM_ADMIN_NAME}" ]; then
            print "System admin user name: "
            SYSTEM_ADMIN_NAME=$(askProperty)
        fi

        if [ -z "${SYSTEM_ADMIN_PASSWORD}" ]; then
            print "System admin password: "
            SYSTEM_ADMIN_PASSWORD=$(askProperty)
        fi


        insertProperty "admin_ldap_user_name" ${SYSTEM_ADMIN_NAME}
        insertProperty "system_ldap_password" ${SYSTEM_ADMIN_PASSWORD}

        askAndInsertProperty "Please set the DNS hostname to be used by Codenvy" "host_url"
        askAndInsertProperty "Please set the DNS hostname of the Puppet Master node" "puppet_master_host_name"
        askAndInsertProperty "Please set the DNS hostname of the Data node" "data_host_name"
        askAndInsertProperty "Please set the DNS hostname of the API node" "api_host_name"
        askAndInsertProperty "Please set the DNS hostname of the Builder node" "builder_host_name"
        askAndInsertProperty "Please set the DNS hostname of the Runner node" "runner_host_name"
        askAndInsertProperty "Please set the DNS hostname of the Datasource node" "datasource_host_name"
        askAndInsertProperty "Please set the DNS hostname of the Analytics node" "analytics_host_name"
        askAndInsertProperty "Please set the DNS hostname of the Site node" "site_host_name"

        printLn ""
    fi

    pressYKeyToContinue
}

doConfigureSystem() {
    printLn "Configuring system..."

    if [ -d ${DIR} ]; then rm -rf ${DIR}; fi
    mkdir ${DIR}

    sleep 1; updateProgress 1
}

doInstallPackages() {
    printLn "Installing required packages... [tar ]"
    installPackageIfNeed tar
    updateProgress 1

    printLn "Installing required packages... [wget]"
    installPackageIfNeed wget
    updateProgress 1

    printLn "Installing required packages... [uzip]"
    installPackageIfNeed unzip
    updateProgress 1

    printLn "Installing required packages... [java]"
    installJava
    updateProgress 2
}

doInstallImCli() {
    printLn "Install the Codenvy installation manager..."
    installIm
    updateProgress 3
}

doDownloadBinaries() {
    printLn "Downloading Codenvy binaries... "
    updateProgress 3

    executeIMCommand im-download ${ARTIFACT} ${VERSION} 1> progress.tmp &
    for ((;;)); do
        sleep 1

        DOWNLOAD_PROGRESS=`cat progress.tmp | sed -n "2p" | sed 's/.* \([0-9]*%\).*/\1/'`
        if [[ ${DOWNLOAD_PROGRESS} =~ [0-9]*% ]]; then
            printLn "Downloading Codenvy binaries... "${DOWNLOAD_PROGRESS}

            if [[ ${DOWNLOAD_PROGRESS} == "100%" ]]; then
                updateProgress 4
                break
            else
                updateProgress 3
            fi
        fi
    done
    rm progress.tmp

    executeIMCommand im-download --list-local 1> /dev/null
}

updateProgress() {
    CURRENT_STEP=$1
    LAST_STEP=14
    FACTOR=5

    print "Full install ["
    for ((i=1; i<=$CURRENT_STEP*$FACTOR; i++));  do
       echo -n "="
    done
    for ((i=$CURRENT_STEP*$FACTOR+1; i<=$LAST_STEP*$FACTOR; i++));  do
       echo -n " "
    done
    PROGRESS=$(( $CURRENT_STEP*100/$LAST_STEP ))
    echo "] "${PROGRESS}"%"

    END_TIME=`date +%s`
    DURATION=$(( $END_TIME-$START_TIME))
    M=$(( $DURATION/60 ))
    S=$(( $DURATION%60 ))
    printLn "Elapsed time: "${M}"m "${S}"s"

    cursorUp
    cursorUp
    cursorUp
}

doInstallCodenvy() {
    for ((STEP=1; STEP<=9; STEP++));  do
        clearLine

        if [ ${CODENVY_TYPE} == "multi" ]; then
            executeIMCommand im-install --step ${STEP}-${STEP} --force --multi --config ${CONFIG} ${ARTIFACT} ${VERSION}
        else
            executeIMCommand im-install --step ${STEP}-${STEP} --force --config ${CONFIG} ${ARTIFACT} ${VERSION}
        fi

        updateProgress $(( $STEP+4 ))
        sleep 1
    done
}

doInstallCodenvy_() {
    for ((STEP=1; STEP<=9; STEP++));  do
        clearLine

        if [ ${CODENVY_TYPE} == "multi" ]; then
            executeIMCommand im-install --step ${STEP}-${STEP} --force --multi --config ${CONFIG} ${ARTIFACT} ${VERSION} 1> progress.tmp &
        else
            executeIMCommand im-install --step ${STEP}-${STEP} --force --config ${CONFIG} ${ARTIFACT} ${VERSION} 1> progress.tmp &
        fi

        for ((;;)); do
            sleep 1

            PROGRESS=`cat progress.tmp | sed -n "2p" | sed 's/.* \([0-9]*%\).*/\1/'`
            if [[ ${PROGRESS} =~ [0-9]*% ]]; then
                printLn "Downloading Codenvy binaries... "${PROGRESS}

                if [[ ${PROGRESS} == "100%" ]]; then
                    updateProgress $(( $STEP+4 ))
                    break
                else
                    updateProgress $(( $STEP+3 ))
                fi
            fi
        done
        rm progress.tmp

        sleep 1
    done
}

printPostInstallInfo() {
    [ -z ${SYSTEM_ADMIN_NAME} ] && SYSTEM_ADMIN_NAME=`grep admin_ldap_user_name= ${CONFIG} | cut -d '=' -f2`
    [ -z ${SYSTEM_ADMIN_PASSWORD} ] && SYSTEM_ADMIN_PASSWORD=`grep system_ldap_password= ${CONFIG} | cut -d '=' -f2`
    [ -z ${HOST_NAME} ] && HOST_NAME=`grep host[_url]*=.* ${CONFIG} | cut -f2 -d '='`

    printLn ""
    printLn "Codenvy is ready at http://"${HOST_NAME}
    printLn ""
    printLn "Administrator dashboard ready a http://"${HOST_NAME}"/admin"
    printLn "System admin user name : "${SYSTEM_ADMIN_NAME}
    printLn "System admin password  : "${SYSTEM_ADMIN_PASSWORD}
    printLn ""
    printLn "Installation & Troubleshooting Docs: http://docs.codenvy.com/onpremises/installation-${CODENVY_TYPE}-node/#install-troubleshooting"
    printLn "Upgrade & Configuration Docs: http://docs.codenvy.com/onpremises/installation-${CODENVY_TYPE}-node/#upgrades"
}

clear
preconfigureSystem "$@"

printPreInstallInfo_${CODENVY_TYPE}

printLn ""
updateProgress 0

doConfigureSystem
doInstallPackages
doInstallImCli
doDownloadBinaries
doInstallCodenvy

printPostInstallInfo
