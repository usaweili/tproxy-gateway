#!/bin/bash

arch=`uname -m`
v2ray_latest_ver="$(curl -H 'Cache-Control: no-cache' -s https://api.github.com/repos/v2ray/v2ray-core/releases/latest | grep 'tag_name' | cut -d\" -f4)"
if [ "$arch" = "x86_64" ]; then
  kp_url="https://koolproxy.com/downloads/x86_64"
  v2ray_url="https://raw.githubusercontent.com/v2ray/dist/master/v2ray-linux-64.zip"
  #v2ray_url="https://github.com/v2ray/v2ray-core/releases/download/$v2ray_latest_ver/v2ray-linux-64.zip"
fi
if [ "$arch" = "aarch64" ]; then
  kp_url="https://koolproxy.com/downloads/arm"
  v2ray_url="https://raw.githubusercontent.com/v2ray/dist/master/v2ray-linux-arm64.zip"
  #v2ray_url="https://github.com/v2ray/v2ray-core/releases/download/$v2ray_latest_ver/v2ray-linux-arm64.zip"
fi

# 更新之前停止 ss-tproxy
if [ ! -f /usr/local/bin/ss-tproxy ]; then
  /usr/local/bin/ss-tproxy stop > /dev/null
fi

# 更新系统
echo "`date +%Y-%m-%d\ %T` Upgrading system.."
sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
apk --no-cache --no-progress upgrade && \
apk --no-cache --no-progress add perl curl bash iptables pcre openssl dnsmasq ipset iproute2 tzdata && \
sed -i 's/mirrors.aliyun.com/dl-cdn.alpinelinux.org/g' /etc/apk/repositories

# 更新 V2RAY 版本
echo "`date +%Y-%m-%d\ %T` Updating v2ray.."
if [ -f /v2ray/v2ray ]; then
  v2ray_latest_v="$(echo $v2ray_latest_ver | cut -dv -f2)"
  v2ray_current_v="$(/v2ray/v2ray -version | grep V2Ray | cut -d' ' -f2)"
fi
if [ "$v2ray_latest_v" != "$v2ray_current_v" -o ! -f /v2ray/v2ray ]; then
  rm -fr /v2ray && mkdir -p /v2ray && cd /v2ray && \
  wget "$v2ray_url" -O v2ray-linux.zip && \
  unzip v2ray-linux.zip && \
  rm -fr doc systemv systemd config.json v2ray-linux.zip && \
  chmod +x v2ray v2ctl
fi

# 更新 ss-tproxy 并 patch
echo "`date +%Y-%m-%d\ %T` Updating ss-tproxy.."
cd / && mkdir -p /ss-tproxy &&\
wget https://raw.githubusercontent.com/zfl9/ss-tproxy/v3-master/ss-tproxy -O /ss-tproxy/ss-tproxy && \
sed -i 's/while umount \/etc\/resolv.conf; do :; done/while mount|grep overlay|grep \/etc\/resolv.conf; do umount \/etc\/resolv.conf; done/g' /ss-tproxy/ss-tproxy && \
sed -i 's/60053/53/g' /ss-tproxy/ss-tproxy && \
sed -i '/no-resolv/i\addn-hosts=$dnsmasq_addn_hosts' /ss-tproxy/ss-tproxy && \
install -c /ss-tproxy/ss-tproxy /usr/local/bin && \
mkdir -m 0755 -p /etc/ss-tproxy && chown -R root:root /etc/ss-tproxy && \
rm -rf /ss-tproxy

# 更新 koolproxy
echo "`date +%Y-%m-%d\ %T` Updating koolproxy.."
rm -fr /koolproxy && mkdir -p /koolproxy && \
wget "$kp_url" -O /koolproxy/koolproxy && \
chmod +x /koolproxy/koolproxy && \
chown -R daemon:daemon /koolproxy

# 更新 chinadns
echo "`date +%Y-%m-%d\ %T` Updating chinadns.."
if [ ! -f /usr/local/bin/chinadns ]; then
  wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/chinadns.`uname -m` -O /tmp/chinadns && install -c /tmp/chinadns /usr/local/bin
fi

echo "`date +%Y-%m-%d\ %T` Updating sample files.."
mkdir -p /sample_config
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/ss-tproxy.conf -O /sample_config/ss-tproxy.conf
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/v2ray.conf -O /sample_config/v2ray.conf
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/gfwlist.ext -O /sample_config/gfwlist.ext

# 写入更新日期及版本
rm -rf /tmp/*
echo "Update completed !!"
echo "Update time: `date +%Y-%m-%d\ %T`" > /version
echo "V2Ray version: `/v2ray/v2ray -version | grep V2Ray | cut -d' ' -f2`" | tee -a /version
echo "Koolproxy version: `/koolproxy/koolproxy -v`" | tee -a /version
echo "Chinadns version: `/usr/local/bin/chinadns -V | cut -d' ' -f2`" | tee -a /version