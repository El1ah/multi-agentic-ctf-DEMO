#!/bin/bash
set -euo pipefail

# Режим без VPN: ціль досяжна напряму (напр. локальний контейнер), тунелю немає.
# Фаєрвол усе одно обмежує вихід до однієї цілі + 443/53. Контейнер лишається живим.
if [ "${NO_VPN:-0}" = "1" ]; then
  /opt/lab/firewall.sh
  echo "NO-VPN mode. Target: $TARGET_IP reachable directly; no tunnel."
  exec sleep infinity
fi

/opt/lab/firewall.sh
openvpn --config /opt/vpn/lab.ovpn --daemon --log /var/log/openvpn.log \
  --pull-filter ignore "ifconfig-ipv6" --pull-filter ignore "route-ipv6"

# Чекаємо саме на IPv4-адресу на tun0, а не лише на інтерфейс
ATTACKER_IP=""
for i in $(seq 1 30); do
  # tun0 зʼявляється не одразу; під set -e/pipefail порожній результат не має валити скрипт
  ATTACKER_IP=$(ip -4 -o addr show tun0 2>/dev/null | awk '{print $4}' | cut -d/ -f1) || true
  [ -n "$ATTACKER_IP" ] && break
  sleep 1
done
if [ -z "$ATTACKER_IP" ]; then
  echo "VPN failed: tun0 has no IPv4 after 30s. Last openvpn log lines:" >&2
  tail -n 20 /var/log/openvpn.log >&2 || true
  exit 1
fi
echo "VPN up, attacker IP: $ATTACKER_IP"
exec sleep infinity
