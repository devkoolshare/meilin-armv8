#!/bin/sh

source /etc/profile

title="迅游加速器"
systemType=0

remove_install_file(){
    rm -rf /tmp/xunyou*.gz > /dev/null 2>&1
    rm -rf /tmp/xunyou > /dev/null 2>&1
}

cd /tmp

if [ ! -f /tmp/xunyou/version ]; then
    echo "version文件不存在，获取插件版本号失败！！！"
    echo [`date +"%Y-%m-%d %H:%M:%S"`] "退出安装！"
    remove_install_file
    exit 1
fi

VERSION=`cat /tmp/xunyou/version`

case $(uname -m) in
    aarch64)
        ;;
    armv7l)
        kernel=`uname -r`
        if [ -z "${kernel}" ];then
            echo [`date +"%Y-%m-%d %H:%M:%S"`] "获取内核版本号失败！！！"
            echo [`date +"%Y-%m-%d %H:%M:%S"`] "退出安装！"
            remove_install_file
            exit 1
        fi
        #
        one=`echo ${kernel} | awk -F '.' '{print $1}'`
        second=`echo ${kernel} | awk -F '.' '{print $2}'`
        if [[ "${one}" != "4" || "${second}" != "1" ]];then
            echo [`date +"%Y-%m-%d %H:%M:%S"`] "内核版本号不匹配，你的内核版本：$(uname -r)不能安装！！！"
            echo [`date +"%Y-%m-%d %H:%M:%S"`] "退出安装！"
            remove_install_file
            exit 1
        fi
        ;;
    *)
        echo [`date +"%Y-%m-%d %H:%M:%S"`] "本插件适用于【koolshare merlin hnd/axhnd aarch64】固件平台，你的平台：$(uname -m)不能安装！！！"
        echo [`date +"%Y-%m-%d %H:%M:%S"`] "退出安装！"
        remove_install_file
        exit 1
        ;;
esac

if [ -d "/koolshare" ];then
    systemType=0
else
    systemType=1
    [ ! -d "/jffs" ] && systemType=2
fi

koolshare_install()
{
    [ -e "/koolshare/scripts/uninstall_xunyou.sh" ] && sh /koolshare/scripts/uninstall_xunyou.sh
    mkdir -p /koolshare/xunyou
    #
    dbus set xunyou_enable=1
    #
    cp -rf /tmp/xunyou/webs/* /koolshare/webs/
    cp -rf /tmp/xunyou/res/*  /koolshare/res/
    cp -arf /tmp/xunyou       /koolshare

    [ -f /koolshare/configs/xunyou-user ] && mv -f /koolshare/configs/xunyou-user /koolshare/xunyou/configs/
    [ -f /tmp/xunyou-device ] && cp -f /tmp/xunyou-device /koolshare/xunyou/configs/
    [ -f /tmp/xunyou-user ] && cp -f /tmp/xunyou-user /koolshare/xunyou/configs/
    [ -f /tmp/xunyou-game ] && cp -f /tmp/xunyou-game /koolshare/xunyou/configs/

    cp -rf /tmp/xunyou/uninstall.sh  /koolshare/scripts/uninstall_xunyou.sh
    #
    chmod -R 777 /koolshare/xunyou/*
    #
    ln -sf /koolshare/xunyou/scripts/xunyou_config.sh /koolshare/init.d/S90XunYouAcc.sh
    ln -sf /koolshare/xunyou/scripts/xunyou_config.sh /koolshare/scripts/xunyou_status.sh
    #
    dbus set xunyou_version="${VERSION}"
    dbus set xunyou_title="${title}"
    dbus set softcenter_module_xunyou_install=1
    dbus set softcenter_module_xunyou_name=xunyou
    dbus set softcenter_module_xunyou_version="${VERSION}"
    dbus set softcenter_module_xunyou_title="${title}"
    dbus set softcenter_module_xunyou_description="迅游加速器，支持PC和主机加速。"
    #
    sh /koolshare/xunyou/scripts/xunyou_config.sh app
}

official_install()
{
    [ -e "/jffs/xunyou/uninstall.sh" ] && sh /jffs/xunyou/uninstall.sh
    #
    cp -arf /tmp/xunyou    /jffs/

    [ -f /jffs/configs/xunyou-user ] && mv -f /jffs/configs/xunyou-user /jffs/xunyou/configs/
    [ -f /tmp/xunyou-device ] && cp -f /tmp/xunyou-device /jffs/xunyou/configs/
    [ -f /tmp/xunyou-user ] && cp -f /tmp/xunyou-user /jffs/xunyou/configs/
    [ -f /tmp/xunyou-game ] && cp -f /tmp/xunyou-game /jffs/xunyou/configs/
    #
    chmod -R 777 /jffs/xunyou/*
    ln -sf /jffs/xunyou/scripts/xunyou_config.sh /etc/init.d/S90XunYouAcc.sh > /dev/null 2>&1
    sh /jffs/xunyou/scripts/xunyou_config.sh app
}

case ${systemType} in
    0)
        koolshare_install
        ;;
    1)
        official_install
        ;;
    2)
        ;;
    *)
        ;;
esac

remove_install_file

exit 0
