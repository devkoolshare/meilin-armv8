#!/bin/sh

source /etc/profile

systemType=0

sleep 1

if [ -d "/koolshare" ];then
    systemType=0
    BasePath="/koolshare"
else
    systemType=1
    BasePath="/jffs"
    [ ! -d "/jffs" ] && exit 1
fi

delete_xunyou_cfg()
{
    rm -rf ${BasePath}/configs/xunyou-*
    rm -rf /var/log/xunyou-*
    rm -rf /jffs/configs/dnsmasq.d/xunyou.conf
    rm -rf /tmp/xunyou_uninstall.sh
}

koolshare_uninstall()
{
    eval `dbus export xunyou_`
    source /koolshare/scripts/base.sh
    #
    sh /koolshare/xunyou/scripts/xunyou_config.sh uninstall
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
    [ -e /koolshare/xunyou/configs/xunyou-user ] && cp -af /koolshare/xunyou/configs/xunyou-user /tmp/
    [ -e /koolshare/xunyou/configs/xunyou-device ] && cp -af /koolshare/xunyou/configs/xunyou-device /tmp/
    [ -e /koolshare/xunyou/configs/xunyou-game ] && cp -af /koolshare/xunyou/configs/xunyou-game /tmp/

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
    sh /jffs/xunyou/scripts/xunyou_config.sh uninstall
    #
    [ -e /jffs/xunyou/configs/xunyou-user ] && cp -af /jffs/xunyou/configs/xunyou-user /tmp/
    [ -e /jffs/xunyou/configs/xunyou-device ] && cp -af /jffs/xunyou/configs/xunyou-device /tmp/
    [ -e /jffs/xunyou/configs/xunyou-game ] && cp -af /jffs/xunyou/configs/xunyou-game /tmp/

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
