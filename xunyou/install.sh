#!/bin/sh
#1.0.5.4

source /etc/profile

title="迅游加速器"
systemType=0
logPath="/tmp/xunyou_install.log"
isBackup=0
installCfgUrl=""
old_version=""
old_title=""

log()
{
    echo [`date +"%Y-%m-%d %H:%M:%S"`] "${1}" >> ${logPath}
}

remove_install_file(){
    rm -rf /tmp/xunyou*.gz > /dev/null 2>&1
    rm -rf /tmp/xunyou > /dev/null 2>&1
    rm -rf /tmp/xunyou_bak > /dev/null 2>&1
}

get_json_value()
{
    local json=${1}
    local key=${2}
    local num=1
    local value=$(echo "${json}" | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'${key}'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p)
    echo ${value}
}

get_install_json_url()
{
    alias=$(nvram get wps_mfstring)
    model=$(nvram get productid)
    version=$(nvram get buildno)
    log "alias=${alias}, model=${model}, version=${version}"

    resp_info_json=$(curl -X POST -H "Content-Type: application/json" -d '{"alias":"'"${alias}"'","model":"'"${model}"'","version":"'"${version}"'"}' "https://router.xunyou.com/index.php/vendor/get-info") > /dev/null 2>&1
    
    local ret=$?
    if [ ${ret} -ne 0 ] ;then
        log "curl get info faild: $ret"
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
        log "cannet find the install.json's url"
        return 4
    fi
    installCfgUrl="https:"${url_value}
    installCfgUrl=$(echo ${installCfgUrl} | sed 's/\\//g')
    
    return 0
}

download_adaptation_install_bin()
{
    rm -f /tmp/xunyou/install.json
    wget --no-check-certificate -O /tmp/xunyou/install.json ${installCfgUrl} > /dev/null 2>&1
    local ret=$?
    if [ ${ret} -ne 0 ];then
        log "wget install config file failed: ${ret}"
        return 5
    fi
    
    json=$(sed ':a;N;s/\n//g;ta' /tmp/xunyou/install.json)
    urlString=$(echo $json | awk -F"," '{print $1}' | sed s/\"//g)
    checksumString=$(echo $json | awk -F"," '{print $2}' | sed s/\"//g)

    installUrl=${urlString#*:}
    installChecksum=${checksumString#*:}

    wget --no-check-certificate -O /tmp/xunyou/adaptation_install ${installUrl} > /dev/null 2>&1
    ret=$?
    if [ ${ret} -ne 0 ];then
        log "wget adaptation_install bin file failed: ${ret}"
        return 5
    fi
    chmod 777 /tmp/xunyou/adaptation_install

    checksum=$(md5sum /tmp/xunyou/adaptation_install)
    ret=$?
    if [ ${ret} -ne 0 ];then
        log "execute md5sum failed:${ret}"
        return 7
    fi
    
    installChecksum=$(echo ${installChecksum} | tr [a-z] [A-Z])
    checksum=$(echo ${checksum} | awk '{print $1}' | tr [a-z] [A-Z])
    if [ ${installChecksum} != ${checksum} ]; then
        log "adaptation_install file check checksum failed"
        return 8
    fi
    
    return 0
}

set_xunyou_bak()
{
    if [ ${systemType} -eq 0 ];then
        if [ -e "/koolshare/xunyou" ];then
            isBackup=1
            rm -f /tmp/xunyou_bak.tar.gz
            cd /koolshare && tar -czvf /tmp/xunyou_bak.tar.gz xunyou > /dev/null 2>&1
            
            old_version=`dbus get xunyou_version`
            old_title=`dbus get xunyou_title`
            
            log "backup xunyou success"
        fi
    elif [ ${systemType} -eq 1 ];then
        if [ -e "/jffs/xunyou" ];then
            isBackup=1
            rm -f /tmp/xunyou_bak.tar.gz
            cd /jffs && tar -czvf /tmp/xunyou_bak.tar.gz xunyou > /dev/null 2>&1
            
            log "backup xunyou success"
        fi
    else
        echo "unknown dev"
    fi
}

restore_xunyou_bak()
{
    if [ ${isBackup} == 1 ]; then
        if [ ${systemType} -eq  0 ];then
            if [ -f "/tmp/xunyou_bak.tar.gz" ];then
                mkdir -p /tmp/xunyou_bak
                cd /tmp && tar -zxvf xunyou_bak.tar.gz -C /tmp/xunyou_bak > /dev/null 2>&1
                #
                dbus set xunyou_enable=1
                #
                cp -rf /tmp/xunyou_bak/xunyou/webs/* /koolshare/webs/
                cp -rf /tmp/xunyou_bak/xunyou/res/*  /koolshare/res/
                cp -arf /tmp/xunyou_bak/xunyou       /koolshare
                #
                [ -f /koolshare/configs/xunyou-user ] && mv -f /koolshare/configs/xunyou-user /koolshare/xunyou/configs/
                [ -f /tmp/xunyou-device ] && cp -f /tmp/xunyou-device /koolshare/xunyou/configs/
                [ -f /tmp/xunyou-user ] && cp -f /tmp/xunyou-user /koolshare/xunyou/configs/
                [ -f /tmp/xunyou-game ] && cp -f /tmp/xunyou-game /koolshare/xunyou/configs/
                
                cp -rf /tmp/xunyou_bak/xunyou/uninstall.sh  /koolshare/scripts/uninstall_xunyou.sh
                #
                chmod -R 777 /koolshare/xunyou/*
                #
                ln -sf /koolshare/xunyou/scripts/xunyou_config.sh /koolshare/init.d/S90XunYouAcc.sh
                ln -sf /koolshare/xunyou/scripts/xunyou_config.sh /koolshare/scripts/xunyou_status.sh
                #
                dbus set xunyou_version="${old_version}"
                dbus set xunyou_title="${old_title}"
                dbus set softcenter_module_xunyou_install=1
                dbus set softcenter_module_xunyou_name=xunyou
                dbus set softcenter_module_xunyou_version="${old_version}"
                dbus set softcenter_module_xunyou_title="${old_title}"
                dbus set softcenter_module_xunyou_description="迅游加速器，支持PC和主机加速。"
                #
                sh /koolshare/xunyou/scripts/xunyou_config.sh app
            fi
        elif [ ${systemType} -eq 1 ];then
            if [ -f "/tmp/xunyou_bak.tar.gz" ];then
                mkdir -p /tmp/xunyou_bak
                cd /tmp && tar -zxvf xunyou_bak.tar.gz -C /tmp/xunyou_bak > /dev/null 2>&1
                cp -arf /tmp/xunyou_bak/xunyou    /jffs/

                [ -f /jffs/configs/xunyou-user ] && mv -f /jffs/configs/xunyou-user /jffs/xunyou/configs/
                [ -f /tmp/xunyou-device ] && cp -f /tmp/xunyou-device /jffs/xunyou/configs/
                [ -f /tmp/xunyou-user ] && cp -f /tmp/xunyou-user /jffs/xunyou/configs/
                [ -f /tmp/xunyou-game ] && cp -f /tmp/xunyou-game /jffs/xunyou/configs/
                #
                chmod -R 777 /jffs/xunyou/*
                ln -sf /jffs/xunyou/scripts/xunyou_config.sh /etc/init.d/S90XunYouAcc.sh > /dev/null 2>&1
                sh /jffs/xunyou/scripts/xunyou_config.sh app
            fi
        else
            echo "unknown dev"
        fi
        
        log "restore xunyou success"
    fi
}

uninstall_xunyou()
{
    if [ ${systemType} -eq  0 ];then
        [ -e "/koolshare/scripts/uninstall_xunyou.sh" ] && sh /koolshare/scripts/uninstall_xunyou.sh upgrade > /dev/null 2>&1
    elif [ ${systemType} -eq 1 ];then
        [ -e "/jffs/xunyou/uninstall.sh" ] && sh /jffs/xunyou/uninstall.sh upgrade > /dev/null 2>&1
    else
        echo "unknown dev"
    fi
    
    log "uninstall xunyou success"
}

log "安装迅游模块！"

if [ -d "/koolshare" ];then
    systemType=0
else
    systemType=1
    [ ! -d "/jffs" ] && systemType=2
fi

rm -f /tmp/xunyou_install.log

mkdir -p /tmp/xunyou
cd /tmp/xunyou

set_xunyou_bak

get_install_json_url
ret=$?
if [ ${ret} -ne  0 ];then
    restore_xunyou_bak
    remove_install_file
    cat ${logPath}
    exit ${ret}
fi

log "get install config file url success!"

download_adaptation_install_bin
ret=$?
if [ ${ret} -ne  0 ];then
    restore_xunyou_bak
    remove_install_file
    cat ${logPath}
    exit ${ret}
fi

log "[app]: download adaptation_install bin success."

#执行卸载操作
uninstall_xunyou

log "beging to adaptation_install xunyou"

/tmp/xunyou/adaptation_install >> ${logPath}
ret=$?
if [ ${ret} -ne 0 ];then
    log "adaptation_install xunyou faild"
    restore_xunyou_bak
    remove_install_file
    cat ${logPath}
    exit ${ret}
fi

log "adaptation_install success!!!"

remove_install_file

cat ${logPath}
exit 0

