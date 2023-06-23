#!/bin/bash

read -p "请输入目标内网IP地址: " destination_ip
read -p "请输入本机内网IP地址: " local_ip
read -p "请输入限制带宽大小（单位：Mbps）: " bandwidth_limit

# 清空现有的规则和链
iptables -F
iptables -X

# 设置默认策略
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# 启用IP转发
sysctl -w net.ipv4.ip_forward=1

# 添加tc限速规则
tc qdisc add dev eth0 root handle 1: htb default 10
tc class add dev eth0 parent 1: classid 1:1 htb rate ${bandwidth_limit}mbps burst 15k
tc filter add dev eth0 parent 1: protocol ip prio 1 u32 match ip dst ${destination_ip} flowid 1:1

# 配置PREROUTING链，将指定端口的流量进行DNAT到目标内网IP
iptables -t nat -A PREROUTING -p tcp --dport 1025:65535 -j DNAT --to-destination "$destination_ip"
iptables -t nat -A PREROUTING -p udp --dport 1025:65535 -j DNAT --to-destination "$destination_ip"

# 配置POSTROUTING链，将来自目标内网IP的响应流量进行SNAT，将源地址设置为本机内网IP
iptables -t nat -A POSTROUTING -p tcp -d "$destination_ip" --dport 1025:65535 -j SNAT --to-source "$local_ip"
iptables -t nat -A POSTROUTING -p udp -d "$destination_ip" --dport 1025:65535 -j SNAT --to-source "$local_ip"

# 保存规则
mkdir -p /etc/iptables/
iptables-save > /etc/iptables/rules.v4

# 安装iptables-persistent以永久保存规则
apt-get update
apt-get install -y iptables-persistent

echo "内网传输配置完成。"
