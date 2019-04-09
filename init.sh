#!/bin/bash

CONFIG_PATH="/etc/ss-tproxy"
function check-env {
  if [ ! -f /usr/local/bin/ss-tproxy -o ! -f /v2ray/v2ray -o ! -f /koolproxy/koolproxy  -o ! -f /sample_config/ss-tproxy.conf -o ! -f /sample_config/v2ray.conf -o ! -f /sample_config/gfwlist.ext ]; then
    /update.sh || echo "[ERR] Can't update, please check networking or update the container. "
  fi
  return 0
}

function check-config {
  NEED_EXIT="false"
  # 若没有配置文件，拷贝配置文件模版
  if [ ! -f "$CONFIG_PATH"/ss-tproxy.conf ]; then
    cp /sample_config/ss-tproxy.conf "$CONFIG_PATH"
    echo "[ERR] No ss-tproxy.conf, sample file copied, please configure it."
    NEED_EXIT="true"
  fi
  if [ ! -f "$CONFIG_PATH"/v2ray.conf ]; then
    cp /sample_config/v2ray.conf "$CONFIG_PATH"
    echo "[ERR] No v2ray.conf, sample file copied, please configure it."
    NEED_EXIT="true"
  fi
  if [ ! -f "$CONFIG_PATH"/gfwlist.ext ]; then
    cp /sample_config/gfwlist.ext "$CONFIG_PATH"
  fi
  if [ "$NEED_EXIT" = "true" ]; then
    exit 1;
  fi
  # touch 空配置文件
  source "$CONFIG_PATH"/ss-tproxy.conf
  [ ! -f "$file_gfwlist_txt" ] && touch $file_gfwlist_txt
  [ ! -f "$file_chnroute_txt" ] && touch $file_chnroute_txt
  [ ! -f "$file_chnroute_set" ] && touch $file_chnroute_set
  [ ! -f "$dnsmasq_addn_hosts" ] && touch $dnsmasq_addn_hosts
  return 0
}

function stop-ss-tproxy {
  # 更新之前，停止 ss-tproxy
  echo "`date +%Y-%m-%d\ %T` stopping tproxy-gateway.."
  /usr/local/bin/ss-tproxy stop && return 0
}

function update-ss-config {
  # 更新 ss-tproxy 配置
  if [ "$mode" = chnroute ]; then
    echo "`date +%Y-%m-%d\ %T` updating chnroute.."
    /usr/local/bin/ss-tproxy update-chnroute
  elif [ "$mode" = gfwlist ]; then
    echo "`date +%Y-%m-%d\ %T` updating gfwlist.."
    /usr/local/bin/ss-tproxy update-gfwlist
  elif [ "$mode" = chnonly ]; then
    echo "`date +%Y-%m-%d\ %T` updating chnonly.."
    /usr/local/bin/ss-tproxy update-chnonly
  fi && \
  return 0
}

function flush-ss-tproxy {
  # 清除 iptables
  echo "`date +%Y-%m-%d\ %T` flushing iptables.."
  /usr/local/bin/ss-tproxy flush-iptables
  # 清除 gfwlist
  echo "`date +%Y-%m-%d\ %T` flushing gfwlist.."
  /usr/local/bin/ss-tproxy flush-gfwlist
  # 清除 dns cache
  echo "`date +%Y-%m-%d\ %T` flushing dnscache.."
  /usr/local/bin/ss-tproxy flush-dnscache
  return 0
}

function set-cron {
  # 停止 crond
  cron_pid="`pidof crond`"
  if [ -n "$cron_pid" ]; then
    kill -9 "$cron_pid" &> /dev/null
  fi
  # 若 /etc/crontabs/root 存在 '/init.sh' 则启动 crond
  grep -n '^[^#]*/init.sh' /etc/crontabs/root && crond
  return 0
}

function start-ss-tproxy {
  # 启动 ss-tproxy
  echo "`date +%Y-%m-%d\ %T` staring tproxy-gateway.."
  /usr/local/bin/ss-tproxy start && return 0
}

check-env && check-config && stop-ss-tproxy && update-ss-config && flush-ss-tproxy && set-cron && start-ss-tproxy && \
echo -e "IPv4 gateway & dns server: \n`ip addr show eth0 |grep 'inet ' | awk '{print $2}' |sed 's/\/.*//g'`" && \
echo -e "IPv6 dns server: \n`ip addr show eth0 |grep 'inet6 ' | awk '{print $2}' |sed 's/\/.*//g'`" || echo "[ERR] Start tproxy-gateway failed."
if [ "$1" = daemon ]; then
  tail -f /dev/null
fi