#!/bin/sh
# -----------------------------------
# DN42-Go By EdenJohnson
# For AS4242423025
# if you want to deploy on other server
# change the things in the define block
# -----------------------------------

# Update System and install packages
apt update
apt install software-properties-common curl -y
add-apt-repository ppa:cz.nic-labs/bird -y
apt update
apt upgrade -y
apt install bird2 wireguard babeld -y

# Define things
curl https://raw.githubusercontent.com/Eden7Ba23/DN42-Go/nodeinfo/nodeinfo.conf >> /tmp/nodeinfo-base64.conf
base64 -d /tmp/nodeinfo-base64.conf > /tmp/nodeinfo.conf
LAST=$(sed -n $(awk '{print NR}' nodeinfo-debase.conf|tail -n1)p nodeinfo-debase.conf|cut -d '|' -f1)

OWNAS="4242423025"
OWNNET="172.23.131.224/27"
OWNNETv6="fddd:5002:6646::/48"
read -r -p "Do you want to config Node IP automaticly? [y/N] " HowIPInput
if [[ "$HowIPInput" =~ ^([yY][eE][sS]|[yY])$ ]]
then
    OWNIP=$(expr $LAST + 224)
    OWNIPv6="fddd:5002:6646::$(expr $LAST + 1)"
else
    read -p "DN42 IPv4 Address : " OWNIP
    read -p "DN42 IPv6 Address : " OWNIPv6
fi



# Write things before download
echo "define OWNAS = ${OWNAS};\ndefine OWNIP = ${OWNIP};\ndefine OWNIPv6 = ${OWNIPv6};\ndefine OWNNET = ${OWNNET};\ndefine OWNNETv6 = ${OWNNETv6};\ndefine OWNNETSET = [${OWNNET}+];\ndefine OWNNETSETv6 = [${OWNNETv6}+];\n\n " > /tmp/bird.conf

# Download birdconfig from Internet
curl https://raw.githubusercontent.com/Eden7Ba23/DN42-Go/main/bird.conf >> /tmp/bird.conf

# Turn off some settings
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
sysctl -p

# wireguard keygen
wg genkey | tee /tmp/privatekey | wg pubkey > /tmp/publickey
mkdir /root/wgkey/peers -p
mv /tmp/privatekey /root/wgkey/peers
mv /tmp/publickey /root/wgkey/peers
wg genkey | tee /tmp/privatekey | wg pubkey > /tmp/publickey
mkdir /root/wgkey/nodes -p
mv /tmp/privatekey /root/wgkey/nodes
mv /tmp/publickey /root/wgkey/nodes

# turn on bird service
rm /etc/bird/bird.conf
mv /tmp/bird.conf /etc/bird/bird.conf
mkdir /etc/bird/peers
mkdir /etc/bird/nodes
curl -sfSLR -o /etc/bird/roa_dn42.conf https://dn42.burble.com/roa/dn42_roa_bird2_4.conf && curl -sfSLR -o /etc/bird/roa_dn42_v6.conf https://dn42.burble.com/roa/dn42_roa_bird2_6.conf && /usr/sbin/birdc configure 1> /dev/null
(echo "0 */4 * * * curl -sfSLR -o /etc/bird/roa_dn42.conf https://dn42.burble.com/roa/dn42_roa_bird2_4.conf && curl -sfSLR -o /etc/bird/roa_dn42_v6.conf https://dn42.burble.com/roa/dn42_roa_bird2_6.conf && /usr/sbin/birdc configure 1> /dev/null" ; crontab -l) | crontab
systemctl unmask bird
systemctl enable bird
bird
