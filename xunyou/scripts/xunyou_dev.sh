#!/bin/sh

ifName="br0"
dnsmasqFile="/var/lib/misc/dnsmasq.leases"
nfPath="/proc/net/nf_conntrack"
logPath="/var/log/xunyou-install.log"
outDevPath="/tmp/xunyou-dev.info"

log()
{
    echo [`date +"%Y-%m-%d %H:%M:%S"`] "${1}" >> ${logPath}
}

#
[ ! -e "${dnsmasqFile}" ] && log "${dnsmasqFile} 不存在！" && exit 1
[ ! -e "${nfPath}" ] && log "${nfPath} 不存在！" && exit 1
ret=`ip address show ${ifName} 2>/dev/null`
[ -z "${ret}" ] && log "${ifName} 不存在！" && bexit 1

#
echo -n > ${outDevPath}

#
cat /proc/net/arp | grep -v grep | grep "\<${ifName}\>" | grep "\<0x2\>" | while read line
do
    #
    ip=`echo "${line}" | awk -F ' ' '{print $1}'`
    mac=`echo "${line}" | awk -F ' ' '{print $4}'`
    #
    [[ -z "${ip}" || -z "${mac}" ]] && continue
    #
    #echo "ip=${ip}, mac=${mac}"
    devName=`cat ${dnsmasqFile} | grep -v grep | grep "\<${ip}\>" | awk -F ' '  '{print $4}'`
    [ -z "${devName}" ] && devName="UNKOWN"
    #
    ret=`cat ${nfPath} | grep -v grep | grep "\<${ip}\>" | wc -l`
    [ ${ret} -eq 0 ] && continue
    #
    echo "${ip} ${mac} ${devName}" >> ${outDevPath}
done
