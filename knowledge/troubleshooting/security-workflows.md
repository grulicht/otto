# Security Workflow Troubleshooting

## Vault Token Expiry Mid-Pipeline
**Symptoms:** Pipeline fails partway through with 403 Forbidden, token expired errors.
**Steps:**
1. Check token TTL: `vault token lookup` to see remaining TTL
2. Use short-lived tokens with `vault token create -ttl=1h -policy=ci`
3. Prefer AppRole or JWT/OIDC auth for CI/CD (auto-renewable)
4. Set `VAULT_TOKEN` only for the duration needed, not globally
5. Use `vault token renew` in long-running pipelines
6. Configure token max-TTL on the auth method to allow sufficient time
7. Use Vault Agent for automatic token renewal in long-running processes
8. Check for clock skew between CI runner and Vault server

## Trivy False Positives
**Symptoms:** Scan reports vulnerabilities in packages not actually used, outdated CVE data.
**Steps:**
1. Update Trivy DB: `trivy image --download-db-only` before scanning
2. Create `.trivyignore` file with false positive CVE IDs
3. Use `--ignore-unfixed` to skip vulnerabilities without available patches
4. Filter by severity: `--severity HIGH,CRITICAL` to reduce noise
5. Use `--ignorefile` for per-project ignore lists
6. Check if vulnerability is in a base image layer (may not affect your app)
7. Verify with `trivy image --list-all-pkgs` to confirm package presence
8. Consider using Trivy's VEX (Vulnerability Exploitability eXchange) support

## Sealed-Secrets Controller Not Unsealing
**Symptoms:** SealedSecret created but Secret not appearing, controller logs show errors.
**Steps:**
1. Check controller logs: `kubectl logs -n kube-system -l name=sealed-secrets-controller`
2. Verify the SealedSecret was sealed with the correct certificate
3. Re-fetch certificate: `kubeseal --fetch-cert --controller-namespace kube-system`
4. Check namespace: SealedSecrets are namespace-scoped by default
5. Verify controller is running: `kubectl get pods -n kube-system -l name=sealed-secrets-controller`
6. Check for key rotation: old secrets may need re-sealing after key rotation
7. Ensure RBAC allows the controller to create Secrets in the target namespace
8. Check if the SealedSecret scope (strict, namespace-wide, cluster-wide) matches usage

## SOPS Decryption Failures
**Symptoms:** `sops -d` fails with key errors, cannot access KMS, age key not found.
**Steps:**
1. Check `.sops.yaml` creation rules match the file being decrypted
2. For AWS KMS: verify IAM permissions for `kms:Decrypt` on the key ARN
3. For age: ensure `SOPS_AGE_KEY_FILE` points to the correct key file
4. For GCP KMS: verify `gcloud auth application-default login` is active
5. Check if the file was encrypted with a different key than configured
6. Run `sops -d --verbose` for detailed error output
7. Verify KMS key is not disabled or scheduled for deletion
8. For PGP: ensure the private key is in the GPG keyring

## Falco High Noise Alerts
**Symptoms:** Thousands of alerts, most are false positives, alert fatigue.
**Steps:**
1. Review default rules: many are too broad for production workloads
2. Create custom rules with exceptions: `exceptions` field in Falco rules
3. Use `append: true` to add exceptions to existing rules without overriding
4. Filter by container image: add `container.image.repository` conditions
5. Tune `priority` levels: set informational rules to DEBUG or WARNING
6. Use Falco macros to define common exclusion patterns
7. Start with only CRITICAL and ERROR rules, then gradually add more
8. Monitor `falco_events` metrics to identify the noisiest rules

## cert-manager ACME Challenge Failures
**Symptoms:** Certificate stuck in "Pending", challenge not completing, 403/404 from ACME.
**Steps:**
1. Check Certificate status: `kubectl describe certificate <name>`
2. Check CertificateRequest: `kubectl get certificaterequest`
3. Check Order and Challenge: `kubectl get order` and `kubectl get challenge`
4. For HTTP-01: verify ingress routes `/.well-known/acme-challenge/` correctly
5. For DNS-01: verify DNS provider credentials and permissions
6. Check cert-manager logs: `kubectl logs -n cert-manager deploy/cert-manager`
7. Verify ClusterIssuer/Issuer is correctly configured: `kubectl describe clusterissuer`
8. Rate limits: Let's Encrypt has a 5 duplicate certificates per week limit

## Wazuh Agent Disconnection
**Symptoms:** Agent shows "disconnected" in Wazuh dashboard, no alerts from host.
**Steps:**
1. Check agent status: `systemctl status wazuh-agent`
2. Verify manager IP in `/var/ossec/etc/ossec.conf` matches actual manager
3. Check firewall: port 1514 (TCP/UDP) must be open between agent and manager
4. Review agent logs: `/var/ossec/logs/ossec.log`
5. Check manager-side: `/var/ossec/bin/agent_control -l` to list known agents
6. Re-register agent if key mismatch: `/var/ossec/bin/agent-auth -m <manager-ip>`
7. Check for time synchronization issues between agent and manager
8. Verify TLS certificates if enrollment uses certificate-based auth

## RBAC Policy Too Restrictive Blocking Deployments
**Symptoms:** ServiceAccount cannot create/update resources, 403 errors in CI/CD.
**Steps:**
1. Check current permissions: `kubectl auth can-i --list --as=system:serviceaccount:ns:sa`
2. Test specific permission: `kubectl auth can-i create deployments --as=system:serviceaccount:ns:sa`
3. Review RoleBinding/ClusterRoleBinding: `kubectl get rolebindings -n <ns> -o yaml`
4. Check if Role/ClusterRole has the needed verbs and resource types
5. For Helm: ServiceAccount needs `get,list,watch,create,update,patch,delete` on many resource types
6. Add missing permissions incrementally: use `kubectl auth reconcile -f role.yaml`
7. Check for namespace mismatch: RoleBinding only works within its namespace
8. Use audit logs to see exactly which API call is being denied
