#!/bin/sh

source /etc/profile

systemType=0
action=$1

#等待插件回复完消息后再卸载
sleep 1

if [ -d "/koolshare" ];then
    systemType=0
    BasePath="/koolshare"
else
    systemType=1
    BasePath="/jffs"
    [ ! -d "/jffs" ] && exit 1
fi

unbind_api="https://router-wan.xunyou.com:9004/v2/core/removeuserrouter"

get_json_value()
{
    local json=${1}
    local key=${2}
    local num=1
    local value=$(echo "${json}" | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'${key}'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p)
    echo ${value}
}

send_unbind_msg()
{
    #远程卸载和升级卸载不需要发送解绑消息
    if [ "${action}" != "remote" -a "${action}" != "upgrade" ]; then
        if [ -e ${BasePath}/xunyou/configs/xunyou-user ]; then
            value=`cat ${BasePath}/xunyou/configs/xunyou-user`
            key="userId"
            userId=$(get_json_value $value $key)
            [ -z "${userId}" ] && return

            data='{"userid":"'${userId}'"}'

            curl -H "Content-Type: application/json" -X POST -d '{"userid":"'${userId}'"}' "${unbind_api}" > /dev/null 2&>1
        fi
    fi
}

delete_xunyou_cfg()
{
    rm -rf ${BasePath}/configs/xunyou-*
    rm -rf /var/log/xunyou-*
    rm -rf /jffs/configs/dnsmasq.d/xunyou.conf
    rm -rf /tmp/xunyou_uninstall.sh
}

koolshare_uninstall()
{
    send_unbind_msg
    #
    eval `dbus export xunyou_`
    source ${BasePath}/scripts/base.sh
    #
    sh ${BasePath}/xunyou/scripts/xunyou_config.sh uninstall
    #
    values=`dbus list xunyou_ | cut -d "=" -f 1`
    for value in $values
    do
        dbus remove $value
    done
    #
    values=`dbus list softcenter_module_xunyou_ | cut -d "=" -f 1`
    for value in $values
    do
        dbus remove $value
    done
    #
    [ -e ${BasePath}/xunyou/configs/xunyou-user ] && cp -af ${BasePath}/xunyou/configs/xunyou-user /tmp/
    [ -e ${BasePath}/xunyou/configs/xunyou-device ] && cp -af ${BasePath}/xunyou/configs/xunyou-device /tmp/
    [ -e ${BasePath}/xunyou/configs/xunyou-game ] && cp -af ${BasePath}/xunyou/configs/xunyou-game /tmp/

    rm -rf ${BasePath}/scripts/xunyou_status.sh
    rm -rf ${BasePath}/init.d/S90XunYouAcc.sh
    rm -rf ${BasePath}/xunyou
    rm -rf ${BasePath}/res/icon-xunyou.png
    rm -rf ${BasePath}/webs/Module_xunyou.asp
    rm -rf ${BasePath}/scripts/uninstall_xunyou.sh
    #
    delete_xunyou_cfg
}

official_uninstall()
{
    send_unbind_msg
    #
    sh ${BasePath}/xunyou/scripts/xunyou_config.sh uninstall
    #
    [ -e ${BasePath}/xunyou/configs/xunyou-user ] && cp -af ${BasePath}/xunyou/configs/xunyou-user /tmp/
    [ -e ${BasePath}/xunyou/configs/xunyou-device ] && cp -af ${BasePath}/xunyou/configs/xunyou-device /tmp/
    [ -e ${BasePath}/xunyou/configs/xunyou-game ] && cp -af ${BasePath}/xunyou/configs/xunyou-game /tmp/

    rm -rf /etc/init.d/S90XunYouAcc.sh > /dev/null 2>&1
    rm -rf ${BasePath}/xunyou/
    #
    delete_xunyou_cfg
}

case ${systemType} in
    0)
        koolshare_uninstall
        ;;
    1)
        official_uninstall
        ;;
    2)
        ;;
    *)
        ;;
esac
