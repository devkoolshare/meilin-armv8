#!/bin/sh

[ -f /etc/profile ] && . /etc/profile >/dev/null

ACTION=$1

SYSTEM_TYPE=""
PLUGIN_DIR=""
IF_NAME=""
VENDOR=""
MODEL=""
VERSION=""
PLUGIN_VERSION=""
IF_MAC=""
PLUGIN_MOUNT_DIR=“”
PLUGIN_CONF=""
USER_NAME=""

WORK_DIR="/tmp/xunyou"
INSTALL_DIR="/tmp/.xunyou_install"
BACKUP_DIR="${INSTALL_DIR}/bak"
DOWNLOAD_DIR="${INSTALL_DIR}/download"

PLUGIN_CONF="${WORK_DIR}/conf/plugin.conf"
INSTALL_JSON="${INSTALL_DIR}/install.json"
CORE_TAR="${DOWNLOAD_DIR}/xunyou.tar.gz"
KO_TAR="${DOWNLOAD_DIR}/ko.tar.gz"

OLD_VERSION=""
OLD_TITLE=""

CTRL_PROC="xunyou_ctrl"
PROXY_PROC="xunyou_proxy"
IPSET_PROC="xunyou_ipset"
POST_PROC="xunyou_post"

XUNYOU_CHAIN="XUNYOU"
XUNYOU_ACC_CHAIN="XUNYOU_ACC"

INSTALL_LOG="/tmp/.xunyou_install.log"

PUBLIC_IP=""

#返回码说明
#RET_OK=0
#RET_UNKOWN_SYSTEM_TYPE=1
#RET_LAN_MAC_NOT_FOUND=2
#RET_DOWNLOAD_FAILED=3
#RET_MD5_MISMATCH=4
#RET_PARSE_FAILED=5
#RET_BACKUP_FAILED=6
#RET_SPACE_NOT_ENOUGH=7
#RET_INSTALL_FAILED=8
#RET_START_FAILED=9

get_json_value()
{
    local json=${1}
    local key=${2}
    local line=`echo ${json} | tr -d "\n " | awk -F"[][}{,]" '{for(i=1;i<=NF;i++) {if($i~/^"'${key}'":/) print $i}}' | tr -d '"' | sed -n 1p`
    local value=${line#*:}
    echo ${value}
}

log()
{
    echo "${1}"
    echo [`date +"%Y-%m-%d %H:%M:%S"`] "${1}" >> ${INSTALL_LOG}
}

post_log()
{
    [ ! -e "${WORK_DIR}/xunyou/bin/${POST_PROC}" ] && return 0

    local tmp_file="/tmp/.xy-post.log"
    local time=`date +"%Y-%m-%d %H:%M:%S"`
    local guid=`echo -n ''${IF_MAC}'merlinrouterxunyou2020!@#$' | md5sum | awk -F ' ' '{print $1}'`

    local success
    if [ "$1" == "failed" ]; then
        success=0
    else
        success=1
    fi

    local type
    if [ "${ACTION}" == "upgrade" ]; then
        type=7
    else
        type=3
    fi

    local data='{"id":1003,"user":"${USER_NAME}","mac":"'${IF_MAC}'","data":{"type":"'${type}'","account":"${USER_NAME}","model":"'${MODEL}'","guid":"'${guid}'","mac":"'${IF_MAC}'","publicIp":"'${PUBLIC_IP}'","source":0, "success":"'${success}'","reporttime":"'${time}'"}}'

    echo ${data} > ${tmp_file}

    ${WORK_DIR}/bin/${POST_PROC} -d "acceldata.xunyou.com" -p 9240 -f ${tmp_file} >/dev/null 2>&1

    rm -f ${tmp_file}
}

download()
{
    local url="$1"
    local file="$2"
    local md5="$3"

    curl -L -s -k "$url" -o "${file}" >/dev/null 2>&1 || \
        wget -q --no-check-certificate "$url" -O "${file}" >/dev/null 2>&1 || \
        curl -s -k "$url" -o "${file}" >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        log "Failed: curl (-L) -s -k ${url} -o ${file} ||
            wget -q --no-check-certificate $url -O ${file}!"
        return 3
    fi

    if [ -n "$md5" ]; then
        local download_md5=`md5sum ${file}`
        if [ $? -ne 0 ]; then
            log "Execute md5sum failed!"
            return 4
        fi

        download_md5=`echo ${download_md5} | awk '{print $1}' | tr [a-z] [A-Z]`

        if [ "$download_md5" != "$md5" ]; then
            log "The checksum of ${file} does not match!"
            return 4
        fi
    fi

    return 0
}

install_init()
{
    local library_path=`echo ${LD_LIBRARY_PATH} | sed "s#${WORK_DIR}/lib:##g"`
    export LD_LIBRARY_PATH=${library_path}

    rm -f ${INSTALL_LOG}

    log "Begin to install plugin."

    mkdir -p ${INSTALL_DIR}
    mkdir -p ${DOWNLOAD_DIR}

    if [ -d "/koolshare" ]; then
        SYSTEM_TYPE="merlin"
        PLUGIN_DIR="/koolshare/xunyou"
        PLUGIN_MOUNT_DIR="/jffs"
        IF_NAME="br0"
        VENDOR=`nvram get wps_mfstring`
        MODEL=`nvram get productid`
        VERSION=`nvram get buildno`
    elif [ -d "/jffs" ]; then
        SYSTEM_TYPE="asus"
        PLUGIN_DIR="/jffs/xunyou"
        PLUGIN_MOUNT_DIR="/jffs"
        IF_NAME="br0"
        VENDOR=`nvram get wps_mfstring`
        MODEL=`nvram get productid`
        VERSION=`nvram get buildno`
    elif [ -d "/var/tmp/misc2" ]; then
        SYSTEM_TYPE="linksys"
        PLUGIN_DIR="/var/tmp/misc2/xunyou"
        PLUGIN_MOUNT_DIR="/var/tmp/misc2"
        IF_NAME="br0"
        VENDOR=`nvram kget manufacturer`
        MODEL=`nvram kget modelNumber`
        VERSION=`awk -F' ' '{printf $2}' /etc/fwversion`
    elif [ -d "/etc/oray" ]; then
        SYSTEM_TYPE="oray"
        PLUGIN_DIR="/xunyou"
        PLUGIN_MOUNT_DIR="/"
        IF_NAME="br-lan"
        VENDOR=`cat /etc/device_info | grep DEVICE_MANUFACTURER |awk -F '"' '{print $2}'`
        MODEL=`cat /etc/device_info | grep DEVICE_REVISION |awk -F '"' '{print $2}'`
        VERSION=`cat /etc/openwrt_version`
    else
        local hostname=`uname -n`
        if [ "${hostname}" == "XiaoQiang" ]; then
            SYSTEM_TYPE="xiaomi"
            PLUGIN_DIR="/userdisk/appdata/2882303761520108685"
            PLUGIN_MOUNT_DIR="/data"
            IF_NAME="br-lan"
            VENDOR="XIAOMI"
            MODEL=`uci get /usr/share/xiaoqiang/xiaoqiang_version.version.HARDWARE`
            VERSION=`uci get /usr/share/xiaoqiang/xiaoqiang_version.version.ROM`
        elif [ "${hostname}" == "ARS2" ]; then
            SYSTEM_TYPE="koolshare"
            PLUGIN_DIR="/xunyou"
            PLUGIN_MOUNT_DIR="/"
            IF_NAME="eth1"
            VENDOR="KOOLSHARE"
            MODEL="ARS2"
            VERSION=`cat /etc/openwrt_version`
        else
            curl -s http://127.0.0.1/currentsetting.htm | tr '\r' '\n' > /tmp/.xunyou_tmp
            local model=`awk -F"=" '$1=="Model" {print $2}' /tmp/.xunyou_tmp`
            local version=`awk -F"=" '$1=="Firmware" {print $2}' /tmp/.xunyou_tmp`

            rm -f /tmp/.xunyou_tmp

            if [ -n ${model} -a -n ${version} ]; then
                SYSTEM_TYPE="netgear"
                PLUGIN_DIR="/data/xunyou"
                PLUGIN_MOUNT_DIR="/data"
                IF_NAME="br0"
                VENDOR="NETGEAR"
                MODEL="${model}"
                VERSION="${version#V*}"
            else
                log "Unknown system type!"
                return 1
            fi
        fi
    fi

    IF_MAC=`ip address show ${IF_NAME} | grep link/ether | awk -F ' ' '{print $2}' | tr '[A-Z]' '[a-z]'`
    if [ -z "${IF_MAC}" ]; then
        log "Can't find the lan mac!"
        return 2
    fi

    local json
    local key

    if [ -f ${PLUGIN_DIR}/.cache/bind_info ]; then
        json=`cat ${PLUGIN_DIR}/.cache/bind_info`

        key="userName"
        USER_NAME=`get_json_value "${json}" "${key}"`
    fi

    json=`curl -s http://router.xunyou.com/index.php/Info/getClientIp` >/dev/null 2>&1
    if [ -n "${json}" ]; then
        key="ip"
        PUBLIC_IP=`get_json_value "${json}" "${key}"`
    fi

    log "SYSTEM_TYPE=${SYSTEM_TYPE}"

    return 0
}

install_exit(){
    rm -rf ${INSTALL_DIR} > /dev/null 2>&1

    log "End to install plugin."
}

download_install_json()
{
    log "vendor=${VENDOR}, model=${MODEL}, version=${VERSION}"

    local resp_info_json=`curl -s -k -X POST -H "Content-Type: application/json" -d '{"alias":"'"${VENDOR}"'","model":"'"${MODEL}"'","version":"'"${VERSION}"'"}' "https://router.xunyou.com/index.php/vendor/get-info"` > /dev/null 2>&1
    if [ $? -ne 0 ] ;then
        log "Curl get info failed!"
        return 3
    fi

    #判断网站返回的info信息是否正确
    local key="id"
    local value=`get_json_value "${resp_info_json}" "${key}"`

    if [ -z "${value}" ];then
        log "Can't find id!"
        return 5
    fi

    if [ ${value} -ne 1 ];then
        log "The id is error: ${value}!"
        return 5
    fi

    #获取install.json的下载路径
    key="url"
    value=`get_json_value "${resp_info_json}" "${key}"`
    if [ -z "${value}" ];then
        log "Can't find the install json's url!"
        return 5
    fi

    local url=`echo ${value} | sed 's/\\\\//g'`

    download ${url} ${INSTALL_JSON}
    ret=$?
    if [ ${ret} -ne 0 ]; then
        return ${ret}
    fi

    log "Download install json file success."

    #调整install.json文件的排版格式，便于后续解析
    sed -e 's/,/\n,\n/g' -e 's/{/\n{\n/g' -e 's/}/\n}\n/g' -e 's/\[/\n\[\n/g' -e 's/\]/\n\]\n/g' -e 's/[ \t]//g' -i ${INSTALL_JSON}
    sed '/^$/d' -i ${INSTALL_JSON}

    return 0
}

download_plugin()
{
    local state
    local core_md5
    local core_url
    local lib_name
    local lib_keyfile
    local lib_md5
    local lib_url
    local lib_file
    local kernel
    local kernel_md5
    local kernel_url
    local libcurl_md5
    local libcurl_url
    local libcurl_file
    local libevent_openssl_md5
    local libevent_openssl_url
    local libevent_openssl_file
    local download_related_lib=0

    local kernel_release=`uname -r`

    while read line;
    do
        if [ "${line}" == '"name":"common"' ]; then
            state="core"
            continue
        elif [ "${line}" == '"name":"libs"' ]; then
            state="libs"
            continue
        elif [ "${line}" == '"name":"kos"' ]; then
            state="kos"
            continue
        fi

        if [ "${state}" == "core" ]; then
            if [ "${line%%:*}" == '"checksum"' ]; then
                core_md5=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"url"' ]; then
                core_url=`echo ${line#*:} | tr -d '"'`
            fi

            if [ -n "${core_md5}" -a -n "${core_url}" ]; then
                download ${core_url} ${CORE_TAR} ${core_md5}
                ret=$?
                if [ ${ret} -ne 0 ]; then
                    return ${ret}
                fi

                core_md5=""
                core_url=""
            fi
        elif [ "${state}" == "libs" ]; then
            if [ "${line%%:*}" == '"name"' ]; then
                lib_name=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"keyfile"' ]; then
                lib_keyfile=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"checksum"' ]; then
                lib_md5=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"url"' ]; then
                lib_url=`echo ${line#*:} | tr -d '"'`
            fi

            if [ -n "${lib_name}" -a -n "${lib_keyfile}" -a -n "${lib_md5}" -a -n "${lib_url}" ]; then
                lib_file="${DOWNLOAD_DIR}/${lib_name}.tar.gz"

                local lib_path=`find /lib/ /usr/lib/ -name ${lib_keyfile}`
                if [ -z "${lib_path}" ]; then
                    download ${lib_url} ${lib_file} ${lib_md5}
                    ret=$?
                    if [ ${ret} -ne 0 ]; then
                        return ${ret}
                    fi

                    if [ "${lib_name}" == "libssl" ]; then
                        download_related_lib=1
                    fi
                else
                    if [ "${lib_name}" == "libcurl" ]; then
                        libcurl_md5="${lib_md5}"
                        libcurl_url="${lib_url}"
                        libcurl_file="${lib_file}"
                    elif [ "${lib_name}" == "libevent_openssl" ]; then
                        libevent_openssl_md5="${lib_md5}"
                        libevent_openssl_url="${lib_url}"
                        libevent_openssl_file="${lib_file}"
                    fi
                fi

                lib_name=""
                lib_keyfile=""
                lib_md5=""
                lib_url=""
                lib_file=""
            fi
        elif [ "${state}" == "kos" ]; then
            if [ "${line%%:*}" == '"kernel"' ]; then
                kernel=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"checksum"' ]; then
                kernel_md5=`echo ${line#*:} | tr -d '"'`
            elif [ "${line%%:*}" == '"url"' ]; then
                kernel_url=`echo ${line#*:} | tr -d '"'`
            fi

            if [ -n "${kernel}" -a -n "${kernel_md5}" -a -n "${kernel_url}" ]; then
                if [ "${kernel_release}" == "${kernel}" ]; then
                    download ${kernel_url} ${KO_TAR} ${kernel_md5}
                    ret=$?
                    if [ ${ret} -ne 0 ]; then
                        return ${ret}
                    fi
                fi

                kernel=""
                kernel_md5=""
                kernel_url=""
            fi
        fi
    done < ${INSTALL_JSON}

    # 因为libcurl和libevent_openssl依赖于libssl编译出来的，为了版本匹配，必须配套使用。所以如果需要下载libssl，则也需要下载libcurl和libevent_openssl。
    if [ ${download_related_lib} -eq 1 ]; then
        if [ -n "${libcurl_md5}" -a -n "${libcurl_url}" -a -n "${libcurl_file}" ]; then
            download ${libcurl_url} ${libcurl_file} ${libcurl_md5}
            ret=$?
            if [ ${ret} -ne 0 ]; then
                return ${ret}
            fi
        fi

        if [ -n "${libevent_openssl_md5}" -a -n "${libevent_openssl_url}" -a -n "${libevent_openssl_file}" ]; then
            download ${libevent_openssl_url} ${libevent_openssl_file} ${libevent_openssl_md5}
            ret=$?
            if [ ${ret} -ne 0 ]; then
                return ${ret}
            fi
        fi
    fi

    log "Download plugin success."

    return 0
}

uninstall_plugin()
{
    if [ -f ${PLUGIN_DIR}/uninstall.sh ]; then
        sh ${PLUGIN_DIR}/uninstall.sh upgrade > /dev/null 2>&1
    elif [ -f ${PLUGIN_DIR}/xunyou_uninstall.sh ]; then
        sh ${PLUGIN_DIR}/xunyou_uninstall.sh silent > /dev/null 2>&1
    else
        rm -rf ${WORK_DIR} ${PLUGIN_DIR}
    fi

    log "Uninstall plugin success."

    return 0
}

install_plugin()
{
    #解压缩插件包到INSTALL目录，从中拷贝version、xunyou_daemon.sh、xunyou_firewall.sh、xunyou_uninstall.sh和xunyou_post文件到DOWNLOAD目录
    tar -C ${INSTALL_DIR} -xzf ${CORE_TAR}

    cp -af ${INSTALL_DIR}/xunyou/version ${DOWNLOAD_DIR}
    cp -af ${INSTALL_DIR}/xunyou/scripts/xunyou_daemon.sh ${DOWNLOAD_DIR}
    cp -af ${INSTALL_DIR}/xunyou/scripts/xunyou_firewall.sh ${DOWNLOAD_DIR}/firewall.sh
    cp -af ${INSTALL_DIR}/xunyou/scripts/xunyou_uninstall.sh ${DOWNLOAD_DIR}

    #为兼容老版本，拷贝xunyou_daemon.sh到xunyou_config.sh
    mkdir -p ${DOWNLOAD_DIR}/scripts
    cp -af ${DOWNLOAD_DIR}/xunyou_daemon.sh ${DOWNLOAD_DIR}/scripts/xunyou_config.sh

    #如果BACKUP目录有缓存文件，则拷贝到DOWNLOAD目录
    if [ -d ${BACKUP_DIR}/.cache ]; then
        cp -arf ${BACKUP_DIR}/.cache ${DOWNLOAD_DIR}
    fi

    #检查插件目录所在分区是否有足够的空间
    local require=`du -sk ${DOWNLOAD_DIR} | awk -F" " '{print $1}'`
    local available=`df -k | awk -F" " '$6=="'${PLUGIN_MOUNT_DIR}'" {print $4}' | sed -n 1p`

    #预留2k的空间保存daemon日志
    let "require = ${require} + 2"
    if [ ${require} -ge ${available} ]; then
        log "There is not enough space to install plugin!"
        return 7
    fi

    #将DOWNLOAD_DIR移动到PLUGIN_DIR
    cp -arf ${DOWNLOAD_DIR} ${PLUGIN_DIR}
    if [ $? -ne 0 ]; then
        log "Failed to install plugin to ${PLUGIN_DIR}!"
        return 8
    fi

    #如果是Koolshare梅林固件需要做特殊处理
    if [ "${SYSTEM_TYPE}" == "merlin" ]; then
        dbus set xunyou_enable=1
        cp -rf ${INSTALL_DIR}/xunyou/webs/Module_xunyou.asp /koolshare/webs/
        cp -rf ${INSTALL_DIR}/xunyou/res/icon-xunyou.png /koolshare/res/

        ln -sf ${PLUGIN_DIR}/xunyou_uninstall.sh /koolshare/scripts/uninstall_xunyou.sh
        ln -sf ${PLUGIN_DIR}/xunyou_daemon.sh /koolshare/init.d/S90XunYouAcc.sh
        ln -sf ${PLUGIN_DIR}/xunyou_daemon.sh /koolshare/scripts/xunyou_status.sh

        local plugin_version=`cat ${PLUGIN_DIR}/version`

        dbus set xunyou_version=${plugin_version}
        dbus set xunyou_title="迅游加速器"
        dbus set softcenter_module_xunyou_install=1
        dbus set softcenter_module_xunyou_name=xunyou
        dbus set softcenter_module_xunyou_version=${plugin_version}
        dbus set softcenter_module_xunyou_title="迅游加速器"
        dbus set softcenter_module_xunyou_description="迅游加速器，支持PC和主机加速。"
    fi

    log "Install plugin success."

    return 0
}

start_plugin()
{
    sh ${PLUGIN_DIR}/xunyou_daemon.sh simple >> ${INSTALL_LOG}
    if [ $? -ne 0 ]; then
        log "Failed to start plugin."
        return 9
    fi

    sleep 1

    sh ${PLUGIN_DIR}/xunyou_daemon.sh status >> ${INSTALL_LOG}
    if [ $? -ne 0 ]; then
        log "Plugin's running status is not ok."
        return 9
    fi

    return 0
}

set_xunyou_bak()
{
    if [ -d "${PLUGIN_DIR}" ]; then
        rm -rf ${BACKUP_DIR}

        cp -arf ${PLUGIN_DIR} ${BACKUP_DIR}
        if [ $? -ne 0 ]; then
            log "Failed to backup plugin!"
            return 6
        fi

        if [ "${SYSTEM_TYPE}" == "merlin" ];then
            OLD_VERSION=`dbus get xunyou_version`
            OLD_TITLE=`dbus get xunyou_title`
        fi

        log "Backup plugin success."
    else
        log "No need to backup plugin."
    fi

    return 0
}

restore_xunyou_bak()
{
    uninstall_plugin upgrade

    if [ -d "${BACKUP_DIR}" ]; then
        rm -rf ${PLUGIN_DIR}
        cp -arf ${BACKUP_DIR} ${PLUGIN_DIR}

        if [ "${SYSTEM_TYPE}" == "merlin" ];then
            dbus set xunyou_enable=1

            cp -rf ${PLUGIN_DIR}/webs/* /koolshare/webs/
            cp -rf ${PLUGIN_DIR}/res/*  /koolshare/res/

            if [ -f ${PLUGIN_DIR}/xunyou_uninstall.sh ]; then
                cp -rf ${PLUGIN_DIR}/xunyou_uninstall.sh /koolshare/scripts/uninstall_xunyou.sh
            else
                cp -rf ${PLUGIN_DIR}/uninstall.sh /koolshare/scripts/uninstall_xunyou.sh
            fi

            if [ -f ${PLUGIN_DIR}/xunyou_daemon.sh ]; then
                ln -sf ${PLUGIN_DIR}/xunyou_daemon.sh /koolshare/init.d/S90XunYouAcc.sh
                ln -sf ${PLUGIN_DIR}/xunyou_daemon.sh /koolshare/scripts/xunyou_status.sh
            else
                ln -sf ${PLUGIN_DIR}/scripts/xunyou_config.sh /koolshare/init.d/S90XunYouAcc.sh
                ln -sf ${PLUGIN_DIR}/scripts/xunyou_config.sh /koolshare/scripts/xunyou_status.sh
            fi

            dbus set xunyou_version="${OLD_VERSION}"
            dbus set xunyou_title="${OLD_TITLE}"
            dbus set softcenter_module_xunyou_install=1
            dbus set softcenter_module_xunyou_name=xunyou
            dbus set softcenter_module_xunyou_version="${OLD_VERSION}"
            dbus set softcenter_module_xunyou_title="${OLD_TITLE}"
            dbus set softcenter_module_xunyou_description="迅游加速器，支持PC和主机加速。"
        fi

        rm -rf ${BACKUP_DIR}

        if [ -f ${PLUGIN_DIR}/xunyou_daemon.sh ]; then
            sh ${PLUGIN_DIR}/xunyou_daemon.sh simple
        else
            sh ${PLUGIN_DIR}/scripts/xunyou_config.sh simple
        fi

        log "Restore xunyou backup success."
    fi

    return 0
}

install_init
ret=$?
if [ ${ret} -ne 0 ];then
    install_exit
    exit ${ret}
fi

download_install_json
ret=$?
if [ ${ret} -ne 0 ];then
    install_exit
    exit ${ret}
fi

download_plugin
ret=$?
if [ ${ret} -ne  0 ];then
    install_exit
    exit ${ret}
fi

#安装之前先备份
set_xunyou_bak
ret=$?
if [ ${ret} -ne 0 ];then
    install_exit
    exit ${ret}
fi

#执行卸载操作
uninstall_plugin
ret=$?
if [ ${ret} -ne 0 ];then
    restore_xunyou_bak
    install_exit
    exit ${ret}
fi

#执行安装操作
install_plugin
ret=$?
if [ ${ret} -ne 0 ];then
    restore_xunyou_bak
    install_exit
    exit ${ret}
fi

#启动插件
start_plugin
ret=$?
if [ ${ret} -ne 0 ]; then
    restore_xunyou_bak
    install_exit
    exit ${ret}
fi

post_log success

log "Install and start plugin success!"

install_exit
