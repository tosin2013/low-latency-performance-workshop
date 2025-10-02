# Pre-Commit Hooks Documentation

This document describes the pre-commit hooks system for the Low-Latency Performance Workshop repository.

## Overview

Pre-commit hooks automatically validate document formatting before allowing commits. This ensures:
- ✅ Consistent document quality
- ✅ Early detection of syntax errors
- ✅ Reduced build failures
- ✅ Better collaboration

## What Gets Validated

### YAML Files (`.yml`, `.yaml`)
- **Syntax validation**: Ensures valid YAML structure
- **yamllint checks**: Enforces YAML best practices
- **Common issues detected**:
  - Trailing spaces
  - Incorrect indentation
  - Missing or extra colons
  - Invalid characters

### AsciiDoc Files (`.adoc`)
- **Syntax validation**: Ensures valid AsciiDoc markup
- **asciidoctor checks**: Validates document structure
- **Common issues detected**:
  - Trailing whitespace
  - Tabs instead of spaces
  - Improper heading hierarchy
  - Missing document titles (for modules)
  - Invalid code block syntax

### Markdown Files (`.md`)
- **Syntax validation**: Ensures valid Markdown
- **markdownlint checks**: Enforces Markdown best practices
- **Common issues detected**:
  - Trailing whitespace
  - Tabs instead of spaces
  - Missing top-level headings
  - Inconsistent list formatting

## Setup

### Automatic Setup (Recommended)

Run the developer setup script:

```bash
./scripts/developer-setup.sh
```

This will:
1. Configure git to use `.githooks` directory
2. Make all hooks executable
3. Install required validation tools
4. Test the setup

### Manual Setup

If you prefer manual setup:

```bash
# Configure git to use custom hooks directory
git config core.hooksPath .githooks

# Make hooks executable
chmod +x .githooks/*
chmod +x scripts/validate-documents.sh

# Install required tools
pip3 install --user yamllint
gem install asciidoctor
npm install -g markdownlint-cli
```

### Verify Setup

Check that git is configured correctly:

```bash
git config core.hooksPath
# Should output: .githooks
```

Test the validation script:

```bash
./scripts/validate-documents.sh content/antora.yml
```

## Usage

### Normal Workflow

Once configured, hooks run automatically:

```bash
# 1. Make changes to documents
vim content/modules/ROOT/pages/module-01-low-latency-intro.adoc

# 2. Stage your changes
git add content/modules/ROOT/pages/module-01-low-latency-intro.adoc

# 3. Commit (validation runs automatically)
git commit -m "Update module 01 content"
```

**If validation passes:**
```
==================================================
Running pre-commit validation...
==================================================

ℹ Validating staged documents...

ℹ Validating AsciiDoc: content/modules/ROOT/pages/module-01-low-latency-intro.adoc
✓ AsciiDoc validation passed: content/modules/ROOT/pages/module-01-low-latency-intro.adoc

==================================================
✓ Pre-commit validation passed!
==================================================

[main abc1234] Update module 01 content
 1 file changed, 10 insertions(+), 5 deletions(-)
```

**If validation fails:**
```
==================================================
Running pre-commit validation...
==================================================

ℹ Validating staged documents...

ℹ Validating AsciiDoc: content/modules/ROOT/pages/module-01-low-latency-intro.adoc
⚠ File contains trailing whitespace
✗ asciidoctor validation failed

==================================================
✗ Pre-commit validation failed!
==================================================

Please fix the issues above before committing.
To skip this check (not recommended), use:
  git commit --no-verify
```

### Manual Validation

You can validate documents manually at any time:

```bash
# Validate all tracked documents
./scripts/validate-documents.sh

# Validate specific file
./scripts/validate-documents.sh content/modules/ROOT/pages/module-01-low-latency-intro.adoc

# Validate multiple files
./scripts/validate-documents.sh file1.adoc file2.yaml file3.md
```

### Bypassing Validation

**⚠️ Not recommended** - Only use when absolutely necessary:

```bash
git commit --no-verify -m "Your message"
```

**When to bypass:**
- Emergency hotfixes (fix validation issues in next commit)
- Known false positives (rare)
- Temporary work-in-progress commits (fix before PR)

**When NOT to bypass:**
- Regular development work
- Pull requests
- Production releases

## Common Issues and Solutions

### Issue: "yamllint not found"

**Solution:**
```bash
pip3 install --user yamllint
```

### Issue: "asciidoctor not found"

**Solution:**
```bash
# RHEL/Fedora
sudo dnf install rubygem-asciidoctor

# Ubuntu/Debian
sudo apt-get install asciidoctor

# macOS
brew install asciidoctor
```

### Issue: "Permission denied"

**Solution:**
```bash
chmod +x .githooks/*
chmod +x scripts/validate-documents.sh
```

### Issue: "Hook not running"

**Solution:**
```bash
# Check git configuration
git config core.hooksPath

# If not set to .githooks, configure it
git config core.hooksPath .githooks
```

### Issue: "Trailing whitespace" warnings

**Solution:**
```bash
# Remove trailing whitespace from file
sed -i 's/[[:space:]]*$//' your-file.adoc

# Or configure your editor to remove trailing whitespace on save
```

### Issue: "YAML indentation error"

**Solution:**
- Use 2 spaces for indentation (not tabs)
- Ensure consistent indentation throughout
- Use a YAML-aware editor

### Issue: "AsciiDoc heading hierarchy"

**Solution:**
- Start with `=` for document title
- Use `==` for level 1 sections
- Use `===` for level 2 sections
- Don't skip levels (e.g., `=` to `===`)

## Best Practices

### 1. Validate Early and Often

```bash
# Validate before staging
./scripts/validate-documents.sh your-file.adoc

# Stage and commit
git add your-file.adoc
git commit -m "Your message"
```

### 2. Fix Issues Immediately

Don't bypass validation - fix the issues instead:
- Validation errors indicate real problems
- Fixing early prevents build failures
- Maintains code quality

### 3. Use Editor Integration

Configure your editor to:
- Remove trailing whitespace on save
- Use spaces instead of tabs
- Show whitespace characters
- Validate syntax in real-time

**VS Code:**
```json
{
  "files.trimTrailingWhitespace": true,
  "editor.insertSpaces": true,
  "editor.tabSize": 2,
  "editor.renderWhitespace": "all"
}
```

**Vim:**
```vim
" Remove trailing whitespace on save
autocmd BufWritePre * :%s/\s\+$//e

" Use spaces instead of tabs
set expandtab
set tabstop=2
set shiftwidth=2
```

### 4. Test Locally Before Pushing

```bash
# Build documentation locally
make clean-build

# Serve and review
make serve

# Validate all documents
./scripts/validate-documents.sh

# Run tests
npm test
```

### 5. Keep Tools Updated

```bash
# Update yamllint
pip3 install --upgrade yamllint

# Update asciidoctor
gem update asciidoctor

# Update markdownlint
npm update -g markdownlint-cli
```

## Integration with CI/CD

The same validation script can be used in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: Validate Documents

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: |
          pip3 install yamllint
          gem install asciidoctor
          npm install -g markdownlint-cli
      - name: Validate documents
        run: ./scripts/validate-documents.sh
```

## Troubleshooting

### Debug Mode

Run validation with verbose output:

```bash
bash -x ./scripts/validate-documents.sh your-file.adoc
```

### Check Tool Versions

```bash
python3 --version
yamllint --version
asciidoctor --version
markdownlint --version
```

### Test Individual Tools

```bash
# Test yamllint
yamllint your-file.yaml

# Test asciidoctor
asciidoctor --safe-mode=safe your-file.adoc

# Test markdownlint
markdownlint your-file.md
```

## Additional Resources

- **Developer Guide**: [DEVELOPER_GUIDE.md](../DEVELOPER_GUIDE.md)
- **Onboarding Guide**: [DEVELOPER_ONBOARDING.md](DEVELOPER_ONBOARDING.md)
- **Git Hooks README**: [.githooks/README.md](../.githooks/README.md)
- **Scripts README**: [scripts/README.md](../scripts/README.md)

## Support

If you encounter issues:

1. Check this documentation
2. Review error messages carefully
3. Test validation manually
4. Check tool installation
5. Open an issue on GitHub

## Contributing

To improve the validation system:

1. Edit `scripts/validate-documents.sh`
2. Test your changes thoroughly
3. Update this documentation
4. Submit a pull request

---

**Remember**: Pre-commit hooks are here to help maintain quality. Don't fight them - embrace them! 🎉

