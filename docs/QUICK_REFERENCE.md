# Quick Reference Guide

Quick reference for common tasks in the Low-Latency Performance Workshop project.

## New Developer Setup

```bash
# Clone and setup
git clone https://github.com/tosin2013/low-latency-performance-workshop.git
cd low-latency-performance-workshop
./scripts/developer-setup.sh
```

## Build & Serve

```bash
# Build documentation
make build

# Serve locally (http://localhost:8080)
make serve

# Build and serve
make run-all

# Stop server
make stop

# Clean and rebuild
make clean-build

# Stop and clean
make stop-clean
```

## Document Validation

```bash
# Validate all documents
./scripts/validate-documents.sh

# Validate specific file
./scripts/validate-documents.sh path/to/file.adoc

# Validate multiple files
./scripts/validate-documents.sh file1.adoc file2.yaml file3.md
```

## Git Workflow

```bash
# Create feature branch
git checkout -b feature/your-feature

# Make changes and validate
./scripts/validate-documents.sh your-file.adoc

# Stage and commit (validation runs automatically)
git add your-file.adoc
git commit -m "Your message"

# Push to fork
git push origin feature/your-feature
```

## Testing

```bash
# Run JavaScript tests
npm test

# Test all Python scripts
./scripts/test-all-scripts.sh

# Validate ArgoCD security
./scripts/validate-argocd-security.sh
```

## Performance Analysis

```bash
# Analyze performance results
python3 scripts/analyze-performance.py

# Compare baseline vs tuned
python3 scripts/analyze-performance.py --compare

# Generate report
python3 scripts/analyze-performance.py --report report.md

# Check cluster health
python3 scripts/cluster-health-check.py
```

## Pre-commit Hooks

```bash
# Setup hooks (done by developer-setup.sh)
git config core.hooksPath .githooks

# Make hooks executable
chmod +x .githooks/*

# Bypass validation (not recommended)
git commit --no-verify -m "Message"
```

## Common Issues

### Permission Denied
```bash
chmod +x scripts/*.sh .githooks/*
```

### Missing yamllint
```bash
pip3 install --user yamllint
```

### Missing asciidoctor
```bash
# RHEL/Fedora
sudo dnf install rubygem-asciidoctor

# Ubuntu/Debian
sudo apt-get install asciidoctor

# macOS
brew install asciidoctor
```

### Hook Not Running
```bash
git config core.hooksPath .githooks
```

### Trailing Whitespace
```bash
# Remove trailing whitespace
sed -i 's/[[:space:]]*$//' your-file.adoc
```

## File Locations

```
├── content/modules/ROOT/pages/    # Workshop modules
├── gitops/                         # GitOps configs
├── scripts/                        # Utility scripts
│   ├── developer-setup.sh         # New developer setup
│   ├── validate-documents.sh      # Document validation
│   └── *.py                       # Analysis scripts
├── .githooks/                      # Git hooks
│   └── pre-commit                 # Pre-commit validation
├── docs/                           # Documentation
│   ├── DEVELOPER_ONBOARDING.md    # Onboarding guide
│   ├── PRE_COMMIT_HOOKS.md        # Hooks documentation
│   └── QUICK_REFERENCE.md         # This file
├── Makefile                        # Build automation
└── DEVELOPER_GUIDE.md              # Full developer guide
```

## Useful Commands

```bash
# Show all make targets
make help

# View git hooks config
git config core.hooksPath

# Check tool versions
python3 --version
node --version
npm --version
yamllint --version
asciidoctor --version

# Find all AsciiDoc files
find content -name "*.adoc"

# Find all YAML files
find . -name "*.yml" -o -name "*.yaml"

# Count lines in modules
wc -l content/modules/ROOT/pages/*.adoc
```

## Editor Configuration

### VS Code
```json
{
  "files.trimTrailingWhitespace": true,
  "editor.insertSpaces": true,
  "editor.tabSize": 2,
  "editor.renderWhitespace": "all"
}
```

### Vim
```vim
autocmd BufWritePre * :%s/\s\+$//e
set expandtab
set tabstop=2
set shiftwidth=2
```

## Documentation Links

- **[DEVELOPER_GUIDE.md](../DEVELOPER_GUIDE.md)** - Comprehensive guide
- **[DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md)** - New developer guide
- **[PRE_COMMIT_HOOKS.md](PRE_COMMIT_HOOKS.md)** - Hooks documentation
- **[ENVIRONMENT_CONFIG.md](../ENVIRONMENT_CONFIG.md)** - Environment config
- **[.githooks/README.md](../.githooks/README.md)** - Git hooks README
- **[scripts/README.md](../scripts/README.md)** - Scripts documentation

## Support

- **Issues**: https://github.com/tosin2013/low-latency-performance-workshop/issues
- **Documentation**: See links above
- **Questions**: Open an issue or check existing ones

---

**Pro Tip**: Bookmark this page for quick access! 🔖

