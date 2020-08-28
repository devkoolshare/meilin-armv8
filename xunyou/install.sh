#!/bin/sh

source /etc/profile

MODULE=xunyou
title="迅游加速器"
VERSION="1.0.0.3"
systemType=0
clientType="0"

remove_install_file(){
    rm -rf /tmp/${MODULE}*.gz > /dev/null 2>&1
    rm -rf /tmp/${MODULE} > /dev/null 2>&1
}

cd /tmp

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

#[[ "${1}" == "app" || "${1}" == "APP" ]] && clientType="1"
clientType="1"

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
    dbus set ${MODULE}_enable=0
    [ "${clientType}" == "1" ] && dbus set ${MODULE}_enable=1
    #
    cp -rf /tmp/${MODULE}/webs/* /koolshare/webs/
    cp -rf /tmp/${MODULE}/res/*  /koolshare/res/
    cp -rf /tmp/${MODULE}/*      /koolshare/xunyou/
    cp -rf /tmp/${MODULE}/uninstall.sh  /koolshare/scripts/uninstall_xunyou.sh
    #
    chmod -R 777 /koolshare/xunyou/* 
    #
    ln -sf /koolshare/xunyou/scripts/${MODULE}_config.sh /koolshare/init.d/S90XunYouAcc.sh
    ln -sf /koolshare/xunyou/scripts/${MODULE}_config.sh /koolshare/scripts/xunyou_status.sh
    #
    dbus set ${MODULE}_version="${VERSION}"
    dbus set ${MODULE}_title="${title}"
    dbus set softcenter_module_${MODULE}_install=1
    dbus set softcenter_module_${MODULE}_name=${MODULE}
    dbus set softcenter_module_${MODULE}_version="${VERSION}"
    dbus set softcenter_module_${MODULE}_title="${title}"
    dbus set softcenter_module_${MODULE}_description="迅游加速器，支持PC和主机加速。"
    #
    [ "${clientType}" == "1" ] &&  sh /koolshare/xunyou/scripts/${MODULE}_config.sh app
}

official_install()
{
    if [ ! -d "/jffs/xunyou" ];then
        ret=`mkdir -p /jffs/xunyou`
        [ -n "${ret}" ] && echo [`date +"%Y-%m-%d %H:%M:%S"`] "创建安装路径失败！" && return 1
    fi
    #
    [ -e "/jffs/xunyou/uninstall.sh" ] && sh /jffs/xunyou/uninstall.sh
    #
    rm -rf /etc/init.d/S90XunYouAcc.sh > /dev/null 2>&1
    cp -rf /tmp/${MODULE}/*      /jffs/xunyou/
    #
    chmod -R 777 /jffs/xunyou/*
    ln -sf /jffs/xunyou/scripts/${MODULE}_config.sh /etc/init.d/S90XunYouAcc.sh > /dev/null 2>&1
    sh /jffs/xunyou/scripts/${MODULE}_config.sh app
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
