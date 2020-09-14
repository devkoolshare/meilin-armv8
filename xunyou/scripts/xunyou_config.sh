#!/bin/sh

source /etc/profile

if [ -d "/jffs/.koolshare" ];then
    source /koolshare/scripts/base.sh
    eval `dbus export xunyou`
    xunyouPath="/jffs/.koolshare"
    #
    [ "${1}" == "app" ] && dbus set xunyou_enable=1 && xunyou_enable="1"
else
    xunyou_enable="1"
    xunyouPath="/jffs"
    [ ! -d "/jffs" ] && exit 1
fi

module="xunyou_acc"
ifname="br0"
BasePath="${xunyouPath}/xunyou"
RouteCfg="${BasePath}/config/RouteCfg.conf"
ProxyCfg="${BasePath}/config/ProxyCfg.conf"
UserInfo="${xunyouPath}/configs/xunyou-user"
ProxyCfgPort="29595"
RoutePort="28099"
RouteLog="/var/log/xunyou-ctrl.log"
ProxyLog="/var/log/xunyou-proxy.log"
ProxyScripte="${BasePath}/scripts/xunyou_rule.sh"
UpdateScripte="${BasePath}/scripts/xunyou_upgrade.sh"
CfgScripte="${BasePath}/scripts/xunyou_config.sh"
DevType="${BasePath}/scripts/xunyou_dev.sh"
LibPath="${BasePath}/lib/"
RCtrProc="xy-ctrl"
ProxyProc="xy-proxy"
DevTypeProc="xy-devInfo"
UdpPostProc="udp-post"
logPath="/var/log/xunyou-install.log"
DnsCfgPath="/jffs/configs/dnsmasq.d"
DnsConfig="${BasePath}/config/xunyou.conf"
iptName="XUNYOU"
iptAccName="XUNYOUACC"
rtName="95"
kernelKoPath="${BasePath}/modules"
#
domain="router-lan.xyrouterqpm3v2bi.cc"
match="|0a|router-lan|10|xyrouterqpm3v2bi|02|cc"
domainHex="0a726f757465722d6c616e107879726f7574657271706d3376326269026363"

log()
{
    echo [`date +"%Y-%m-%d %H:%M:%S"`] "${1}" >> ${logPath}
}

iptables_rule_cfg()
{
    gateway=`ip address show ${ifname} | grep "\<inet\>" | awk -F ' ' '{print $2}' | awk -F '/' '{print $1}'`
    [ -z "${gateway}" ] && return 1
    #
    ret=`iptables -t mangle -S | grep "\<${iptName}\>"`
    [ -z "${ret}" ] && iptables -t mangle -N ${iptName}
    ret=`iptables -t mangle -S PREROUTING | grep "\<${iptName}\>"`
    if [ -z "${ret}" ];then
        iptables -t mangle -F ${iptName}
        iptables -t mangle -I PREROUTING -i ${ifname} -p udp -m comment --comment "KOOLPROXY" -j ${iptName}
    fi
    #
    ret=`iptables -t nat -S | grep "\<${iptName}\>"`
    [ -z "${ret}" ] && iptables -t nat -N ${iptName}
    ret=`iptables -t nat -S PREROUTING | grep "\<${iptName}\>"`
    if [ -z "${ret}" ];then
        iptables -t nat -F ${iptName}
        iptables -t nat -I PREROUTING -i ${ifname} -m comment --comment "KOOLPROXY" -j ${iptName}
    fi
    #
    ret=`iptables -t nat -S "${iptName}" | grep "\-d ${gateway}"`
    [ -z "${ret}" ] && iptables -t nat -I ${iptName} -d ${gateway} -j ACCEPT
    ret=`iptables -t mangle -S "${iptName}" | grep "\-d ${gateway}"`
    [ -z "${ret}" ] && iptables -t mangle -I ${iptName} -d ${gateway} -j ACCEPT
    #
    ret=`iptables -t nat -S | grep "${iptAccName}"`
    [ -z "${ret}" ] && iptables -t nat -N ${iptAccName}
    ret=`iptables -t mangle -S | grep "${iptAccName}"`
    [ -z "${ret}" ] && iptables -t mangle -N ${iptAccName}
    #
    ret=`iptables -t mangle -S ${iptName} | grep "${domainHex}"`
    [ -z "${ret}" ] && iptables -t mangle -A ${iptName} -i ${ifname} -p udp --dport 53 -m string --hex-string "${match}" --algo kmp -j ACCEPT
    #
    ret=`iptables -t nat -S ${iptName} | grep "${domainHex}"`
    [ -z "${ret}" ] && iptables -t nat -A ${iptName} -i ${ifname} -p udp --dport 53 -m string --hex-string "${match}" --algo kmp -j DNAT --to-destination ${gateway}
    #
    ret=`iptables -t nat -S ${iptName} | grep "${iptAccName}"`
    [ -z "${ret}" ] && iptables -t nat -A ${iptName} -p tcp -j ${iptAccName}
    #
    ret=`iptables -t mangle -S ${iptName} | grep "${iptAccName}"`
    [ -z "${ret}" ] && iptables -t mangle -A ${iptName} -p udp -j ${iptAccName}
    #
    ret=`iptables -t nat -S PREROUTING | sed -n '2p' | grep ${iptName}`
    if [ -z "${ret}" ];then
        ret=`iptables -t nat -S PREROUTING | grep ${iptName}`
        [ -n "${ret}" ] && value=`echo ${ret#*A}` && iptables -t nat -D ${value}
        iptables -t nat -I PREROUTING -i ${ifname} -m comment --comment "KOOLPROXY" -j ${iptName}
    fi
    #
    ret=`iptables -t mangle -S PREROUTING | sed -n '2p' | grep ${iptName}`
    if [ -z "${ret}" ];then
        ret=`iptables -t mangle -S PREROUTING | grep ${iptName}`
        [ -n "${ret}" ] && value=`echo ${ret#*A}` && iptables -t mangle -D ${value}
        iptables -t mangle -I PREROUTING -i ${ifname} -p udp -m comment --comment "KOOLPROXY" -j ${iptName}
    fi
}

set_dnsmasq_config()
{
    #
    ret=`cat /etc/dnsmasq.conf | grep "conf-dir"`
    if [ -n "${ret}" ];then
        #
        ret=`dbus get dhcp_dns1_x`
        [ -z "${ret}" ] && dbus set dhcp_dns1_x=223.6.6.6
        #
        [ -e "${DnsCfgPath}/xunyou.conf"] && return 0
        #
        gateway=`ip address show ${ifname} | grep "\<inet\>" | awk -F ' ' '{print $2}' | awk -F '/' '{print $1}'`
        [ -z "${gateway}" ] && return 1
        #
        echo "address=/${domain}/${gateway}" > ${DnsConfig}
        rm -rf ${DnsCfgPath}/xunyou.conf
        cp -rf ${DnsConfig} ${DnsCfgPath}/
    else
        ret=`cat /etc/hosts | grep "${domain}"`
        [ -n "${ret}" ] && return 0
        nvram set lan_hostname="router-lan"
        nvram set lan_domain="xyrouterqpm3v2bi.cc"
    fi
    service restart_dnsmasq >/dev/null 2>&1
}

create_config_file()
{
    gateway=`ip address show ${ifname} | grep "\<inet\>" | awk -F ' ' '{print $2}' | awk -F '/' '{print $1}'`
    mac=`ip address show ${ifname} | grep link | awk -F ' ' '{print $2}'`
    [[ -z "${gateway}" || -z "${mac}" ]] && return 1
    #
    RouteName=`nvram get odmpid`
    [ -z "${RouteName}" ] && RouteName=`nvram get productid`
    #
    flag=`netstat -an | grep ${ProxyCfgPort}`
    [ -n "${flag}" ] && ProxyCfgPort="39595"
    flag=`netstat -an | grep ${RoutePort}`
    [ -n "${flag}" ] && RoutePort="28090"
    #
    sed -i 's/\("httpd-svr":"\).*/\1'${gateway}'",/g' ${RouteCfg}
    sed -i 's/\("route-mac":"\).*/\1'${mac}'",/g'     ${RouteCfg}
    sed -i 's#\("log":"\).*#\1'${RouteLog}'",#g'      ${RouteCfg}
    sed -i 's/\("net-device":"\).*/\1'${ifname}'",/g'              ${RouteCfg}
    sed -i 's/\("route-name":"\).*/\1'${RouteName}'",/g'           ${RouteCfg}
    sed -i 's/\("proxy-manage-port":\).*/\1'${ProxyCfgPort}',/g'   ${RouteCfg}
    sed -i 's/\("local-port":\).*/\1'${RoutePort}',/g'             ${RouteCfg}
    sed -i 's#\("dev-shell":"\).*#\1'${DevType}'",#g'              ${RouteCfg}
    sed -i 's#\("upgrade-shell":"\).*#\1'${UpdateScripte}'",#g'    ${RouteCfg}
    sed -i 's#\("user-info":"\).*#\1'${UserInfo}'",#g'             ${RouteCfg}
    #
    sed -i 's/\("local-ip":"\).*/\1'${gateway}'",/g'        ${ProxyCfg}
    sed -i 's/\("manage":\).*/\1'${ProxyCfgPort}',/g'       ${ProxyCfg}
    sed -i 's#\("log":"\).*#\1'${ProxyLog}'",#g'            ${ProxyCfg}
    sed -i 's#\("script-cfg":"\).*#\1'${ProxyScripte}'",#g' ${ProxyCfg}
}

rule_init()
{
    #
    flag=`lsmod | grep xt_comment`
    [ -z "${flag}" ] && insmod xt_comment
    #
    flag=`lsmod | grep xt_TPROXY`
    [ -z "${flag}" ] && insmod xt_TPROXY
    #
    flag=`lsmod | grep ip_set`
    kernel_version=`uname -r`
    if [ -z "${flag}" ];then
        ret=`find /lib/modules/ -name "ip_set.ko"`
        [ -n "${ret}" ] && insmod ip_set
        [ -z "${ret}" ] && [ -d ${kernelKoPath}/${kernel_version}/ ] && insmod ${kernelKoPath}/${kernel_version}/kernel/ip_set.ko
    fi
    #
    flag=`lsmod | grep ip_set_hash_netport`
    if [ -z "${flag}" ];then
        ret=`find /lib/modules/ -name "ip_set_hash_netport.ko"`
        [ -n "${ret}" ] && insmod ip_set_hash_netport
        [ -z "${ret}" ] && [ -d ${kernelKoPath}/${kernel_version}/ ] && insmod ${kernelKoPath}/${kernel_version}/kernel/ip_set_hash_netport.ko
    fi
    #
    flag=`which ipset`
    if [ -z "${flag}" ];then
        mkdir -p /tmp/opt/usr/bin/
        [ -d ${kernelKoPath}/${kernel_version}/ ] && ln -sf ${kernelKoPath}/${kernel_version}/bin/ipset /tmp/opt/usr/bin/ipset
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
    [ -e "${BasePath}/uninstall.sh" ] && ln -sf ${BasePath}/uninstall.sh /tmp/xunyou_uninstall.sh
}

xunyou_acc_start()
{
    xunyou_set_time
    xunyou_set_link
    #
    set_dnsmasq_config
    #
    rule_init
    #
    iptables_rule_cfg
    #
    create_config_file
    #
    ret=`export LD_LIBRARY_PATH | grep ${LibPath}`
    [ -z "${ret}" ] && export LD_LIBRARY_PATH=${LibPath}:$LD_LIBRARY_PATH
    ulimit -n 2048
    #
    ret=`ps | grep -v grep | grep nvram`
    [ -n "${ret}" ] && killall nvram >/dev/null 2>&1
    #
    mv ${RouteLog}* /tmp/  >/dev/null 2>&1
    mv ${ProxyLog}* /tmp/  >/dev/null 2>&1
    #
    ${BasePath}/bin/${RCtrProc}  --config ${RouteCfg} &
    ${BasePath}/bin/${ProxyProc} --config ${ProxyCfg} &
    ${BasePath}/bin/${DevTypeProc} &
}

xunyou_acc_install()
{
    [ ! -d ${xunyouPath}/configs ] && mkdir -p ${xunyouPath}/configs
    #
    ret=`cru l | grep "${module}"`
    [ -z "${ret}" ] && cru a ${module} "*/1 * * * * ${CfgScripte} check"
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
    ctrlPid=$(echo -n `ps | grep -v grep | grep -w ${RCtrProc} | awk -F ' ' '{print $1}'`)
    [ -n "${ctrlPid}" ] && kill -10 ${ctrlPid}
    proxyPid=$(echo -n `ps | grep -v grep | grep -w ${ProxyProc} | awk -F ' ' '{print $1}'`)
    [ -n "${proxyPid}" ] && kill -9 ${proxyPid}
    devPid=$(echo -n `ps | grep -v grep | grep -w ${DevTypeProc} | awk -F ' ' '{print $1}'`)
    [ -n "${proxyPid}" ] && kill -9 ${devPid}
    #
    devPid=$(echo -n `ps | grep -v grep | grep -w ${DevTypeProc} | awk -F ' ' '{print $1}'`)
    [ -n "${proxyPid}" ] && killall ${DevTypeProc}
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
}

xunyou_check_rule()
{
    #
    set_dnsmasq_config
    #
    ret=`ps | grep -v grep | grep dnsmasq`
    [ -z "${ret}" ] && service restart_dnsmasq >/dev/null 2>&1
    #
    xunyou_set_time
    xunyou_set_link
    #
    iptables_rule_cfg
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
    [ ! -e "${BasePath}/bin/${UdpPostProc}" ] && return 0
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
    ${BasePath}/bin/${UdpPostProc} -d "acceldata.xunyou.com" -p 9240 -f ${tmpfile} &
}

xunyou_acc_check()
{
    [ "${xunyou_enable}" != "1" ] && return 0
    #
    xunyou_check_rule
    #
    devPid=`ps | grep -v grep | grep -w ${DevTypeProc} | awk -F ' ' '{print $1}'`
    ctrlPid=`ps | grep -v grep | grep -w ${RCtrProc} | awk -F ' ' '{print $1}'`
    proxyPid=`ps | grep -v grep | grep -w ${ProxyProc} | awk -F ' ' '{print $1}'`
    #
    if [[ -z "${devPid}" ]] && [[ -n "${ctrlPid}" && -n "${proxyPid}" ]];then
        ret=`export LD_LIBRARY_PATH | grep ${LibPath}`
        [ -z "${ret}" ] && export LD_LIBRARY_PATH=${LibPath}:$LD_LIBRARY_PATH
        ${BasePath}/bin/${DevTypeProc} &
    fi
    #
    [ -z "${devPid}" ] && xunyou_post_log "xy-devInfo" && log "[check] 重启 xy-devInfo 进程！"
    #
    [[ -n "${ctrlPid}" && -n "${proxyPid}" ]] && return 0
    #
    [ -z "${ctrlPid}" ] && xunyou_post_log "xy-ctrl" && log "[check] 重启 xy-ctrl 进程！"
    [ -z "${proxyPid}" ] && xunyou_post_log "xy-proxy" && log "[check] 重启 xy-proxy 进程！"
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

