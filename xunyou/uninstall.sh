#!/bin/sh

source /etc/profile

MODULE=xunyou
title="迅游加速器"
VERSION="1.0.0.1"
module="xunyou_acc"
systemType=0
uninstallType="0"

sleep 1

if [ -d "/koolshare" ];then
    systemType=0
    xunyouPath="/koolshare"
else
    systemType=1
    xunyouPath="/jffs"
    [ ! -d "/jffs" ] && exit 1
fi

[[ -n "${1}" && "${1}" == "update" ]] && uninstallType="1"


delete_xunyou_cfg()
{
    if [ "${uninstallType}" != "1" ];then
        rm -rf /jffs/configs/*xunyou*
        rm -rf /tmp/xunyou-*
        rm -rf ${xunyouPath}/configs/xunyou-*
    fi
    #
    rm -rf /var/log/xunyou-*
    rm -rf /jffs/configs/dnsmasq.d/xunyou.conf
    rm -rf /tmp/xunyou_uninstall.sh
    #
}

koolshare_uninstall()
{
    eval `dbus export xunyou_`
    source /koolshare/scripts/base.sh
    #
    sh /koolshare/xunyou/scripts/${MODULE}_config.sh uninstall
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
    rm -rf /koolshare/scripts/xunyou_status.sh
    rm -rf /koolshare/init.d/S90XunYouAcc.sh
    rm -rf /koolshare/xunyou
    rm -rf /koolshare/res/icon-xunyou.png
    rm -rf /koolshare/webs/Module_xunyou.asp
    rm -rf /koolshare/scripts/uninstall_xunyou.sh
    #
    delete_xunyou_cfg
}

official_uninstall()
{
    [ ! -d "/jffs/xunyou" ] && return 1
    #
    sh /jffs/xunyou/scripts/${MODULE}_config.sh uninstall
    #
    rm -rf /etc/init.d/S90XunYouAcc.sh > /dev/null 2>&1
    rm -rf /jffs/xunyou/
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
