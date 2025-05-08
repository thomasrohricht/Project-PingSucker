#!/bin/bash
# frustrate-gamers.sh – Apply QoS and shaping to UDP traffic on subnet

set -e

# === Config ===
UPLINK_IF="uplink"                 # built-in Ethernet
SUBNET_IF="subnet"                 # USB-Ethernet
SUBNET_CIDR="10.77.77.0/24"        # <-- new /24 used only between Pi and router
SUBNET_GATEWAY="10.77.77.1"        # Pi’s LAN-side IP
DELAY_BASE_MS=25
DROP_PERCENT=0

echo "[`date`] Starting game QOS appliance"

# === Ensure subnet interface is ready and assign static IP ===
echo "[`date`] Waiting for $SUBNET_IF to be present..."
while ! ip link show "$SUBNET_IF" &>/dev/null; do sleep 1; done

echo "[`date`] Bringing $SUBNET_IF up..."
ip link set "$SUBNET_IF" up

echo "[`date`] Assigning static IP to $SUBNET_IF..."
ip addr flush dev "$SUBNET_IF"
ip addr add ${SUBNET_GATEWAY}/24 dev "$SUBNET_IF"

# === Enable IP forwarding ===
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
echo "[`date`] net.ipv4.ip_forward = 1"

# === Flush iptables and set NAT masquerading ===
iptables -F
iptables -t nat -F

# === Ensure we don't lock ourselves out of SSH ===
iptables -P INPUT DROP                     # default policy
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -i $SUBNET_IF -j ACCEPT  # management from LAN side
iptables -A INPUT -i $SUBNET_IF -p tcp --dport 22 -j ACCEPT
#=== IPtables config and NAT masquerading ===
iptables -A FORWARD -i $SUBNET_IF -o $UPLINK_IF -j ACCEPT
iptables -A FORWARD -i $UPLINK_IF -o $SUBNET_IF -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t nat -A POSTROUTING -o $UPLINK_IF -j MASQUERADE

# === Restart dnsmasq cleanly ===
echo "[`date`] Restarting dnsmasq..."
systemctl restart dnsmasq

# === Configure traffic control ===
tc qdisc del dev $UPLINK_IF root 2>/dev/null || true
tc qdisc add dev $UPLINK_IF root handle 1: prio bands 3 priomap 1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1

tc qdisc add dev $UPLINK_IF parent 1:3 handle 30: netem delay ${DELAY_BASE_MS}ms ${DELAY_BASE_MS}ms distribution normal loss ${DROP_PERCENT}%

# === Filter rules ===
# Route all outbound UDP traffic to the degraded queue (1:3)
tc filter add dev $UPLINK_IF parent 1: protocol ip prio 3 u32 match ip protocol 17 0xff flowid 1:3
# Exclude DNS traffic from shaping by assigning it to high priority band (1:1)
tc filter add dev $UPLINK_IF parent 1: protocol ip prio 1 u32 match ip dport 53 0xffff flowid 1:1
# Exempt DHCP (UDP 67/68) from shaping
tc filter add dev $UPLINK_IF parent 1: protocol ip prio 1 u32 \
     match ip dport 67 0xffff flowid 1:1
tc filter add dev $UPLINK_IF parent 1: protocol ip prio 1 u32 \
     match ip sport 68 0xffff flowid 1:1

# ==== Dynamic Degradation Loop ====
while true; do
    delayoffset=$((RANDOM % 13))  # Range: 0–12
    packetdrop=$(( delayoffset / 3 )) # 4 % max when delayoffset = 12
    echo "[$(date)] delayoffset=${delayoffset}"

    # Inner loop duration 10–30 sec, outer loop duration 150–600 sec
    outerduration=$((150 + RANDOM % 451))
    echo "[$(date)] OUTERDURATION=${outerduration}"
    outerend=$((SECONDS + outerduration))
    while [ $SECONDS -lt $outerend ]; do
            jitter=$((5 + RANDOM % 15))             # 5–19 ms
            delayrange=$((RANDOM % 8))              # 0–7
            delay=$(( (delayoffset + delayrange) ** 2 ))

            # -- sanity window ---------------------------------
            if [ $((RANDOM % 100)) -lt $((delayoffset * 2)) ]; then
                delay=0
                jitter=0
                echo "[$(date)] Zero-delay cycle"
                tc qdisc change dev "$UPLINK_IF" parent 1:3 handle 30: \
                     netem delay 0ms loss $((packetdrop / 2))%            # <- no jitter, no distribution
            else
                tc qdisc change dev "$UPLINK_IF" parent 1:3 handle 30: \
                     netem delay ${delay}ms ${jitter}ms loss ${packetdrop}% distribution normal
            fi

            # ---------------------------------------------------
            echo "[$(date)] Applying delay=${delay}ms ±${jitter}ms, drop=${packetdrop}%"
            sleep $((10 + RANDOM % 21))   
    done
done
