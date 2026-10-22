#!/bin/bash
set -euo pipefail
: "${TARGET_IP:?}"
# Лише одна IPv4-адреса: CIDR чи хостнейм тут відкрили б цілу підмережу або що завгодно
[[ "$TARGET_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "TARGET_IP must be a single IPv4 address, got: $TARGET_IP" >&2; exit 1; }

# IPv6: усе закрито, крім loopback (спільне для обох режимів)
ip6_lock() {
  for chain in INPUT OUTPUT FORWARD; do ip6tables -F "$chain" 2>/dev/null; ip6tables -P "$chain" DROP 2>/dev/null; done
  ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null
  ip6tables -A INPUT -i lo -j ACCEPT 2>/dev/null
}

# Режим без VPN: пускаємо лише до цілі напряму + DNS/HTTPS для API моделей.
if [ "${NO_VPN:-0}" = "1" ]; then
  ip6_lock
  iptables -F OUTPUT; iptables -F FORWARD
  iptables -P FORWARD DROP
  iptables -P OUTPUT DROP
  iptables -A OUTPUT -o lo -j ACCEPT
  iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -p udp --dport 53 -j ACCEPT          # DNS (API моделей)
  iptables -A OUTPUT -d "$TARGET_IP" -j ACCEPT            # лише ціль
  iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT         # HTTPS (API моделей)
  iptables -A OUTPUT -j REJECT
  echo "firewall: NO-VPN mode, only $TARGET_IP + 443/53 allowed outbound"
  exit 0
fi

VPN_HOST=$(awk '/^remote /{print $2; exit}' /opt/vpn/lab.ovpn)
VPN_PORT=$(awk '/^remote /{print $3; exit}' /opt/vpn/lab.ovpn)
VPN_PORT=${VPN_PORT:-1194}
[ -n "$VPN_HOST" ] || { echo "No 'remote' line in lab.ovpn" >&2; exit 1; }

# IPv6: усе закрито, крім loopback
for chain in INPUT OUTPUT FORWARD; do ip6tables -F "$chain"; ip6tables -P "$chain" DROP; done
ip6tables -A OUTPUT -o lo -j ACCEPT
ip6tables -A INPUT -i lo -j ACCEPT

# IPv4
iptables -F OUTPUT
iptables -F INPUT
iptables -F FORWARD
iptables -P FORWARD DROP          # контейнер не маршрутизує чужий трафік у тунель
iptables -P OUTPUT DROP
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT ! -o tun0 -p udp --dport 53 -j ACCEPT
VPN_IPS=$(getent ahostsv4 "$VPN_HOST" | awk '{print $1}' | sort -u)
[ -n "$VPN_IPS" ] || { echo "Cannot resolve VPN host $VPN_HOST" >&2; exit 1; }
for ip in $VPN_IPS; do
  iptables -A OUTPUT -d "$ip" -p udp --dport "$VPN_PORT" -j ACCEPT
  iptables -A OUTPUT -d "$ip" -p tcp --dport "$VPN_PORT" -j ACCEPT
done

# тунель: лише ціль, в обидва боки
iptables -A OUTPUT -o tun0 -d "$TARGET_IP" -j ACCEPT
iptables -A OUTPUT -o tun0 -j REJECT
iptables -A INPUT -i tun0 ! -s "$TARGET_IP" -j DROP

# інтернет: лише HTTPS (API моделей, документація)
iptables -A OUTPUT ! -o tun0 -p tcp --dport 443 -j ACCEPT
