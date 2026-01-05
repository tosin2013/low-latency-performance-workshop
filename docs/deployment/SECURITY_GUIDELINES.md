# Security Guidelines

This document outlines security best practices for working with this repository.

---

## 🔒 Never Commit These

**NEVER commit the following to this repository:**

- ❌ `secrets-ec2.yml` or any `secrets-*.yml` files
- ❌ `pull-secret.json` or any `pull-secret*` files
- ❌ SSH private keys (`.pem`, `.key`, `id_rsa`, etc.)
- ❌ AWS credentials (`~/.aws/credentials`, access keys, secret keys)
- ❌ Kubeconfig files with real cluster credentials
- ❌ Passwords, tokens, or API keys
- ❌ Any file from `agnosticd-output/` directory
- ❌ Deployment artifacts with instance-specific information

---

## ✅ What to Commit

**Safe to commit:**

- ✅ Scripts that *reference* secrets (e.g., `$AWS_ACCESS_KEY`)
- ✅ Configuration templates with placeholders
- ✅ Documentation with example credentials only
- ✅ Sample configuration files
- ✅ Code that reads secrets from external files

---

## 🛡️ Pre-Commit Hook

We use **gitleaks** to automatically scan commits for secrets before they're committed.

### Installation

```bash
# Install the pre-commit hook
cp .github/hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### How It Works

1. Before each commit, gitleaks scans staged files
2. If secrets are detected, the commit is **blocked**
3. You'll see what was detected and where
4. Fix the issue and try again

### What to Do If Blocked

If the pre-commit hook blocks your commit:

1. **Review the findings** - gitleaks will show what it detected
2. **Remove real credentials** - Replace with placeholders or examples
3. **Add to .gitignore** - If it's a secrets file, add it to `.gitignore`
4. **Use examples** - In docs, use AWS example keys like `AKIAIOSFODNN7EXAMPLE`

### Example Credentials (Safe to Use)

For documentation and examples, use AWS's official example credentials format:

```yaml
# AWS provides example credentials for documentation
# Access Key format: AKIA + 16 alphanumeric characters
# Secret Key format: 40 character base64-like string
aws_access_key_id: AKIA...EXAMPLE
aws_secret_access_key: wJal...EXAMPLEKEY
```

**Note**: For complete example credentials, see [AWS Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)

### Bypassing the Hook (NOT RECOMMENDED)

If you absolutely must bypass the hook (for false positives):

```bash
# Option 1: Add a gitleaks:allow comment in the file
# gitleaks:allow
sensitive_data = "example-key-12345"

# Option 2: Skip the pre-commit hook (use sparingly!)
git commit --no-verify
```

**⚠️ Warning**: Only bypass the hook if you're certain it's a false positive!

---

## 📁 Using .gitignore

Our `.gitignore` is configured to exclude common secret patterns:

```gitignore
# AWS and OpenShift secrets
secrets-*.yml
pull-secret*.json
.aws/credentials

# SSH Keys  
*.pem
*.key
ssh_provision_*

# Deployment outputs
agnosticd-output/
*kubeconfig*
```

### Adding New Patterns

If you have additional files that should never be committed:

```bash
echo "my-secret-file.txt" >> .gitignore
git add .gitignore
git commit -m "chore: add my-secret-file.txt to gitignore"
```

---

## 🔍 Manual Security Scan

You can manually scan the repository at any time:

```bash
# Scan the entire repository
gitleaks detect --source=. --verbose

# Scan only staged files
gitleaks protect --staged

# Scan a specific directory
gitleaks detect --source=scripts/
```

---

## 🔐 Secrets Management

### For Local Development

Store secrets in your home directory:

```bash
# AWS credentials
~/.aws/credentials

# OpenShift pull secret  
~/pull-secret.json

# AgnosticD secrets
~/secrets-ec2.yml
```

All scripts are designed to read from these external files.

### For CI/CD

Use environment variables or secret management systems:

- GitHub Secrets
- HashiCorp Vault
- AWS Secrets Manager
- Kubernetes Secrets

**Never hardcode secrets in CI/CD configs!**

---

## 📝 Documentation Best Practices

When writing documentation:

### ✅ DO:

```markdown
1. Get your AWS credentials:
   - Access key: `YOUR_ACCESS_KEY_HERE`
   - Secret key: `YOUR_SECRET_KEY_HERE`

2. Create secrets file:
   ```yaml
   aws_access_key_id: YOUR_ACCESS_KEY
   aws_secret_access_key: YOUR_SECRET_KEY
   ```
```

### ❌ DON'T:

```markdown
1. Use real AWS credentials:
   - Access key: `AKIA[16_real_characters]`
   - Secret key: `[40_character_real_secret]`
```

**Never include real credentials in documentation!**

---

## 🚨 What If Secrets Are Accidentally Committed?

If you accidentally commit secrets:

### 1. **Immediate Actions**

```bash
# If not pushed yet
git reset --soft HEAD~1  # Undo commit
git reset HEAD <file>    # Unstage file
# Fix the file, add to .gitignore

# If already pushed
# ⚠️ Requires rewriting history!
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/secret/file" \
  --prune-empty --tag-name-filter cat -- --all
```

### 2. **Rotate Credentials**

- **AWS keys**: Deactivate and create new ones in IAM console
- **OpenShift pull secret**: No action needed (it's your personal secret)
- **SSH keys**: Generate new key pairs

### 3. **Notify Team**

If this is a shared repository, notify other contributors immediately.

---

## 🔄 CI/CD Security Checks

We recommend adding gitleaks to your CI/CD pipeline:

### GitHub Actions Example

```yaml
name: Security Scan
on: [push, pull_request]

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      
      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 📚 Additional Resources

- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [AWS Security Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [OpenShift Pull Secret Management](https://docs.openshift.com/container-platform/latest/openshift_images/managing_images/using-image-pull-secrets.html)
- [Git Secrets Prevention](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)

---

## 🆘 Need Help?

If you have questions about security practices:

1. Review this document
2. Check the `SECURITY_AUDIT.md` report
3. Ask in the project's issue tracker
4. Contact the repository maintainers

---

**Remember**: It's easier to prevent secrets from being committed than to clean them up afterwards!

