# Project Pingsucker

** A passive-aggressive network appliance designed to frustrate latency-sensitive gamers and make online games feel like they're haunted by the ghost of 2008 Wi-Fi. **
This tool uses `tc netem` and `iptables` to inject just enough jitter, delay, and packet loss into outbound UDP traffic to make competitive games frustratingly unplayable – without breaking basic web, video, or chat traffic. It's designed to run on a Raspberry Pi 3B+ with two network interfaces (e.g., built-in Ethernet and a USB-Ethernet adapter) acting as a transparent bridge or upstream router.

---
## Why?

Because sometimes the problem *isn't* the network – it's who you're sharing it with.

- Maybe you're a parent with teenagers who have no idea … absolutely no idea just what you’re willing to do with a bit of free time and a vibe-coding session with ChatGPT
- Maybe you're tired of bandwidth-hogging, voice-chat-screaming, chair-punching housemates.  
- Maybe you're a troll with a conscience.  
- Or maybe you're just curious what it feels like to weaponize latency without touching a firewall rule.
Whatever your motive, this tool introduces *plausible, periodic chaos* into UDP traffic while leaving everything else mostly untouched. Your users *will* notice... but they probably won't understand why.

---
## What It Does

- Creates a NAT bridge between `subnet` (LAN) and `uplink` (WAN)
- Assigns static IP to `subnet` interface and enables forwarding
- Runs a `dnsmasq` DHCP server for the LAN side
- Configures a `tc netem` queue to inject:
  - Randomized delay (`0–361ms`)
  - Jitter (`±5–19ms`)
  - Packet loss (`0–4%`)
  - Probability-based "sanity windows" (occasional 0-delay bursts)
- Filters only **UDP traffic**, excluding DNS and DHCP

---
## What It Doesn’t Do

- Intercept or decrypt traffic
- Touch TCP flows (web browsing remains usable)
- Do anything useful for serious network engineering

---
## Known Effective Targets

| Game | Result |
|------|--------|
| **CS:GO / CS2** | Snapshots arrive late, input feels laggy, scoreboard ping swings wildly |
| **Valorant** | Disconnects or kicks due to ping >250ms |
| **Apex / Warzone** | Rubberbanding and shot registration hell |
| **Web, Zoom, YouTube** | Mostly fine. DNS and TCP traffic bypass netem. |

---
## Hardware Requirements

- Known to runs perfectly on a Raspberry Pi 3B+, but considering its simple mission in life this could probably run fine on lesser hardware
- 2 NICs (e.g., built-in Ethernet + USB-Ethernet)
- Debian or Raspbian Linux
- Internet upstream on `uplink`
- Downstream router or switch on `subnet`

---
## Network Topology
[Internet]
|
[Modem or ISP Router]
|
[Pi Running frustrate-gamers.sh]
|
[Your Router / Wi-Fi Access Point]
|
[Victims]
The Pi acts as a stealth inline router. Downstream devices get their IP from the Pi and route through it as if it's the gateway.

---
## Warnings & Disclaimers
This is not a security tool. This is not ethical hacking. This is network satire in script form.

- This script flushes existing iptables rules.
- Do **not** run this on a production system unless you're very sure of what you're doing.
- Make sure the device is running behind a NAT or firewall.
- UDP shaping may impact video-conferencing tools like Zoom or Teams. If the target network includes people who need to “work from home” you might be messing with someone's gainful employment.
- ChatGPT vibe-coding played a significant (who am I kidding, it played the *primary*) role in the creation of this tool. Short as it is, it still contains several anomalies and superfluous lines of code. Live with it … or fork it and clean it up if it bothers you enough.
**? Do not deploy on networks you don't own or control.  
**? Don't use this to sabotage people maliciously.  
**? You are responsible for how you use this. I just wrote the punchline.

---
## Install

1. Flash a Raspberry Pi with Debian or Raspbian Lite  
2. Enable IP forwarding  
3. Plug the uplink into `eth0`, the target subnet into `eth1` (or your USB-to-Ethernet adapter)  
4. Clone this repo on your Pi
5. Make the script executable.
6. Run it manually or install as a system service
