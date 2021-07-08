#!/bin/sh

source /etc/profile

KOOLSHARE="koolshare"
ASUS="asus"
NETGEAR="netgear"
LINKSYS="linksys"

title="迅游加速器"
SYSTEM_TYPE=“”
IF_NAME=""
VENDOR=""
MODEL=""
VERSION=""
BASE_PATH=""

logPath="/tmp/xunyou_install.log"

OLD_VERSION=""
OLD_TITLE=""
action=$1

CTRL_PROC="xy-ctrl"
PROXY_PROC="xy-proxy"
UDP_POST_PROC="udp-post"

BACKUP_TAR="/tmp/xunyou/xunyou_bak.tar.gz"
INSTALL_CONFIG_URL=""
INSTALL_CONFIG="/tmp/xunyou/install.json"
INSTALL_BIN="/tmp/xunyou/adaptation_install"

XUNYOU_CHAIN="XUNYOU"
XUNYOUACC_CHAIN="XUNYOUACC"

log()
{
    echo "${1}"
    echo [`date +"%Y-%m-%d %H:%M:%S"`] "${1}" >> ${logPath}
}

remove_install_file(){
    rm -rf /tmp/xunyou > /dev/null 2>&1
}

get_json_value()
{
    local json=${1}
    local key=${2}
    local num=1
    local value=$(echo "${json}" | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'${key}'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p)
    echo ${value}
}

xunyou_post_install_log()
{
    [ ! -e "${BASE_PATH}/xunyou/bin/${UDP_POST_PROC}" ] && return 0
    #
    tmpfile="/tmp/.xy-post.log"
    value=`cat ${BASE_PATH}/xunyou/configs/xunyou-user` >/dev/null 2>&1
    key="userName"
    userName=$(get_json_value $value $key)
    #
    mac=`ip address show ${IF_NAME} | grep link/ether | awk -F ' ' '{print $2}'`
    [ -z "${mac}" ] && return 0
    #
    time=`date +"%Y-%m-%d %H:%M:%S"`
    #
    guid=`echo -n ''${mac}'merlinrouterxunyou2020!@#$' | md5sum | awk -F ' ' '{print $1}'`
    #
    publicIp_json=$(curl https://router.xunyou.com/index.php/Info/getClientIp) >/dev/null 2>&1
    key="ip"
    publicIp=$(get_json_value $publicIp_json $key)
    #
    if [ "$1" == "failed" ]; then
        success=0
    else
        success=1
    fi
    #
    if [ "${action}" == "upgrade" ]; then
        type=7
    else
        type=3
    fi
    data='{"id":1003,"user":"'${userName}'","mac":"'${mac}'","data":{"type":"'${type}'","account":"'${userName}'","model":"'${MODEL}'","guid":"'${guid}'","mac":"'${mac}'","publicIp":"'${publicIp}'","source":0, "success":"'${success}'","reporttime":"'${time}'"}}'
    echo ${data} > ${tmpfile}
    #
    ${BASE_PATH}/xunyou/bin/${UDP_POST_PROC} -d "acceldata.xunyou.com" -p 9240 -f ${tmpfile} >/dev/null 2>&1 &
}

get_install_config_url()
{
    log "VENDOR=${VENDOR}, model=${MODEL}, version=${VERSION}"

    resp_info_json=$(curl -k -X POST -H "Content-Type: application/json" -d '{"alias":"'"${VENDOR}"'","model":"'"${MODEL}"'","version":"'"${VERSION}"'"}' "https://router.xunyou.com/index.php/vendor/get-info") > /dev/null 2>&1
    if [ $? -ne 0 ] ;then
        log "curl get info failed!"
        return 2
    fi

    resp_info_json=`echo ${resp_info_json} | sed "s/https://"`
    #判断网站返回的info信息是否正确
    msg_id="id"
    id_value=$(get_json_value $resp_info_json $msg_id)

    if [ -z "${id_value}" ];then
        log "cannot find the msgid"
        return 3
    fi

    if [ ${id_value} -ne 1 ];then
        log "the msgid is error: $id_value"
        return 1
    fi

    #获取install.json的下载路径
    key="url"
    url_value=$(get_json_value $resp_info_json $key)
    if [ -z "${url_value}" ];then
        log "cannet find the install config file url"
        return 4
    fi

    INSTALL_CONFIG_URL="https:"${url_value}
    INSTALL_CONFIG_URL=$(echo ${INSTALL_CONFIG_URL} | sed 's/\\//g')

    log "get install config file url success!"

    return 0
}

download_install_bin()
{
    rm -f ${INSTALL_CONFIG}

    wget --no-check-certificate -O ${INSTALL_CONFIG} ${INSTALL_CONFIG_URL} > /dev/null 2>&1
    if [ $? -ne 0 ];then
        log "wget install config file failed"
        return 5
    fi

    json=$(sed ':a;N;s/\n//g;ta' ${INSTALL_CONFIG})
    urlString=$(echo $json | awk -F"," '{print $1}' | sed s/\"//g)
    checksumString=$(echo $json | awk -F"," '{print $2}' | sed s/\"//g)

    installUrl=${urlString#*:}
    installChecksum=${checksumString#*:}

    wget --no-check-certificate -O ${INSTALL_BIN} ${installUrl} > /dev/null 2>&1
    if [ $? -ne 0 ];then
        log "wget install bin file failed"
        return 5
    fi

    chmod 777 ${INSTALL_BIN}

    checksum=$(md5sum ${INSTALL_BIN})
    if [ $? -ne 0 ];then
        log "execute md5sum failed"
        return 7
    fi

    installChecksum=$(echo ${installChecksum} | tr [a-z] [A-Z])
    checksum=$(echo ${checksum} | awk '{print $1}' | tr [a-z] [A-Z])
    if [ ${installChecksum} != ${checksum} ]; then
        log "the install bin file's checksum is error!"
        return 8
    fi

    log "download install bin file success."

    return 0
}

set_xunyou_bak()
{
    rm -f ${BACKUP_TAR}

    if [ -e "${BASE_PATH}/xunyou" ]; then
        log "begin to backup xunyou"

        cd ${BASE_PATH}
        tar -czvf ${BACKUP_TAR} xunyou > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            log "backup xunyou failed!"
            return 17
        fi

        if [ ${SYSTEM_TYPE} == ${KOOLSHARE} ];then
            OLD_VERSION=`dbus get xunyou_version`
            OLD_TITLE=`dbus get xunyou_title`
        fi

        log "backup xunyou success"
    else
        log "no need to backup xunyou"
    fi

    return 0
}

restore_xunyou_bak()
{
    if [ -f ${BASE_PATH}/xunyou/uninstall.sh ]; then
        sh ${BASE_PATH}/xunyou/uninstall.sh upgrade > /dev/null 2>&1
    fi

    if [ ! -f ${BACKUP_TAR} ]; then
        return 0
    fi

    log "begin to restore xunyou backup"

    tar -zxvf ${BACKUP_TAR} -C ${BASE_PATH} > /dev/null 2>&1

    if [ ${SYSTEM_TYPE} == ${KOOLSHARE} ];then
        dbus set xunyou_enable=1

        cp -rf ${BASE_PATH}/xunyou/webs/* ${BASE_PATH}/webs/
        cp -rf ${BASE_PATH}/xunyou/res/*  ${BASE_PATH}/res/
        cp -rf ${BASE_PATH}/xunyou/uninstall.sh  ${BASE_PATH}/scripts/uninstall_xunyou.sh

        ln -sf ${BASE_PATH}/xunyou/scripts/xunyou_config.sh ${BASE_PATH}/init.d/S90XunYouAcc.sh
        ln -sf ${BASE_PATH}/xunyou/scripts/xunyou_config.sh ${BASE_PATH}/scripts/xunyou_status.sh

        dbus set xunyou_version="${OLD_VERSION}"
        dbus set xunyou_title="${OLD_TITLE}"
        dbus set softcenter_module_xunyou_install=1
        dbus set softcenter_module_xunyou_name=xunyou
        dbus set softcenter_module_xunyou_version="${OLD_VERSION}"
        dbus set softcenter_module_xunyou_title="${OLD_TITLE}"
        dbus set softcenter_module_xunyou_description="迅游加速器，支持PC和主机加速。"
    elif [ ${SYSTEM_TYPE} == ${ASUS} ];then
        ln -sf ${BASE_PATH}/xunyou/scripts/xunyou_config.sh /etc/init.d/S90XunYouAcc.sh > /dev/null 2>&1
    fi

    rm -f ${BACKUP_TAR}

    sh ${BASE_PATH}/xunyou/scripts/xunyou_config.sh simple

    log "restore xunyou backup success"
}

check_system()
{
    if [ -d "/koolshare" ]; then
        SYSTEM_TYPE="koolshare"
        BASE_PATH="/koolshare"
        IF_NAME="br0"
        VENDOR=$(nvram get wps_mfstring)
        MODEL=$(nvram get productid)
        VERSION=$(nvram get buildno)
    elif [ -d "/jffs" ]; then
        SYSTEM_TYPE="asus"
        BASE_PATH="/jffs"
        IF_NAME="br0"
        VENDOR=$(nvram get wps_mfstring)
        MODEL=$(nvram get productid)
        VERSION=$(nvram get buildno)
    elif [ -d "/var/tmp/misc2" ]; then
        SYSTEM_TYPE="linksys"
        BASE_PATH="/var/tmp/misc2"
        IF_NAME="br0"
        VENDOR=$(nvram kget manufacturer)
        MODEL=$(nvram kget modelNumber)
        VERSION=$(awk -F' ' '{printf $2}' /etc/fwversion)
    elif [ -d "/data" ]; then
        SYSTEM_TYPE="netgear"
        BASE_PATH="/data"
        IF_NAME="br0"
        VENDOR="NETGEAR"
        MODEL=$(cat /module_name)
        VERSION=$(cat /firmware_version)
    else
        log "unknown system type, now exit the installation!"
        return 16
    fi

    return 0
}

uninstall_xunyou()
{
    if [ -f ${BASE_PATH}/xunyou/uninstall.sh ]; then
        sh ${BASE_PATH}/xunyou/uninstall.sh upgrade > /dev/null 2>&1

        log "uninstall xunyou success"
    fi
}
check_running_status()
{
    iptables -t mangle -n -L ${XUNYOU_CHAIN} >/dev/null 2>&1
    if [ $? != 0 ];then
        log "iptables mangle chain ${XUNYOU_CHAIN} does not exist"
        return 1
    fi

    iptables -t mangle -n -L ${XUNYOUACC_CHAIN} >/dev/null 2>&1
    if [ $? != 0 ];then
        log "iptables mangle chain ${XUNYOUACC_CHAIN} does not exist"
        return 1
    fi

    iptables -t mangle -C PREROUTING -i ${IF_NAME} -p udp -j ${XUNYOU_CHAIN} >/dev/null 2>&1
    if [ $? != 0 ]; then
        log "iptables mangle rule does not exist"
        return 1
    fi

    iptables -t nat -n -L ${XUNYOU_CHAIN} >/dev/null 2>&1
    if [ $? != 0 ];then
        log "iptables nat chain ${XUNYOU_CHAIN} does not exist"
        return 1
    fi

    iptables -t nat -n -L ${XUNYOUACC_CHAIN} >/dev/null 2>&1
    if [ $? != 0 ];then
        log "iptables nat chain ${XUNYOUACC_CHAIN} does not exist"
        return 1
    fi

    iptables -t nat -C PREROUTING -i ${IF_NAME} -j ${XUNYOU_CHAIN} >/dev/null 2>&1
    if [ $? != 0 ]; then
        log "iptables nat rule does not exist"
        return 1
    fi

    ctrlPid=`ps | grep -v grep | grep -w ${CTRL_PROC} | awk -F ' ' '{print $1}'`
    if [ -z ${ctrlPid} ]; then
        return 1
    fi

    proxyPid=`ps | grep -v grep | grep -w ${PROXY_PROC} | awk -F ' ' '{print $1}'`
    if [ -z ${proxyPid} ]; then
        return 1
    fi

    return 0
}

rm -f /tmp/xunyou_install.log
log "begin to install the xunyou plugin！"

mkdir -p /tmp/xunyou

check_system
ret=$?
if [ ${ret} -ne 0 ];then
    xunyou_post_install_log failed
    exit ${ret}
fi

set_xunyou_bak
ret=$?
if [ ${ret} -ne 0 ];then
    xunyou_post_install_log failed
    exit ${ret}
fi

get_install_config_url
ret=$?
if [ ${ret} -ne 0 ];then
    log "get install config file url failed!"
    restore_xunyou_bak
    remove_install_file
    xunyou_post_install_log failed
    exit ${ret}
fi

download_install_bin
ret=$?
if [ ${ret} -ne  0 ];then
    log "download xunyou install bin file failed!"
    restore_xunyou_bak
    remove_install_file
    xunyou_post_install_log failed
    exit ${ret}
fi

#执行卸载操作
uninstall_xunyou

log "begin to install xunyou"

/tmp/xunyou/adaptation_install ${SYSTEM_TYPE} >> ${logPath}
ret=$?
if [ ${ret} -ne 0 ]; then
    log "install xunyou failed!"
    restore_xunyou_bak
    remove_install_file
    xunyou_post_install_log failed
    exit ${ret}
fi

sh ${BASE_PATH}/xunyou/scripts/xunyou_config.sh app

sleep 3

check_running_status
if [ $? -ne 0 ]; then
    log "check xunyou running status failed!!"
    restore_xunyou_bak
    remove_install_file
    xunyou_post_install_log failed
    exit ${ret}
fi

xunyou_post_install_log success
log "install xunyou success!"

remove_install_file

exit 0
