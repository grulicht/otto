# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in OTTO, please report it responsibly:

1. **Do NOT open a public issue**
2. Email the maintainers with details of the vulnerability
3. Include steps to reproduce if possible
4. Allow reasonable time for a fix before public disclosure

## Security Considerations

OTTO interacts with sensitive systems (cloud providers, databases, CI/CD pipelines, etc.). Keep these security practices in mind:

### Credentials

- Never commit credentials, tokens, or secrets to the repository
- Use environment variables or `.env` files (gitignored) for sensitive values
- Consider using HashiCorp Vault or similar secret managers for production use

### Permissions

- Use the most restrictive permission profile appropriate for your environment
- Always use `paranoid` or `balanced` profile for production systems
- Review and customize the permission configuration before enabling `autonomous` mode

### Network

- OTTO communicates with external APIs (Slack, cloud providers, monitoring tools)
- Ensure network policies allow only necessary outbound connections
- Use TLS for all API communications

### Audit

- OTTO logs all actions to `state/log.jsonl`
- Review logs periodically for unexpected behavior
- Enable verbose logging in production environments

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest  | Yes       |
