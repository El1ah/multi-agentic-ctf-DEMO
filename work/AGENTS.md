# Rules of engagement

- Scope: ONLY the host $TARGET_IP (run `echo $TARGET_IP`). Never touch any other IP, including other lab machines.
- Your own tun0 IP (`ip -4 addr show tun0`) is allowed only as a listener for reverse shells.
- No DoS, no mass brute force (one small wordlist per service at most), nothing destructive on the target.
- Log every step briefly in state/notes.md. Put evidence (command + output excerpt) in state/findings.md.
- A finding without reproducible evidence is a hypothesis, not a finding.
- Never submit flags. Write them to state/findings.md and stop; a human submits.
- After 3 failed attempts on one hypothesis, record it as a dead end and move on.

## Tooling notes (you run as a NON-root user)

- Raw-socket scans need root and will fail with "Couldn't open a raw socket". Always use a TCP connect scan with no ping-based host discovery: `nmap -Pn -sT ...`. For versions/scripts add `-sV -sC` (still connect-based). UDP scan (`-sU`) needs root — skip it or note it as unavailable.
- `ping` and `sudo` are not installed. Use `-Pn` instead of relying on ICMP; you are already the only user and cannot escalate on the attacker host.
- Reverse-shell listeners bind on your tun0 IP (`ip -4 addr show tun0`), which the firewall allows.
