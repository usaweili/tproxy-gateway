#!/bin/bash

echo "`date +%Y-%m-%d\ %T` Upgrading system.."
sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
apk --no-cache --no-progress upgrade && \
apk --no-cache --no-progress add perl curl bash iptables pcre openssl dnsmasq ipset iproute2 tzdata && \
sed -i 's/mirrors.aliyun.com/dl-cdn.alpinelinux.org/g' /etc/apk/repositories

arch=`uname -m`
if [ "$arch" = "x86_64" ]; then
  kp_url="https://koolproxy.com/downloads/x86_64"
  v2ray_url="https://raw.githubusercontent.com/v2ray/dist/master/v2ray-linux-64.zip"
fi
if [ "$arch" = "aarch64" ]; then
  kp_url="https://koolproxy.com/downloads/arm"
  v2ray_url="https://raw.githubusercontent.com/v2ray/dist/master/v2ray-linux-arm64.zip"
fi

echo "`date +%Y-%m-%d\ %T` Updating v2ray.."
rm -fr /v2ray && \
mkdir -p /v2ray && \
cd /v2ray && \
wget -q "$v2ray_url" -O v2ray-linux.zip && \
unzip v2ray-linux.zip && \
rm config.json v2ray-linux.zip && \
chmod +x v2ray v2ctl && mkdir -p /sample_config

echo "`date +%Y-%m-%d\ %T` Updating ss-tproxy.."
cd / && mkdir -p /ss-tproxy &&\
wget https://raw.githubusercontent.com/zfl9/ss-tproxy/v3-master/ss-tproxy -O /ss-tproxy/ss-tproxy && \
sed -i 's/while umount \/etc\/resolv.conf; do :; done/while mount|grep overlay|grep \/etc\/resolv.conf; do umount \/etc\/resolv.conf; done/g' /ss-tproxy/ss-tproxy && \
sed -i 's/60053/53/g' /ss-tproxy/ss-tproxy && \
sed -i '/no-resolv/i\addn-hosts=$dnsmasq_addn_hosts' /ss-tproxy/ss-tproxy && \
install -c /ss-tproxy/ss-tproxy /usr/local/bin && \
mkdir -m 0755 -p /etc/ss-tproxy && chown -R root:root /etc/ss-tproxy && \
rm -rf /ss-tproxy

echo "`date +%Y-%m-%d\ %T` Updating koolproxy.."
rm -fr /koolproxy && \
mkdir -p /koolproxy && cd /koolproxy && \
wget "$kp_url" -O koolproxy && \
chmod +x koolproxy && \
chown -R daemon:daemon /koolproxy

echo "`date +%Y-%m-%d\ %T` Updating chinadns.."
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/chinadns.`uname -m` -O /tmp/chinadns && install -c /tmp/chinadns /usr/local/bin && rm -rf /tmp/*

echo "`date +%Y-%m-%d\ %T` Updating sample files.."
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/ss-tproxy.conf -O /sample_config/ss-tproxy.conf
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/v2ray.conf -O /sample_config/v2ray.conf
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/gfwlist.ext -O /sample_config/gfwlist.ext

date +%Y-%m-%d\ %T > /version