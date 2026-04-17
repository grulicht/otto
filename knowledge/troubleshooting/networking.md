# Networking Common Issues

## DNS Resolution Fails
**Steps:**
1. `dig <domain>` or `nslookup <domain>` - test resolution
2. `cat /etc/resolv.conf` - check configured nameservers
3. `dig @8.8.8.8 <domain>` - test with external DNS
4. Check: DNS service running, firewall allows UDP/53, domain exists

## SSL/TLS Certificate Issues
**Certificate expired:**
1. `openssl s_client -connect <host>:443 -servername <host>` - check cert
2. `openssl x509 -in cert.pem -noout -dates` - check expiry
3. Renew with certbot/cert-manager/Let's Encrypt

**Certificate chain incomplete:**
1. Check intermediate certificates are included
2. `openssl s_client -showcerts -connect <host>:443`
3. Test with: https://www.ssllabs.com/ssltest/

## Port Not Reachable
**Steps:**
1. `ss -tlnp | grep <port>` - is something listening?
2. `iptables -L -n` / `ufw status` - firewall blocking?
3. `telnet <host> <port>` or `nc -zv <host> <port>` - test connectivity
4. Check: service running, correct bind address (0.0.0.0 vs 127.0.0.1), firewall, security groups

## SSH Connection Issues
**Connection refused:**
1. Check sshd running: `systemctl status sshd`
2. Check port: `ss -tlnp | grep 22`
3. Check firewall allows SSH

**Permission denied:**
1. Check key permissions: `chmod 600 ~/.ssh/id_rsa`
2. Check authorized_keys on server
3. Check sshd_config: PasswordAuthentication, PubkeyAuthentication

## VPN Not Connecting
**WireGuard:**
1. `wg show` - check interface status
2. Verify keys match between peers
3. Check endpoint reachability and firewall (UDP port)

**OpenVPN:**
1. Check client logs for errors
2. Verify certificates and keys
3. Check server-side routing and NAT
