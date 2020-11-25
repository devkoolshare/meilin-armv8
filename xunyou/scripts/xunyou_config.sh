#!/bin/sh

source /etc/profile

if [ -d "/koolshare" ];then
    source /koolshare/scripts/base.sh
    eval `dbus export xunyou`
    BasePath="/koolshare"
    #
    [ "${1}" == "app" ] && dbus set xunyou_enable=1 && xunyou_enable="1"
else
    xunyou_enable="1"
    BasePath="/jffs"
    [ ! -d "/jffs" ] && exit 1
fi

module="xunyou_acc"
ifname="br0"
XunyouPath="${BasePath}/xunyou"
LibPath="${XunyouPath}/lib"
kernelKoPath="${XunyouPath}/modules"

RouteCfg="${XunyouPath}/configs/RouteCfg.conf"
ProxyCfg="${XunyouPath}/configs/ProxyCfg.conf"
DeviceCfg="${XunyouPath}/configs/DeviceCfg.conf"
IpsetCfg="${XunyouPath}/configs/IpsetCfg.conf"
UserInfo="${XunyouPath}/configs/xunyou-user"
GameInfo="${XunyouPath}/configs/xunyou-game"
DeviceInfo="${XunyouPath}/configs/xunyou-device"
IpsetEnableCfg="${XunyouPath}/configs/ipset_enable"

logPath="${XunyouPath}/log/xunyou-install.log"
RouteLog="${XunyouPath}/log/xunyou-ctrl.log"
ProxyLog="${XunyouPath}/log/xunyou-proxy.log"
DeviceLog="${XunyouPath}/log/xunyou-device.log"
IpsetLog="${XunyouPath}/log/xunyou-ipset.log"

ProxyScript="${XunyouPath}/scripts/xunyou_rule.sh"
UpdateScript="${XunyouPath}/scripts/xunyou_upgrade.sh"
CfgScript="${XunyouPath}/scripts/xunyou_config.sh"
DeviceScript="${XunyouPath}/scripts/xunyou_dev.sh"

CtrlProc="xy-ctrl"
ProxyProc="xy-proxy"
DeviceProc="xy-device"
IpsetProc="xy-ipset"
UdpPostProc="udp-post"

ProxyCfgPort="29595"
RoutePort="28099"
DevicePort="29090"
IpsetPort="27890"

DnsmasqCfgFile="/etc/dnsmasq.conf"
iptName="XUNYOU"
iptAccName="XUNYOUACC"
rtName="95"

domain="router-lan.xyrouterqpm3v2bi.cc"
match="|0a|router-lan|10|xyrouterqpm3v2bi|02|cc"
domainHex="0a726f757465722d6c616e107879726f7574657271706d3376326269026363"

gateway=`ip address show ${ifname} | grep "\<inet\>" | awk -F ' ' '{print $2}' | awk -F '/' '{print $1}'`
[ -z "${gateway}" ] && exit 1

[ ! -f ${XunyouPath}/version ] && exit 1

VERSION=`cat ${XunyouPath}/version`
[ -z "${VERSION}" ] && exit 1

log()
{
    echo [`date +"%Y-%m-%d %H:%M:%S"`] "${1}" >> ${logPath}
}

iptables_rule_cfg()
{
    ret=`iptables -t mangle -S | grep "\<${iptName}\>"`
    [ -z "${ret}" ] && iptables -t mangle -N ${iptName}

    ret=`iptables -t mangle -S PREROUTING | grep "\<${iptName}\>"`
    if [ -z "${ret}" ];then
        iptables -t mangle -I PREROUTING -i ${ifname} -p udp -m comment --comment "KOOLPROXY" -j ${iptName}
    fi
    #
    ret=`iptables -t nat -S | grep "\<${iptName}\>"`
    [ -z "${ret}" ] && iptables -t nat -N ${iptName}

    ret=`iptables -t nat -S PREROUTING | grep "\<${iptName}\>"`
    if [ -z "${ret}" ];then
        iptables -t nat -I PREROUTING -i ${ifname} -m comment --comment "KOOLPROXY" -j ${iptName}
    fi
    #
    ret=`iptables -t nat -S | grep "${iptAccName}"`
    [ -z "${ret}" ] && iptables -t nat -N ${iptAccName}
    ret=`iptables -t mangle -S | grep "${iptAccName}"`
    [ -z "${ret}" ] && iptables -t mangle -N ${iptAccName}

    #添加mangle表规则
    iptables -t mangle -F ${iptName}
    iptables -t mangle -A ${iptName} -d ${gateway} -j ACCEPT
    iptables -t mangle -A ${iptName} -i ${ifname} -p udp --dport 53 -m string --hex-string "${match}" --algo kmp -j ACCEPT
    iptables -t mangle -A ${iptName} -p udp -j ${iptAccName}

    #添加nat表规则
    iptables -t nat -F ${iptName}
    iptables -t nat -A ${iptName} -d ${gateway} -j ACCEPT
    iptables -t nat -A ${iptName} -i ${ifname} -p udp --dport 53 -m string --hex-string "${match}" --algo kmp -j DNAT --to-destination ${gateway}
    iptables -t nat -A ${iptName} -p tcp -j ${iptAccName}
}

set_dnsmasq_config()
{
    #配置默认的DNS服务器
    lan_dns=`nvram get dhcp_dns1_x`
    if [ -z "${lan_dns}" ]; then
        wan_dns=`nvram get wan_dns | cut -d' ' -f1`
        if [ -n "${wan_dns}" ]; then
            nvram set dhcp_dns1_x=${wan_dns}
        else
            nvram set dhcp_dns1_x=223.6.6.6
        fi
    fi

    #关闭以网关地址作为DNS服务器
    nvram set dhcpd_dns_router=0

    if [ -f ${DnsmasqCfgFile} ]; then
        DnsConfDir=`awk -F "=" '$1=="conf-dir" {print $2}' ${DnsmasqCfgFile}`
        AddnHostsDir=`awk -F "=" '$1=="addn-hosts" {print $2}' ${DnsmasqCfgFile}`

        if [ -n "${DnsConfDir}" -a -d ${DnsConfDir} ]; then
            grep "address=/${domain}/${gateway}" ${DnsConfDir}/xunyou.conf >/dev/null 2>&1 && return 0
            echo "address=/${domain}/${gateway}" > ${DnsConfDir}/xunyou.conf
            service restart_dnsmasq >/dev/null 2>&1
            return 0
        elif [ -n "${AddnHostsDir}" -a -d ${AddnHostsDir} ]; then
            grep "${gateway} ${domain}" ${AddnHostsDir%*/}/${domain} >/dev/null 2>&1 && return 0
            echo "${gateway} ${domain}" > ${AddnHostsDir%*/}/${domain}
            service restart_dnsmasq >/dev/null 2>&1
            return 0
        fi
    fi

    ret=`cat /etc/hosts | grep "${domain}"`
    [ -n "${ret}" ] && return 0

    nvram set lan_hostname="router-lan"
    nvram set lan_domain="xyrouterqpm3v2bi.cc"

    service restart_dnsmasq >/dev/null 2>&1
}

ipset_check()
{
    IpsetEnable="0"

    ipset_cmd=`type -p ipset`
    if [ -z "${ipset_cmd}" ]; then
        if [ -f ${kernelKoPath}/${kernel_version}/bin/ipset ]; then
            ipset_cmd="${kernelKoPath}/${kernel_version}/bin/ipset"
        else
            IpsetEnable="1"
            echo -n ${IpsetEnable} > ${IpsetEnableCfg}
            return
        fi
    fi

    ${ipset_cmd} -! create test_net hash:net || IpsetEnable="1"
    ${ipset_cmd} destroy test_net || IpsetEnable="1"
    ${ipset_cmd} -! create test_netport hash:net,port || IpsetEnable="1"
    ${ipset_cmd} destroy test_netport || IpsetEnable="1"

    echo -n ${IpsetEnable} > ${IpsetEnableCfg}
}

create_config_file()
{
    IpsetEnable=$1
    [ -z "${IpsetEnable}" ] && return 1

    product_arch=`uname -m`
    if [ ! -z ${product_arch} ];then
        if [ ${product_arch} == "aarch64" ];then
            product_arch="arm-8"
        elif [ ${product_arch} == "armv7l"  ];then
            product_arch="arm-7"
        fi
    fi

    #product_version=`nvram get buildno`
    product_version="384"

    product_id=`nvram get productid`
    if [ -z ${product_id} ];then
        product_id=`nvram get odmpid`
        if [ -z ${product_id} ];then
            product_id="unknown"
        fi
    fi

    if [ ${product_id} =  "RT-AX55" -o ${product_id} =  "RT-AX82U" -o ${product_id} =  "TUF-AX3000" ];then
        product_arch="arm-8"
    fi

    str="$product_version"
    substr=${str%.*}
    product_version=$substr

    mac=`ip address show ${ifname} | grep link/ether | awk -F ' ' '{print $2}'`
    [ -z "${mac}" ] && return 1
    #
    flag=`netstat -an | grep ${ProxyCfgPort}`
    [ -n "${flag}" ] && ProxyCfgPort="39595"
    flag=`netstat -an | grep ${RoutePort}`
    [ -n "${flag}" ] && RoutePort="28090"
    #
    sed -i 's/\("version":"\).*/\1'${VERSION}'",/g' ${RouteCfg}
    sed -i 's/\("httpd-svr":"\).*/\1'${gateway}'",/g' ${RouteCfg}
    sed -i 's/\("route-mac":"\).*/\1'${mac}'",/g'     ${RouteCfg}
    sed -i 's#\("log":"\).*#\1'${RouteLog}'",#g'      ${RouteCfg}
    sed -i 's/\("net-device":"\).*/\1'${ifname}'",/g'              ${RouteCfg}
    sed -i 's/\("route-name":"\).*/\1'${product_id}'",/g'           ${RouteCfg}
    sed -i 's/\("proxy-manage-port":\).*/\1'${ProxyCfgPort}',/g'   ${RouteCfg}
    sed -i 's/\("local-port":\).*/\1'${RoutePort}',/g'             ${RouteCfg}
    sed -i 's#\("dev-shell":"\).*#\1'${DeviceScript}'",#g'         ${RouteCfg}
    sed -i 's#\("upgrade-shell":"\).*#\1'${UpdateScript}'",#g'     ${RouteCfg}
    sed -i 's#\("user-info":"\).*#\1'${UserInfo}'",#g'             ${RouteCfg}
    sed -i 's#\("game-info":"\).*#\1'${GameInfo}'",#g'             ${RouteCfg}
    sed -i 's#\("ipset-enable":\).*#\1'${IpsetEnable}',#g'         ${RouteCfg}
    sed -i 's#\("product-arch":"\).*#\1'${product_arch}'",#g'        ${RouteCfg}
    sed -i 's#\("product-version":"\).*#\1'${product_version}'",#g'  ${RouteCfg}
    #
    sed -i 's/\("local-ip":"\).*/\1'${gateway}'",/g'             ${ProxyCfg}
    sed -i 's/\("manage":\).*/\1'${ProxyCfgPort}',/g'            ${ProxyCfg}
    sed -i 's#\("log":"\).*#\1'${ProxyLog}'",#g'                 ${ProxyCfg}
    sed -i 's#\("script-cfg":"\).*#\1'${ProxyScript}'",#g'       ${ProxyCfg}
    sed -i 's#\("ipset-enable":\).*#\1'${IpsetEnable}',#g'     ${ProxyCfg}
    #
    sed -i 's/\("route-mac":"\).*/\1'${mac}'",/g'     ${DeviceCfg}
    sed -i 's/\("net-device":"\).*/\1'${ifname}'",/g'       ${DeviceCfg}
    sed -i 's/\("local-ip":"\).*/\1'${gateway}'",/g'        ${DeviceCfg}
    sed -i 's/\("local-port":\).*/\1'${DevicePort}',/g'      ${DeviceCfg}
    sed -i 's#\("log":"\).*#\1'${DeviceLog}'",#g'            ${DeviceCfg}
    sed -i 's#\("device-info":"\).*#\1'${DeviceInfo}'",#g'   ${DeviceCfg}
    #
    sed -i 's/\("local-ip":"\).*/\1'${gateway}'",/g'        ${IpsetCfg}
    sed -i 's/\("local-port":\).*/\1'${IpsetPort}',/g'      ${IpsetCfg}
    sed -i 's#\("log":"\).*#\1'${IpsetLog}'",#g'            ${IpsetCfg}
}

rule_init()
{
    flag=`lsmod | grep xt_comment`
    if [ -z "${flag}" ]; then
        ko_path=`find /lib/modules/ -name xt_comment.ko`
        [ -n "${ko_path}" ] && insmod ${ko_path}
    fi

    flag=`lsmod | grep xt_TPROXY`
    if [ -z "${flag}" ]; then
        ko_path=`find /lib/modules/ -name xt_TPROXY.ko`
        [ -n "${ko_path}" ] && insmod ${ko_path}
    fi

    flag=`lsmod | grep ip_set`
    if [ -z "${flag}" ]; then
        ko_path=`find /lib/modules/ -name ip_set.ko`
        if [ -n "${ko_path}" ]; then
            insmod ${ko_path}
        elif [ -f ${kernelKoPath}/${kernel_version}/kernel/ip_set.ko ]; then
            insmod ${kernelKoPath}/${kernel_version}/kernel/ip_set.ko
        fi
    fi

    flag=`lsmod | grep ip_set_hash_net`
    if [ -z "${flag}" ]; then
        ko_path=`find /lib/modules/ -name ip_set_hash_net.ko`
        if [ -n "${ko_path}" ]; then
            insmod ${ko_path}
        elif [ -f ${kernelKoPath}/${kernel_version}/kernel/ip_set_hash_net.ko ]; then
            insmod ${kernelKoPath}/${kernel_version}/kernel/ip_set_hash_net.ko
        fi
    fi

    flag=`lsmod | grep ip_set_hash_netport`
    if [ -z "${flag}" ]; then
        ko_path=`find /lib/modules/ -name ip_set_hash_netport.ko`
        if [ -n "${ko_path}" ]; then
            insmod ${ko_path}
        elif [ -f ${kernelKoPath}/${kernel_version}/kernel/ip_set_hash_netport.ko ]; then
            insmod ${kernelKoPath}/${kernel_version}/kernel/ip_set_hash_netport.ko
        fi
    fi
}

xunyou_set_time()
{
    ret=`cat /etc/TZ | grep GMT-8`
    [ -n "${ret}" ] && return 0
    echo "GMT-8" > /etc/TZ
}

xunyou_set_link()
{
    [ -e "/tmp/xunyou_uninstall.sh" ] && return 0
    [ -e "${XunyouPath}/uninstall.sh" ] && ln -sf ${XunyouPath}/uninstall.sh /tmp/xunyou_uninstall.sh
}

xunyou_acc_start()
{
    [ -f ${IpsetEnableCfg} ] || return 1
    IpsetEnable=`cat ${IpsetEnableCfg}`

    xunyou_set_time
    xunyou_set_link
    #
    set_dnsmasq_config
    #
    rule_init
    #
    iptables_rule_cfg
    #
    create_config_file ${IpsetEnable}
    #
    ret=`echo $LD_LIBRARY_PATH | grep ${LibPath}`
    [ -z "${ret}" ] && export LD_LIBRARY_PATH=${LibPath}:$LD_LIBRARY_PATH
    ulimit -n 2048
    #
    ret=`ps | grep -v grep | grep nvram`
    [ -n "${ret}" ] && killall nvram >/dev/null 2>&1
    #
    #ulimit -c unlimited
    #echo "/tmp/core-%e-%p" > /proc/sys/kernel/core_pattern

    echo 1 > /proc/sys/vm/overcommit_memory

    ${XunyouPath}/bin/${CtrlProc}  --config ${RouteCfg} &
    ${XunyouPath}/bin/${ProxyProc} --config ${ProxyCfg} &
    ${XunyouPath}/bin/${DeviceProc} --config ${DeviceCfg} &
    if [ ${IpsetEnable} == "1" ]; then
        ${XunyouPath}/bin/${IpsetProc} --config ${IpsetCfg} &
    fi
}

xunyou_acc_install()
{
    rule_init

    ipset_check

    ret=`cru l | grep "${module}"`
    [ -z "${ret}" ] && cru a ${module} "*/1 * * * * ${CfgScript} check"
}

xunyou_clear_rule()
{
    flag=`ip rule | grep ${rtName}`
    [ -n "${flag}" ] && ip r f t ${rtName} >/dev/null 2>&1 && ip rule d t ${rtName} >/dev/null 2>&1
    #
    iptables -t nat -F ${iptName} >/dev/null 2>&1
    iptables -t nat -F ${iptAccName} >/dev/null 2>&1
    #
    iptables -t mangle -F ${iptName} >/dev/null 2>&1
    iptables -t mangle -F ${iptAccName} >/dev/null 2>&1
    #
    iptables -t nat -S PREROUTING | grep "XUNYOU" | while read line
    do
        value=`echo ${line#*A}`
        iptables -t nat -D ${value} >/dev/null 2>&1
    done
    #
    iptables -t nat -X ${iptName} >/dev/null 2>&1
    iptables -t nat -X ${iptAccName} >/dev/null 2>&1
    ####
    iptables -t mangle -S PREROUTING | grep "XUNYOU" | while read line
    do
        value=`echo ${line#*A}`
        iptables -t mangle -D ${value} >/dev/null 2>&1
    done
    #
    iptables -t mangle -X ${iptName} >/dev/null 2>&1
    iptables -t mangle -X ${iptAccName} >/dev/null 2>&1
}

xunyou_acc_stop()
{
    ctrlPid=$(echo -n `ps | grep -v grep | grep -w ${CtrlProc} | awk -F ' ' '{print $1}'`)
    [ -n "${ctrlPid}" ] && kill -9 ${ctrlPid}
    proxyPid=$(echo -n `ps | grep -v grep | grep -w ${ProxyProc} | awk -F ' ' '{print $1}'`)
    [ -n "${proxyPid}" ] && kill -9 ${proxyPid}
    devicePid=$(echo -n `ps | grep -v grep | grep -w ${DeviceProc} | awk -F ' ' '{print $1}'`)
    [ -n "${devicePid}" ] && kill -9 ${devicePid}
    ipsetPid=$(echo -n `ps | grep -v grep | grep -w ${IpsetProc} | awk -F ' ' '{print $1}'`)
    [ -n "${ipsetPid}" ] && kill -9 ${ipsetPid}
    #
    xunyou_clear_rule
}

xunyou_acc_uninstall()
{
    cru d ${module}
    #
    xunyou_acc_stop
    ##
    rm -rf ${RouteLog}*
    rm -rf ${ProxyLog}*
    rm -rf ${DeviceLog}*
    rm -rf ${IpsetLog}*
}

get_json_value()
{
    local json=${1}
    local key=${2}
    local num=1
    local value=$(echo "${json}" | awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'${key}'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p)
    echo ${value}
}

xunyou_post_log()
{
    [ ! -e "${XunyouPath}/bin/${UdpPostProc}" ] && return 0
    #
    process=${1}
    [ -z "${process}" ] && return 0
    #
    RouteName=`nvram get odmpid`
    [ -z "${RouteName}" ] && RouteName=`nvram get productid`
    #
    value=`cat ${UserInfo}`
    key="userName"
    userName=$(get_json_value $value $key)
    [ -z "${userName}" ] return 0
    #
    mac=`ip address show ${ifname} | grep link | awk -F ' ' '{print $2}'`
    [ -z "${mac}" ] && return 0
    #
    time=`date +"%Y-%m-%d %H:%M:%S"`
    #
    tmpfile="/tmp/.xy-post.log"
    #
    data='{"id":1003,"user":"'${userName}'","mac":"'${mac}'","data":{"type":5,"account":"'${userName}'","model":"'${RouteName}'","guid":"","mac":"'${mac}'","crashdll":"'${process}'","reporttime":"'${time}'"}}'
    echo ${data} > ${tmpfile}
    #
    ${XunyouPath}/bin/${UdpPostProc} -d "acceldata.xunyou.com" -p 9240 -f ${tmpfile} &
}

xunyou_acc_check()
{
    [ "${xunyou_enable}" != "1" ] && return 0
    #
    devicePid=`ps | grep -v grep | grep -w ${DeviceProc} | awk -F ' ' '{print $1}'`
    ctrlPid=`ps | grep -v grep | grep -w ${CtrlProc} | awk -F ' ' '{print $1}'`
    proxyPid=`ps | grep -v grep | grep -w ${ProxyProc} | awk -F ' ' '{print $1}'`
    ipsetPid=`ps | grep -v grep | grep -w ${IpsetProc} | awk -F ' ' '{print $1}'`
    #
    [ -f ${IpsetEnableCfg} ] || xunyou_acc_install
    IpsetEnable=`cat ${IpsetEnableCfg}`
    #
    if [ ${IpsetEnable} == "1" ]; then
        [[ -n "${ctrlPid}" && -n "${proxyPid}" && -n "${devicePid}" && -n "${ipsetPid}" ]] && return 0
    else
        [[ -n "${ctrlPid}" && -n "${proxyPid}" && -n "${devicePid}" ]] && return 0
    fi
    #
    xunyou_acc_stop
    xunyou_acc_start
    #
}

case $1 in
    install)
        xunyou_acc_install
        ;;

    uninstall)
        xunyou_acc_uninstall
        ;;

    start)
        if [ "${xunyou_enable}" == "1" ];then
            log "[start]: 启动迅游模块！"
            xunyou_acc_stop
            xunyou_acc_start
        else
            log "[start]: 未设置开机启动，跳过！"
        fi
        ;;

    stop)
        log "[stop] 停止加速进程"
        xunyou_acc_uninstall
        ;;

    check)
        xunyou_acc_check
        ;;

    app)
        log "[app]: 启动迅游模块！"
        xunyou_acc_install
        xunyou_acc_stop
        xunyou_acc_start
        ;;

    *)
        http_response "$1"
        #
        if [ "${xunyou_enable}" == "1" ];then
            log "[default]: 启动迅游模块！"
            xunyou_acc_install
            xunyou_acc_stop
            xunyou_acc_start
        else
            log "[default]: 停止迅游模块！"
            xunyou_acc_stop
        fi
        ;;
esac

exit 0

