# Certificate Renewal Runbook

## Automated (cert-manager / Let's Encrypt)

### Check Status
```bash
# Kubernetes cert-manager
kubectl get certificates -A
kubectl describe certificate <name> -n <namespace>

# Certbot
certbot certificates
```

### If Auto-Renewal Fails
1. Check cert-manager logs: `kubectl logs -n cert-manager deploy/cert-manager`
2. Check challenge status: `kubectl get challenges -A`
3. Common issues: DNS propagation, HTTP challenge not reachable, rate limits
4. Force renewal: `kubectl delete certificate <name>` (cert-manager will recreate)

## Manual Renewal

### Generate CSR
```bash
openssl req -new -key server.key -out server.csr \
  -subj "/CN=example.com" \
  -addext "subjectAltName=DNS:example.com,DNS:www.example.com"
```

### After Getting New Certificate
1. Verify the new certificate: `openssl x509 -in new-cert.pem -noout -text`
2. Verify key matches: compare modulus hashes
3. Update the certificate in the server configuration
4. Reload (not restart) the web server: `nginx -s reload`
5. Verify: `openssl s_client -connect host:443`

## Monitoring
- Alert when certificate expires in < 30 days
- Track cert-manager Certificate resources
- Monitor OCSP stapling status
