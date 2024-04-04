#!/bin/bash

export DEBIANFRONTEND=noninteractive

sudo apt update && sudo apt upgrade -y
sudo apt install haproxy -y
echo -e "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

cp /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg

sudo systemctl restart haproxy
