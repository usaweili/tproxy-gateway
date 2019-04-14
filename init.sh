#!/bin/bash

CONFIG_PATH="/etc/ss-tproxy"
function check-env {
  if [ ! -f /usr/local/bin/ss-tproxy -o ! -f /v2ray/v2ray -o ! -f /koolproxy/koolproxy  -o ! -f /sample_config/ss-tproxy.conf -o ! -f /sample_config/v2ray.conf -o ! -f /sample_config/gfwlist.ext ]; then
    /update.sh && { $0 $@; exit 0; } || echo "[ERR] Can't update, please check networking or update the container. "
  fi; \
  return 0
}

function resolve_URI {
  echo "$(date +%Y-%m-%d\ %T) Resolving proxy URI.."

  if [ $(stat -c %Y ${CONFIG_PATH}/ss-tproxy.conf) -lt $(stat -c %Y ${CONFIG_PATH}/v2ray.conf) -a -n "$(/v2ray/v2ray -test -config ${CONFIG_PATH}/v2ray.conf | grep 'Configuration OK')" ]; then
    echo "$(date +%Y-%m-%d\ %T) v2ray.conf is the latest, NO need to resolve."
    return 0
  fi

  # base64 解码 URI
  proxy_vmess_config=$(echo $proxy_uri | grep 'vmess://' | sed 's/vmess:\/\///g' | base64 -d | jq . || { echo "[ERR] Proxy URI error, can't decode!" exit 1; })

  if [ -n "$proxy_vmess_config" ]; then
      proxy_vmess_add=$(echo "$proxy_vmess_config"  | jq .add)
      sed -i 's/proxy_server=.*/proxy_server=('$(echo $proxy_vmess_add | cut -d\" -f2)')/'  $CONFIG_PATH/ss-tproxy.conf
      proxy_vmess_port=$(echo "$proxy_vmess_config" | jq .port | cut -d\" -f2)
      proxy_vmess_id=$(echo "$proxy_vmess_config"   | jq .id)
      proxy_vmess_aid=$(echo "$proxy_vmess_config"  | jq .aid | cut -d\" -f2)
      proxy_vmess_net=$(echo "$proxy_vmess_config"  | jq .net)
      proxy_vmess_type=$(echo "$proxy_vmess_config" | jq .type)
      proxy_vmess_host=$(echo "$proxy_vmess_config" | jq .host)
      proxy_vmess_path=$(echo "$proxy_vmess_config" | jq .path)
      proxy_vmess_tls=$(echo "$proxy_vmess_config"  | jq .tls)

      ## outBounds 设置
      out_set='{"vnext":[{"address":'${proxy_vmess_add}',"port":'${proxy_vmess_port}',"users":[{"id":'${proxy_vmess_id}',"security":"auto","alterId": '${proxy_vmess_aid}'}]}]}'
      out_stream='{"network":'${proxy_vmess_net}',"security":"none"}'

      if [ "$proxy_vmess_net" == '"tcp"' ]; then
        out_stream=$(echo $out_stream | jq '. | {network, security, "tcpSettings":{}}')
      elif [ "$proxy_vmess_net" == '"kcp"' ]; then
        out_stream=$(echo $out_stream | jq '. | {network, security, "kcpSettings":{}}')
      elif [ "$proxy_vmess_net" == '"ws"' ]; then
        out_stream=$(echo $out_stream | jq '. | {network, security, "wsSettings":{"path":'${proxy_vmess_path}'}}')
      elif [ "$proxy_vmess_net" == '"http"' ]; then
        out_stream=$(echo $out_stream | jq '. | {network, security, "httpSettings":{"path":'${proxy_vmess_path}',"host":'${$proxy_vmess_host}'}}')
      elif [ "$proxy_vmess_net" == '"quic"' ]; then
        out_stream=$(echo $out_stream | jq '. | {network, security, "quicSettings":{"security":'${proxy_vmess_host}',"key":'${proxy_vmess_path}',"header":{"type": "none"}}}')
      fi
      if [ "$proxy_vmess_tls" == '"tls"' ]; then
        if [ "$proxy_vmess_host" == '""' ]; then 
          proxy_vmess_host="null"
        fi
        out_stream=$(echo "$out_stream" | jq '. += {"tlsSettings":{"allowInsecure":true,"serverName":'${proxy_vmess_host}'}} | to_entries | map(if .key == "security" then . + {"value":"tls"} else . end ) | from_entries')
      fi
      outbound='[{"protocol":"vmess","settings":'${out_set}',"tag": "out-0","streamSettings":'${out_stream}'}]'

      ## inBounds 设置
      if [ "$proxy_tproxy" == 'true' ]; then
        proxy_vmess_tproxy='"tproxy"'
      else
        proxy_vmess_tproxy='"redirect"'
      fi
      if [ "$(echo "$proxy_tcport"|[ -n "`sed -n '/^[0-9][0-9]*$/p'`" ])" ]; then
        proxy_tcport=60080
        sed -i 's/proxy_tcport=.*/proxy_tcport=60080/'  $CONFIG_PATH/ss-tproxy.conf
      fi
      if [ "$(echo "$proxy_udport"|[ -n "`sed -n '/^[0-9][0-9]*$/p'`" ])" ]; then
        proxy_duport=60080
        sed -i 's/proxy_udport=.*/proxy_udport=60080/'  $CONFIG_PATH/ss-tproxy.conf
      fi
      in_stream='{"sockopt":{"mark":0,"tcpFastOpen":true,"tproxy":'${proxy_vmess_tproxy}'}}'

      if [ "$proxy_tcport" != "$proxy_udport" ]; then
        inbound='[{"protocol":"dokodemo-door","listen":"0.0.0.0","port":'${proxy_tcport}',"settings":{"network": "tcp","followRedirect":true },"streamSettings":'${in_stream}'},[{"protocol":"dokodemo-door","listen":"0.0.0.0","port":'${proxy_udport}',"settings":{"network": "udp","followRedirect":true },"streamSettings":'${in_stream}'}]'
      else
        inbound='[{"protocol":"dokodemo-door","listen":"0.0.0.0","port":'${proxy_tcport}',"settings":{"network": "tcp,udp","followRedirect":true },"streamSettings":'${in_stream}'}]'
      fi
      ## v2ray 日志
      v_log='{"loglevel": "warning","error": "/var/log/v2ray-error.log","access": "/var/log/v2ray-access.log"}'

      v2ray_config=$(echo '{"log":'${v_log}',"dns":{},"stats":{},"inbounds":'${inbound}',"outbounds":'${outbound}',"routing":{},"policy":{},"reverse":{},"transport":{}}' | jq .)

      echo $v2ray_config | jq . > "/tmp/v2ray.conf"
      if [ -n "$(/v2ray/v2ray -test -config /tmp/v2ray.conf | grep 'Configuration OK')" ]; then
        echo "V2ray.conf resolve succeed !!"
        mv /tmp/v2ray.conf "$CONFIG_PATH/v2ray.conf"
      else
        echo "[ERR] V2ray.conf resolvefailed.."
        exit 1
      fi
  fi
}

function check-config {
  NEED_EXIT="false"
  # 若没有配置文件，拷贝配置文件模版
  if [ ! -f "$CONFIG_PATH"/ss-tproxy.conf ]; then
    cp /sample_config/ss-tproxy.conf "$CONFIG_PATH"
    echo "[ERR] No ss-tproxy.conf, sample file copied, please configure it."
    NEED_EXIT="true"
  fi; \
  # if [ ! -f "$CONFIG_PATH"/v2ray.conf ]; then
  #   cp /sample_config/v2ray.conf "$CONFIG_PATH"
  #   echo "[ERR] No v2ray.conf, sample file copied, please configure it."
  #   NEED_EXIT="true"
  # fi; \
  if [ "$NEED_EXIT" = "true" ]; then
    exit 1;
  fi; \
  # touch 空配置文件
  source "$CONFIG_PATH"/ss-tproxy.conf
  if [ ! -f "$file_gfwlist_ext" ]; then
    cp /sample_config/gfwlist.ext "$file_gfwlist_ext"
  fi; \
  [ ! -f "$file_gfwlist_txt" ] && touch $file_gfwlist_txt; \
  [ ! -f "$file_chnroute_txt" ] && touch $file_chnroute_txt; \
  [ ! -f "$file_chnroute_set" ] && touch $file_chnroute_set; \
  [ ! -f "$dnsmasq_addn_hosts" ] && touch $dnsmasq_addn_hosts; \
  return 0
}

function stop-ss-tproxy {
  # 更新之前，停止 ss-tproxy
  echo "$(date +%Y-%m-%d\ %T) stopping tproxy-gateway.."; \
  /usr/local/bin/ss-tproxy stop && return 0
}

function update-ss-config {
  # 更新 ss-tproxy 规则
  if [ "$mode" = chnroute ]; then
    proxy_mode="$mode"
    proxy_rule_latest_url="https://api.github.com/repos/17mon/china_ip_list/commits/master"
    proxy_rule_file="$file_chnroute_txt"
  elif [ "$mode" = gfwlist -a "$mode_chnonly" = 'true' ]; then
    proxy_mode="chnonly"
    proxy_rule_latest_url="https://api.github.com/repos/17mon/china_ip_list/commits/master"
    proxy_rule_file="$file_gfwlist_txt"
  elif [ "$mode" = gfwlist ]; then
    proxy_mode="$mode"
    proxy_rule_latest_url="https://api.github.com/repos/gfwlist/gfwlist/commits/master"
    proxy_rule_file="$file_gfwlist_txt"
  fi; \
  echo "$(date +%Y-%m-%d\ %T) updating $proxy_mode.."
  if [ -s "$proxy_rule_file" ]; then #不空
    proxy_rule_latest=$(curl -H 'Cache-Control: no-cache' -s "$proxy_rule_latest_url" | grep '"date": ' | awk 'NR==1{print $2}' | sed 's/"//g; s/T/ /; s/Z//' | xargs -I{} date -u -d {} +%s); \
    proxy_rule_current=$(stat -c %Y $proxy_rule_file);
    if [ "$proxy_rule_latest" -gt "$proxy_rule_current" ]; then
          /usr/local/bin/ss-tproxy update-"$proxy_mode"
    else
          echo "$(date +%Y-%m-%d\ %T) $proxy_mode rule is latest, NO need to update."
    fi
  else # 空文件
    /usr/local/bin/ss-tproxy update-"$proxy_mode"
  fi
  return 0
}

function flush-ss-tproxy {
  # 清除 iptables
  echo "$(date +%Y-%m-%d\ %T) flushing iptables.."; \
  /usr/local/bin/ss-tproxy flush-iptables; \
  # 清除 gfwlist
  echo "$(date +%Y-%m-%d\ %T) flushing gfwlist.."; \
  /usr/local/bin/ss-tproxy flush-gfwlist; \
  # 清除 dns cache
  echo "$(date +%Y-%m-%d\ %T) flushing dnscache.."; \
  /usr/local/bin/ss-tproxy flush-dnscache; \
  return 0
}

function set-cron {
  echo "$(date +%Y-%m-%d\ %T) setting auto update.."; \
  # 停止 crond
  cron_pid="`pidof crond`" && \
  if [ -n "$cron_pid" ]; then
    kill -9 "$cron_pid" &> /dev/null
  fi; \
  # 若 /etc/crontabs/root 存在 '/init.sh' 则启动 crond
  if [ -n "$(grep -n '^[^#]*/init.sh' /etc/crontabs/root)" ]; then
    crond
  else
    echo "$(date +%Y-%m-%d\ %T) auto update not valid, NO need to set."; \
  fi
  return 0
}

function start-ss-tproxy {
  # 启动 ss-tproxy
  echo "$(date +%Y-%m-%d\ %T) staring tproxy-gateway.."; \
  /usr/local/bin/ss-tproxy start && return 0
}

check-env && check-config && stop-ss-tproxy && update-ss-config && flush-ss-tproxy && set-cron && resolve_URI && start-ss-tproxy && \
echo -e "IPv4 gateway & dns server: \n`ip addr show eth0 |grep 'inet ' | awk '{print $2}' |sed 's/\/.*//g'`" && \
echo -e "IPv6 dns server: \n`ip addr show eth0 |grep 'inet6 ' | awk '{print $2}' |sed 's/\/.*//g'`" || echo "[ERR] Start tproxy-gateway failed."
if [ "$1" = daemon ]; then
  tail -f /dev/null
fi