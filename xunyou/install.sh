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
PLUGIN_MOUNT_DIR=""
PLUGIN_CONF=""
PLUGIN_VERSION=""
HARDWARE_TYPE=""
CPU_TYPE=""

WORK_DIR="/tmp/xunyou"
INSTALL_DIR="/tmp/.xunyou_install"
BACKUP_DIR="${INSTALL_DIR}/bak"
DOWNLOAD_DIR="${INSTALL_DIR}/download"

PLUGIN_CONF="${WORK_DIR}/conf/plugin.conf"
INSTALL_JSON="${INSTALL_DIR}/install.json"
DEV_INFO="${INSTALL_DIR}/dev-info"
CORE_TAR="${DOWNLOAD_DIR}/xunyou.tar.gz"
KO_TAR="${DOWNLOAD_DIR}/ko.tar.gz"

OLD_VERSION=""
OLD_TITLE=""

INSTALL_LOG="/tmp/.xunyou_install.log"

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

post_es_log()
{
    #local time=`date +"%Y-%m-%d %H:%M:%S"`

    if [ -f ${PLUGIN_DIR}/version ]; then
        PLUGIN_VERSION=`cat ${PLUGIN_DIR}/version`
    fi

    local guid=`echo -n ''${IF_MAC}'merlinrouterxunyou2020!@#$' | md5sum | awk -F ' ' '{print $1}'`
    curl -s -m 20 --connect-timeout 10 --retry 3 -k -X POST -d "{\"uid\":\"0\",\"cookie_id\":\"${guid}\"}" --header "Content-type: application/json" https://ms.xunyou.com/api/statistics/public-properties >/dev/null 2>&1
    if [ $? -ne 0 ] ;then
        log "Curl post es public failed!"
    fi

    if [ "$2" == "fail" ]; then
        local error_code="$3"
    else
        local error_code="N/A"
    fi

    local device_id="${guid}"

    if [ "$1" == "install" ]; then
        event_id="r_install"
        curl -s -m 20 --connect-timeout 10 --retry 3 -k -X POST -d "{\"uid\":\"0\", \"cookie_id\": \"${guid}\", \"device_vendors\":\"${VENDOR}\", \"device_model\":\"${MODEL}\", \"device_version\":\"${VERSION}\", \"device_type\":4, \"device_id\":\"${device_id}\", \"version_id\":\"${PLUGIN_VERSION}\", \"x_event_id\":\"${event_id}\", \"x_feature\":\"$2\", \"x_content\":\"${error_code}\", \"hardware_type\":\"${HARDWARE_TYPE}\", \"cpu_type\":\"${CPU_TYPE}\", \"system_type\":\"${SYSTEM_TYPE}\", \"lan_mac\":\"${IF_MAC}\"}" --header "Content-type: application/json" https://ms.xunyou.com/api/statistics/event >/dev/null 2>&1
        if [ $? -ne 0 ] ;then
            log "Curl post es public failed!"
        fi
    elif [ "$1" == "install_start" ]; then
        curl -s -m 20 --connect-timeout 10 --retry 3 -k -X POST -d "{\"uid\":\"0\", \"cookie_id\": \"${guid}\", \"device_vendors\":\"${VENDOR}\", \"device_model\":\"${MODEL}\", \"device_version\":\"${VERSION}\", \"device_type\":4, \"device_id\":\"${device_id}\", \"version_id\":\"${PLUGIN_VERSION}\", \"x_event_id\":\"r_launch_after_install\", \"x_feature\":\"$2\", \"x_content\":\"${error_code}\", \"hardware_type\":\"${HARDWARE_TYPE}\", \"cpu_type\":\"${CPU_TYPE}\", \"system_type\":\"${SYSTEM_TYPE}\", \"lan_mac\":\"${IF_MAC}\"}" --header "Content-type: application/json" https://ms.xunyou.com/api/statistics/event >/dev/null 2>&1
        if [ $? -ne 0 ] ;then
            log "Curl post es public failed!"
        fi
    elif [ "$1" == "restore_backup" ]; then
        curl -s -m 20 --connect-timeout 10 --retry 3 -k -X POST -d "{\"uid\":\"0\", \"cookie_id\": \"${guid}\", \"device_vendors\":\"${VENDOR}\", \"device_model\":\"${MODEL}\", \"device_version\":\"${VERSION}\", \"device_type\":4, \"device_id\":\"${device_id}\", \"version_id\":\"${PLUGIN_VERSION}\", \"x_event_id\":\"r_restore_backup\", \"x_feature\":\"$2\", \"x_content\":\"${error_code}\", \"hardware_type\":\"${HARDWARE_TYPE}\", \"cpu_type\":\"${CPU_TYPE}\", \"system_type\":\"${SYSTEM_TYPE}\", \"lan_mac\":\"${IF_MAC}\"}" --header "Content-type: application/json" https://ms.xunyou.com/api/statistics/event >/dev/null 2>&1
        if [ $? -ne 0 ] ;then
            log "Curl post es public failed!"
        fi
    elif [ "$1" == "backup_start" ]; then
        curl -s -m 20 --connect-timeout 10 --retry 3 -k -X POST -d "{\"uid\":\"0\", \"cookie_id\": \"${guid}\", \"device_vendors\":\"${VENDOR}\", \"device_model\":\"${MODEL}\", \"device_version\":\"${VERSION}\", \"device_type\":4, \"device_id\":\"${device_id}\", \"version_id\":\"${PLUGIN_VERSION}\", \"x_event_id\":\"r_launch_backup\", \"x_feature\":\"$2\", \"x_content\":\"${error_code}\", \"hardware_type\":\"${HARDWARE_TYPE}\", \"cpu_type\":\"${CPU_TYPE}\", \"system_type\":\"${SYSTEM_TYPE}\", \"lan_mac\":\"${IF_MAC}\"}" --header "Content-type: application/json" https://ms.xunyou.com/api/statistics/event >/dev/null 2>&1
        if [ $? -ne 0 ] ;then
            log "Curl post es public failed!"
        fi
    else
        return 0
    fi
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

    if [ -n "${md5}" ]; then
        local download_md5=`md5sum ${file} | awk '{print $1}'`
        if [ $? -ne 0 ]; then
            log "Execute md5sum failed!"
            return 4
        fi

        download_md5=`echo ${download_md5} | tr '[A-Z]' '[a-z]'`
        local expected_md5=`echo ${md5} | tr '[A-Z]' '[a-z]'`

        if [ "${download_md5}" != "${expected_md5}" ]; then
            log "The checksum of ${file} does not match!"
            return 11
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
        if [ -z "$VERSION" ]; then
            VERSION="386"
        fi
    elif [ -d "/jffs" ]; then
        SYSTEM_TYPE="asus"
        PLUGIN_DIR="/jffs/xunyou"
        PLUGIN_MOUNT_DIR="/jffs"
        IF_NAME="br0"
        VENDOR=`nvram get wps_mfstring`
        MODEL=`nvram get productid`
        VERSION=`nvram get buildno`
        if [ -z "$VERSION" ]; then
            VERSION="386"
        fi
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
        VENDOR=`awk -F '=' '$1=="DEVICE_MANUFACTURER" {print $2}' /etc/device_info  | tr -d \'\"`
        MODEL=`awk -F '=' '$1=="DEVICE_REVISION" {print $2}' /etc/device_info  | tr -d \'\"`
        VERSION=`cat /etc/openwrt_version`
    else
        local hostname=`uname -n`
        if [ "${hostname}" == "XiaoQiang" ]; then
            SYSTEM_TYPE="xiaomi"
            PLUGIN_DIR="/userdisk/appdata/2882303761520108685"
            PLUGIN_MOUNT_DIR="/userdisk"
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
            if [ ! -f /tmp/.xunyou_tmp ]; then
                log "Failed: curl -s --connect-timeout 3 --retry 3 http://127.0.0.1/currentsetting.htm"
                return 1
            fi

            local model=`awk -F"=" '$1=="Model" {print $2}' /tmp/.xunyou_tmp`
            local version=`awk -F"=" '$1=="Firmware" {print $2}' /tmp/.xunyou_tmp`

            rm -f /tmp/.xunyou_tmp

            if [ -n ${model} -a -n ${version} ]; then
                SYSTEM_TYPE="netgear"
                PLUGIN_MOUNT_DIR="/data"
                IF_NAME="br0"
                VENDOR="NETGEAR"
                MODEL="${model}"
                VERSION="${version#V*}"
                if [ ${MODEL:0:6} == "RAX120" ]; then
                    PLUGIN_DIR="/tmp/data/xunyou"
                else
                    PLUGIN_DIR="/data/xunyou"
                fi
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

    if [ -f ${PLUGIN_DIR}/version ]; then
        PLUGIN_VERSION=`cat ${PLUGIN_DIR}/version`
    fi

    log "SYSTEM_TYPE=${SYSTEM_TYPE}"
    
    HARDWARE_TYPE=$(uname -m)
    if [ "${SYSTEM_TYPE}" == "merlin"  -o "${SYSTEM_TYPE}" == "asus" ]; then
        CPU_TYPE=$(cat /proc/cpuinfo | grep "CPU architecture" | cut -d' ' -f3 | head -n1)
    fi

    return 0
}

install_exit(){
    rm -rf ${INSTALL_DIR} > /dev/null 2>&1

    log "End to install plugin."
}

download_install_json()
{
    log "vendor=${VENDOR}, model=${MODEL}, version=${VERSION}"
    local url

    curl -L -s -k -X POST -H Content-Type: application/json -d '{"alias":"'"${VENDOR}"'","model":"'"${MODEL}"'","version":"'"${VERSION}"'"}' https://router.xunyou.com/index.php/vendor/get-info > ${DEV_INFO} || \
        wget -qO- --no-check-certificate --post-data '{"alias":"'"${VENDOR}"'","model":"'"${MODEL}"'","version":"'"${VERSION}"'"}' https://router.xunyou.com/index.php/vendor/get-info -O ${DEV_INFO} >/dev/null 2>&1  || \
        curl -s -k -X POST -H Content-Type: application/json -d '{"alias":"'"${VENDOR}"'","model":"'"${MODEL}"'","version":"'"${VERSION}"'"}' https://router.xunyou.com/index.php/vendor/get-info > ${DEV_INFO}

    if [ $? -ne 0 ]; then
        log "get dev info failed!"
        return 3
    fi
    
    local resp_info_json=`cat ${DEV_INFO}`
  
    #判断网站返回的info信息是否正确
    local key="id"
    local value=`get_json_value "${resp_info_json}" "${key}"`

    if [ -z "${value}" ];then
        log "Can't find id!"
        return 5
    fi

    if [ ${value} -ne 1 ];then
            if [ "${SYSTEM_TYPE}" == "merlin"  -o "${SYSTEM_TYPE}" == "asus" ]; then
                if [ "${CPU_TYPE}" == "7" ];then
                    url="https://partnerdownload.xunyou.com/routeplugin/merlin/arm-7/386/install.json"
                elif [ "${CPU_TYPE}" == "8" ];then
                    url="https://partnerdownload.xunyou.com/routeplugin/merlin/arm-8/386/install.json"
                else
                    log "decive type not arm7/arm8"
                    return 1
                fi
            else
                log "The id is error: ${value}!"
                return 5
            fi
    else
        #获取install.json的下载路径
        key="url"
        value=`get_json_value "${resp_info_json}" "${key}"`
        if [ -z "${value}" ];then
            log "Can't find the install json's url!"
            return 5
        fi

        url=`echo ${value} | sed 's/\\\\//g'`
    fi

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
    local libevent_openssl_md5
    local libevent_openssl_url
    local libevent_openssl_file
    local download_related_lib=0

    local kernel_release=`uname -r`

    while read line;
    do
        line=`echo ${line} | tr -d ','`

        if [ "${line}" == '"name":"core"' ]; then
            state="core"
            continue
        elif [ "${line}" == '"name":"common"' ]; then
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
                    if [ "${lib_name}" == "libevent_openssl" ]; then
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

    # 因为libevent_openssl依赖于libssl编译出来的，为了版本匹配，必须配套使用。所以如果需要下载libssl，则也需要下载libevent_openssl。
    if [ ${download_related_lib} -eq 1 ]; then
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
        sh ${PLUGIN_DIR}/uninstall.sh > /dev/null 2>&1
    elif [ -f ${PLUGIN_DIR}/xunyou_uninstall.sh ]; then
        sh ${PLUGIN_DIR}/xunyou_uninstall.sh > /dev/null 2>&1
    else
        rm -rf ${WORK_DIR} ${PLUGIN_DIR}
    fi

    #log "Uninstall plugin success."

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

    if [ "$SYSTEM_TYPE" == "oray" ]; then
        local available=`df -m | awk -F" " '$6=="'${PLUGIN_MOUNT_DIR}'" {print $4}' | sed -n 1p | tr -d M`
        available=$(awk 'BEGIN{print '${available}'*1000 }')
    else
        local available=`df -k | awk -F" " '$6=="'${PLUGIN_MOUNT_DIR}'" {print $4}' | sed -n 1p`
    fi   
    
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
        cp -af ${INSTALL_DIR}/xunyou/webs/Module_xunyou.asp /koolshare/webs/
        cp -af ${INSTALL_DIR}/xunyou/res/icon-xunyou.png /koolshare/res/
        
        chmod +x ${INSTALL_DIR}/xunyou/webs/get_lan_mac.sh
        cp -af ${INSTALL_DIR}/xunyou/webs/get_lan_mac.sh /koolshare/scripts/xunyou_get_lan_mac.sh

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

    sleep 2
    sh ${PLUGIN_DIR}/xunyou_daemon.sh status >> ${INSTALL_LOG}
    if [ $? -ne 0 ]; then
        log "Plugin running status is not ok."
        return 10
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
    post_es_log install fail ${ret}
    install_exit
    exit ${ret}
fi

download_install_json
ret=$?
if [ ${ret} -ne 0 ];then
    post_es_log install fail ${ret}
    install_exit
    exit ${ret}
fi

download_plugin
ret=$?
if [ ${ret} -ne  0 ];then
    post_es_log install fail ${ret}
    install_exit
    exit ${ret}
fi

#安装之前先备份
set_xunyou_bak
ret=$?
if [ ${ret} -ne 0 ];then
    post_es_log install fail ${ret}
    install_exit
    exit ${ret}
fi

#执行卸载操作
uninstall_plugin
ret=$?
if [ ${ret} -ne 0 ];then
    post_es_log install fail ${ret}
    restore_xunyou_bak
    post_es_log restore_backup success
    install_exit
    exit ${ret}
fi

#执行安装操作
install_plugin
ret=$?
if [ ${ret} -ne 0 ];then
    post_es_log install fail ${ret}
    restore_xunyou_bak
    post_es_log restore_backup success
    install_exit
    exit ${ret}
fi

post_es_log install success
#启动插件
start_plugin
ret=$?
if [ ${ret} -ne 0 ]; then
    post_es_log install_start fail ${ret}
    restore_xunyou_bak
    post_es_log restore_backup success
    post_es_log backup_start success
    install_exit
    exit ${ret}
fi

post_es_log install_start success

log "Install and start plugin success!"

install_exit
