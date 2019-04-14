#!/bin/bash

function check-new-version {
  echo "$(date +%Y-%m-%d\ %T) Check new version of tproxy-gateway." && \
  tproxy_gateway_latest=$(curl -H 'Cache-Control: no-cache' -s "https://api.github.com/repos/lisaac/tproxy-gateway/commits/master" | grep '"date": ' | awk 'NR==1{print $2}' | sed 's/"//g; s/T/ /; s/Z//' | xargs -I{} date -u -d {} +%s) || { echo "[ERR] can NOT get the latest version of tproxy, please check the network"; exit 1; }
  [ -f $0 ] && update_sh_current=$(stat -c %Y $0) || update_sh_current=0
  if [ "$tproxy_gateway_latest" -gt "$update_sh_current" ]; then
    echo "$(date +%Y-%m-%d\ %T) updating update.sh."
    wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/update.sh -O /tmp/update.sh && \
    install -c /tmp/update.sh $0 && \
    $0 "$@"
    exit 0
  fi
  [ -f /init.sh ] && init_sh_current=$(stat -c %Y /init.sh) || init_sh_current=0
  if [ "$tproxy_gateway_latest" -gt "$init_sh_current" ]; then
    echo "$(date +%Y-%m-%d\ %T) updating init.sh."
    wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/init.sh -O /tmp/init.sh && \
    install -c /tmp/init.sh /init.sh
  fi
  echo "$(date +%Y-%m-%d\ %T) tproxy-gateway update to date."
}

function get-link {
  echo "$(date +%Y-%m-%d\ %T) Getting latest version." && \
  arch=`uname -m` && \
  v2ray_latest_ver="$(curl -H 'Cache-Control: no-cache' -s https://api.github.com/repos/v2ray/v2ray-core/releases/latest | grep 'tag_name' | cut -d\" -f4)"; \
  koolproxy_latest_ver="$(curl -H 'Cache-Control: no-cache' -s https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/latest_version | grep 'koolproxy' | cut -d' ' -f2)"; \
  chinadns_latest_ver="$(curl -H 'Cache-Control: no-cache' -s https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/latest_version | grep 'chinadns' | cut -d' ' -f2)"; \
  if [ "$arch" = "x86_64" ]; then
    kp_url="https://koolproxy.com/downloads/x86_64"
    v2ray_url="https://raw.githubusercontent.com/v2ray/dist/master/v2ray-linux-64.zip"
    #v2ray_url="https://github.com/v2ray/v2ray-core/releases/download/$v2ray_latest_ver/v2ray-linux-64.zip"
  elif [ "$arch" = "aarch64" ]; then
    kp_url="https://koolproxy.com/downloads/arm"
    v2ray_url="https://raw.githubusercontent.com/v2ray/dist/master/v2ray-linux-arm64.zip"
    #v2ray_url="https://github.com/v2ray/v2ray-core/releases/download/$v2ray_latest_ver/v2ray-linux-arm64.zip"
  fi; \
  ss_url="https://raw.githubusercontent.com/zfl9/ss-tproxy/v3-master/ss-tproxy"; \
  chinadns_url="https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/chinadns.`uname -m`"; \
  echo -e "V2ray latest version is ${v2ray_latest_ver}.\nKoolproxy latest version is ${koolproxy_latest_ver}.\nChinadns latest version is ${chinadns_latest_ver}."
}

# 更新之前停止 ss-tproxy
function stop-sstorpxy {
  if [ -f /usr/local/bin/ss-tproxy ]; then
    /usr/local/bin/ss-tproxy stop > /dev/null
  fi
}

# 更新系统
function update-system {
  echo "$(date +%Y-%m-%d\ %T) Upgrading system.." && \
  sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
  apk --no-cache --no-progress upgrade && \
  apk --no-cache --no-progress add perl curl bash iptables pcre openssl dnsmasq ipset iproute2 tzdata jq && \
  sed -i 's/mirrors.aliyun.com/dl-cdn.alpinelinux.org/g' /etc/apk/repositories
}

# 更新 V2RAY
function update-v2ray {
  echo "$(date +%Y-%m-%d\ %T) Updating v2ray.." && \
  v2ray_latest_v="$(echo $v2ray_latest_ver | cut -dv -f2)" && \
  if [ -f /v2ray/v2ray ]; then
    v2ray_current_v="$(/v2ray/v2ray -version | grep V2Ray | cut -d' ' -f2)"
  fi; \
  if [ "$v2ray_latest_v" != "$v2ray_current_v" -o ! -f /v2ray/v2ray ]; then
    echo " Latest v2ray version: ${v2ray_latest_v}, need to update" && \
    rm -fr /v2ray && mkdir -p /v2ray && cd /v2ray && \
    wget "$v2ray_url" -O v2ray-linux.zip && \
    unzip v2ray-linux.zip && \
    rm -fr doc systemv systemd config.json v2ray-linux.zip && \
    chmod +x v2ray v2ctl
  else
    echo "Current v2ray version: ${v2ray_current_v}, need NOT to update"
  fi
}

# 更新 ss-tproxy 并 patch
function update-ss-tproxy {
  echo "$(date +%Y-%m-%d\ %T) Updating ss-tproxy.." && \
  cd / && mkdir -p /ss-tproxy &&\
  wget "$ss_url" -O /ss-tproxy/ss-tproxy && \
  sed -i 's/while umount \/etc\/resolv.conf; do :; done/while mount|grep overlay|grep \/etc\/resolv.conf; do umount \/etc\/resolv.conf; done/g' /ss-tproxy/ss-tproxy && \
  sed -i 's/60053/53/g' /ss-tproxy/ss-tproxy && \
  sed -i '/no-resolv/i\addn-hosts=$dnsmasq_addn_hosts' /ss-tproxy/ss-tproxy && \
  install -c /ss-tproxy/ss-tproxy /usr/local/bin && \
  mkdir -m 0755 -p /etc/ss-tproxy && chown -R root:root /etc/ss-tproxy && \
  rm -rf /ss-tproxy
}

# 更新 koolproxy
function update-koolproxy {
  echo "$(date +%Y-%m-%d\ %T) Updating koolproxy.." && \
  if [ -f /koolproxy/koolproxy ]; then
    koolproxy_current_ver="$(/koolproxy/koolproxy -v | cut -d' ' -f1)"
  fi; \
  if [ "$koolproxy_latest_ver" != "$koolproxy_current_ver" -o ! -f /koolproxy/koolproxy ]; then
    echo "Latest koolproxy version: ${koolproxy_latest_ver}, need to update" && \
    rm -fr /koolproxy && mkdir -p /koolproxy && cd /koolproxy && \
    wget "$kp_url" -O koolproxy && chmod +x /koolproxy/koolproxy
  else
    echo "Current koolproxy version: ${koolproxy_current_ver}, need NOT to update"
  fi
}

# 更新 chinadns
function update-chinadns {
  echo "$(date +%Y-%m-%d\ %T) Updating chinadns.." && \
  if [ -f /usr/local/bin/chinadns ]; then
    chinadns_current_ver="$(/usr/local/bin/chinadns -V | cut -d' ' -f2)"
  fi; \
  if [ "$chinadns_latest_ver" != "$chinadns_current_ver" -o ! -f /usr/local/bin/chinadns ]; then
    echo "Latest chinadns version: ${chinadns_latest_ver}, need to update" && \
    wget "$chinadns_url" -O /tmp/chinadns && install -c /tmp/chinadns /usr/local/bin
  else
    echo "Current chinadns version: ${chinadns_current_ver}, need NOT to update"
  fi
}

function update-sample-files {
  echo "$(date +%Y-%m-%d\ %T) Updating sample files.." && \
  mkdir -p /sample_config && \
  wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/ss-tproxy.conf -O /sample_config/ss-tproxy.conf && \
  wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/v2ray.conf -O /sample_config/v2ray.conf && \
  wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/gfwlist.ext -O /sample_config/gfwlist.ext
}

# 写入更新日期及版本
function check-version {
  rm -rf /tmp/* && \
  echo "Update time: $(date +%Y-%m-%d\ %T)" > /version && \
  echo "V2Ray version: $(/v2ray/v2ray -version | grep V2Ray | cut -d' ' -f2)" | tee -a /version && \
  echo "Koolproxy version:  $(/koolproxy/koolproxy -v)" | tee -a /version && \
  echo "Chinadns version: $(/usr/local/bin/chinadns -V | cut -d' ' -f2)" | tee -a /version && \
  echo "Update completed !!"
}

check-new-version && get-link && stop-sstorpxy && update-v2ray && update-ss-tproxy && update-koolproxy && update-chinadns && update-sample-files && check-version || echo "Update failed." 