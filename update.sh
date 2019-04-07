#!/bin/bash

echo "`date +%Y-%m-%d\ %T` Upgrading system.."
sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
apk --no-cache --no-progress upgrade && \
apk --no-cache --no-progress add perl curl bash iptables pcre openssl dnsmasq ipset iproute2 tzdata && \
sed -i 's/mirrors.aliyun.com/dl-cdn.alpinelinux.org/g' /etc/apk/repositories

echo "`date +%Y-%m-%d\ %T` Updating v2ray.."
rm -fr /v2ray && \
mkdir -p /v2ray && \
cd /v2ray && \
wget https://raw.githubusercontent.com/v2ray/dist/master/v2ray-linux-arm64.zip && \
unzip v2ray-linux-arm64.zip && \
rm config.json v2ray-linux-arm64.zip && \
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
wget https://koolproxy.com/downloads/arm && \
mv arm koolproxy && \
chmod +x koolproxy && \
chown -R daemon:daemon /koolproxy

echo "`date +%Y-%m-%d\ %T` Updating chinadns.."
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/chinadns.`uname -m` -O /tmp/chinadns && install -c /tmp/chinadns /usr/local/bin && rm -rf /tmp/*

echo "`date +%Y-%m-%d\ %T` Updating sample files.."
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/ss-tproxy.conf -O /sample_config/ss-tproxy.conf
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/v2ray.conf -O /sample_config/v2ray.conf
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/gfwlist.ext -O /sample_config/gfwlist.ext

echo "`date +%Y-%m-%d\ %T` Updating init.sh.."
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/init.sh -O /init.sh && chmod +x /init.sh

echo "`date +%Y-%m-%d\ %T` Updating update.sh.."
wget https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/update.sh -O /init.sh && chmod +x /update.sh

date +%Y-%m-%d\ %T > /version