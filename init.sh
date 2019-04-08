#!/bin/bash

if [ ! -f /version ]; then
  /update.sh
fi

CONFIG_PATH='/etc/ss-tproxy'
NEED_EXIT=0
# 若没有配置文件，拷贝配置文件模版
[ ! -f "$CONFIG_PATH"/ss-tproxy.conf ] && { cp /sample_config/ss-tproxy.conf "$CONFIG_PATH"; echo "[ERR] No ss-tproxy.conf, sample file copied, please configure it."  1>&2; NEED_EXIT=1; }
[ ! -f "$CONFIG_PATH"/v2ray.conf ] && { cp /sample_config/v2ray.conf "$CONFIG_PATH"; echo "[ERR] no v2ray.conf, sample file copied, please configure it."  1>&2; NEED_EXIT=1; }
[ ! -f "$CONFIG_PATH"/gfwlist.ext ] && { cp /sample_config/gfwlist.ext "$CONFIG_PATH"; }
if [ "$NEED_EXIT" = 1 ]; then
  exit 1;
fi

# touch 空配置文件
source "$CONFIG_PATH"/ss-tproxy.conf
[ ! -f "$file_gfwlist_txt" ] && touch $file_gfwlist_txt
[ ! -f "$file_chnroute_txt" ] && touch $file_chnroute_txt
[ ! -f "$file_chnroute_set" ] && touch $file_chnroute_set
[ ! -f "$dnsmasq_addn_hosts" ] && touch $dnsmasq_addn_hosts

# 更新之前，停止 ss-tproxy
echo "`date +%Y-%m-%d\ %T` stopping tproxy-gateway.."
/usr/local/bin/ss-tproxy stop
# 更新 ss-tproxy 配置
if [ "$mode" = chnroute ]; then
  echo "`date +%Y-%m-%d\ %T` updating chnroute.."
  /usr/local/bin/ss-tproxy update-chnroute
fi
if [ "$mode" = gfwlist ]; then
  echo "`date +%Y-%m-%d\ %T` updating gfwlist.."
  /usr/local/bin/ss-tproxy update-gfwlist
fi
if [ "$mode" = chnonly ]; then
  echo "`date +%Y-%m-%d\ %T` updating chnonly.."
  /usr/local/bin/ss-tproxy update-chnonly
fi
# 清除 iptables
echo "`date +%Y-%m-%d\ %T` flushing iptables.."
/usr/local/bin/ss-tproxy flush-iptables
# 清除 gfwlist
echo "`date +%Y-%m-%d\ %T` flushing gfwlist.."
/usr/local/bin/ss-tproxy flush-gfwlist
# 清除 dns cache
echo "`date +%Y-%m-%d\ %T` flushing dnscache.."
/usr/local/bin/ss-tproxy flush-dnscache
# 停止 crond
kill -9 $(pidof crond) & > /dev/null
# 若 /etc/crontabs/root 存在 '/init.sh' 则启动 crond
grep -n '^[^#]*/init.sh' /etc/crontabs/root && crond
# 启动 ss-tproxy
echo "`date +%Y-%m-%d\ %T` staring tproxy-gateway.."
/usr/local/bin/ss-tproxy start && \
echo -e "IPv4 gateway & dns server: \n`ip addr show eth0 |grep 'inet ' | awk '{print $2}' |sed 's/\/.*//g'`" && \
echo -e "IPv6 dns server: \n`ip addr show eth0 |grep 'inet6 ' | awk '{print $2}' |sed 's/\/.*//g'`"
if [ "$1" = daemon ]; then
  tail -f /dev/null
fi