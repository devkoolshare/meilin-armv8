#!/bin/sh

if [ -d "/koolshare" ];then
    BasePath="/koolshare"
else
    [ ! -d "/jffs" ] && exit 1
    BasePath="/jffs"
fi

XunyouPath="${BasePath}/xunyou"

ifName="br0"
dnsmasqCfgFile="/etc/dnsmasq.conf"
nfPath="/proc/net/nf_conntrack"
logPath="${XunyouPath}/log/xunyou-install.log"

log()
{
    echo [`date +"%Y-%m-%d %H:%M:%S"`] "${1}" >> ${logPath}
}

[ ! -e "${dnsmasqCfgFile}" ] && log "${dnsmasqCfgFile} 不存在！" && exit 1
[ ! -e "${nfPath}" ] && log "${nfPath} 不存在！" && exit 1

dhcpLeaseFile=`awk -F "=" '$1=="dhcp-leasefile" {print $2}' ${dnsmasqCfgFile}`
[ ! -e "${dhcpLeaseFile}" ] && dhcpLeaseFile="/var/lib/misc/dnsmasq.leases"
[ ! -e "${dhcpLeaseFile}" ] && log "${dhcpLeaseFile} 不存在！" && exit 1

ret=`ip address show ${ifName} 2>/dev/null`
[ -z "${ret}" ] && log "${ifName} 不存在！" && exit 1
#
awk -F ' ' '$3=="0x2" && $6=="'${ifName}'" {print $1, $4}' /proc/net/arp | while read line
do
    #
    ip=`echo "${line}" | awk -F ' ' '{print $1}'`
    mac=`echo "${line}" | awk -F ' ' '{print $2}'`
    #
    [[ -z "${ip}" || -z "${mac}" ]] && continue
    #
    devName=`awk -F ' ' '$2=="'${mac}'" && $3=="'${ip}'" {print $4}' ${dhcpLeaseFile}`
    [ -z "${devName}" ] && devName="UNKOWN"
    #
    count=`grep -c ${ip} ${nfPath}`
    [ ${count} -eq 0 ] && continue
    #
    echo "${ip} ${mac} ${devName}"
done
