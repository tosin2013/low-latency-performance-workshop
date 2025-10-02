# Antora Site Validation Guide

This document describes the site validation system for the Low-Latency Performance Workshop.

## Overview

The workshop includes automated validation to ensure the Antora site builds correctly and content is properly formatted. Validation runs automatically before building the site.

## Validation Levels

### 1. Pre-Commit Validation (Git Hooks)

**When it runs:** Automatically when you commit changes

**What it validates:**
- YAML syntax and structure
- AsciiDoc syntax and formatting
- Markdown syntax and formatting
- Only validates staged files (fast)

**Setup:**
```bash
# Automatic setup (recommended)
./scripts/developer-setup.sh

# Manual setup
git config core.hooksPath .githooks
chmod +x .githooks/*
```

**Usage:**
```bash
# Normal workflow - validation runs automatically
git add content/modules/ROOT/pages/my-page.adoc
git commit -m "Update content"

# Skip validation if needed (not recommended)
git commit --no-verify -m "Update content"
```

### 2. Pre-Build Validation (Antora Site)

**When it runs:** Automatically before building the site with `utilities/lab-build`

**What it validates:**
- Antora site configuration (`default-site.yml`)
- Component configuration (`content/antora.yml`)
- Content directory structure
- Navigation file and references
- AsciiDoc pages for common issues
- Build tool availability
- Document formatting (optional)

**Usage:**
```bash
# Build with validation (default)
make build
# or
./utilities/lab-build

# Build with force (ignore validation warnings)
make build-force
# or
./utilities/lab-build --force

# Build without validation (not recommended)
./utilities/lab-build --skip-validation
```

### 3. Manual Validation

**When to use:** Before committing, during development, or troubleshooting

**Available commands:**

```bash
# Validate Antora site configuration and structure
make validate
# or
./scripts/validate-antora-site.sh

# Validate all documents
make validate-docs
# or
./scripts/validate-documents.sh

# Validate specific files
./scripts/validate-documents.sh content/antora.yml default-site.yml

# Validate specific pages
./scripts/validate-documents.sh content/modules/ROOT/pages/*.adoc
```

## What Gets Validated

### Site Configuration (`default-site.yml`)

✅ **Checks:**
- Valid YAML syntax
- Required fields present:
  - `site.title`
  - `content.sources`
  - `ui.bundle.url`
  - `output.dir`

❌ **Common Issues:**
- Invalid YAML indentation
- Missing required fields
- Incorrect URL format

### Component Configuration (`content/antora.yml`)

✅ **Checks:**
- Valid YAML syntax
- Required fields present:
  - `name`
  - `title`
  - `version`
- Navigation file exists
- Attributes are properly defined

❌ **Common Issues:**
- Missing required fields
- Navigation file not found
- Undefined attributes used in pages

### Content Structure

✅ **Checks:**
- Required directories exist:
  - `content/modules`
  - `content/modules/ROOT`
  - `content/modules/ROOT/pages`
- Content files present
- Navigation file exists

❌ **Common Issues:**
- Missing required directories
- Empty pages directory
- Missing navigation file

### Navigation (`content/modules/ROOT/nav.adoc`)

✅ **Checks:**
- Navigation file exists
- Contains navigation entries
- Referenced pages exist
- Valid xref syntax

❌ **Common Issues:**
- Empty navigation file
- Broken xref links
- Referenced pages don't exist
- Invalid xref syntax

### AsciiDoc Pages

✅ **Checks:**
- Document title present (`= Title`)
- Valid AsciiDoc syntax
- Proper heading hierarchy
- No trailing whitespace
- No tabs (use spaces)
- xrefs have link text
- Attributes are used correctly

❌ **Common Issues:**
- Missing document title
- Broken xref links
- Empty link text in xrefs
- Trailing whitespace
- Tabs instead of spaces
- Undefined attributes

### Build Tools

✅ **Checks:**
- Container runtime available (podman or docker)
- Python 3 available (for YAML validation)
- Optional: asciidoctor, yamllint, markdownlint

❌ **Common Issues:**
- No container runtime installed
- Python 3 not available

## Validation Workflow

### Recommended Development Workflow

```bash
# 1. Make changes to content
vim content/modules/ROOT/pages/module-01.adoc

# 2. Validate manually (optional but recommended)
make validate

# 3. Stage changes
git add content/modules/ROOT/pages/module-01.adoc

# 4. Commit (pre-commit validation runs automatically)
git commit -m "Update module 01 content"

# 5. Build site (pre-build validation runs automatically)
make build

# 6. Serve and review
make serve
# Browse to http://localhost:8080/index.html
```

### Quick Validation Before Building

```bash
# Validate everything before building
make validate && make build

# Or use the combined clean-build target
make clean-build
```

### Continuous Integration Workflow

```bash
# Full validation and build
./scripts/validate-documents.sh && \
./scripts/validate-antora-site.sh && \
./utilities/lab-build
```

## Handling Validation Errors

### Error: "YAML syntax error"

**Cause:** Invalid YAML syntax in configuration files

**Solution:**
```bash
# Check YAML syntax
yamllint default-site.yml
yamllint content/antora.yml

# Common fixes:
# - Use 2 spaces for indentation (not tabs)
# - Ensure proper key: value format
# - Check for missing colons or quotes
```

### Error: "Navigation references missing page"

**Cause:** Navigation file references a page that doesn't exist

**Solution:**
```bash
# Check navigation file
cat content/modules/ROOT/nav.adoc

# Ensure referenced pages exist
ls content/modules/ROOT/pages/

# Fix: Either create the missing page or remove the reference
```

### Error: "Missing document title"

**Cause:** AsciiDoc page missing top-level title

**Solution:**
```asciidoc
= Your Page Title

Your content here...
```

### Error: "asciidoctor validation failed"

**Cause:** Invalid AsciiDoc syntax

**Solution:**
```bash
# Test with asciidoctor directly
asciidoctor --safe-mode=safe --failure-level=WARN \
  content/modules/ROOT/pages/your-page.adoc

# Common fixes:
# - Check heading hierarchy (don't skip levels)
# - Ensure proper attribute syntax: {attribute-name}
# - Check xref syntax: xref:page.adoc[Link Text]
```

### Warning: "Contains xrefs with empty link text"

**Cause:** Cross-references without descriptive link text

**Solution:**
```asciidoc
# Bad
xref:module-01.adoc[]

# Good
xref:module-01.adoc[Module 01: Introduction]
```

## Configuration Options

### Skip Validation

```bash
# Skip pre-build validation (not recommended)
./utilities/lab-build --skip-validation

# Skip document validation in pre-build
SKIP_DOC_VALIDATION=true ./scripts/validate-antora-site.sh
```

### Force Build

```bash
# Build even if validation has warnings
./utilities/lab-build --force
make build-force
```

## Best Practices

### 1. Validate Early and Often

```bash
# Before committing
make validate

# Before building
make validate && make build
```

### 2. Use Pre-Commit Hooks

```bash
# Ensure hooks are configured
git config core.hooksPath
# Should output: .githooks

# Test hooks
./scripts/validate-documents.sh content/antora.yml
```

### 3. Keep Configuration Clean

- Use consistent indentation (2 spaces)
- Keep attributes organized in `content/antora.yml`
- Document custom attributes
- Validate after configuration changes

### 4. Maintain Navigation

- Keep navigation in sync with pages
- Use descriptive link text
- Organize logically
- Test all navigation links

### 5. Write Clean AsciiDoc

- Always include document title
- Use proper heading hierarchy
- Provide link text for xrefs
- Define attributes before use
- Remove trailing whitespace

## Troubleshooting

### Validation passes but build fails

**Possible causes:**
- Antora-specific syntax issues
- Missing UI bundle
- Network issues downloading UI bundle
- Container runtime issues

**Solution:**
```bash
# Check Antora build logs
./utilities/lab-build

# Test with verbose output
podman run --rm -v "./:/antora:z" \
  docker.io/antora/antora --stacktrace default-site.yml
```

### Pre-commit hook not running

**Solution:**
```bash
# Check git configuration
git config core.hooksPath

# Reconfigure if needed
git config core.hooksPath .githooks

# Ensure hooks are executable
chmod +x .githooks/*
```

### Validation tools not found

**Solution:**
```bash
# Install required tools
pip3 install --user yamllint
gem install asciidoctor
npm install -g markdownlint-cli

# Or run developer setup
./scripts/developer-setup.sh
```

## Integration with CI/CD

Example GitHub Actions workflow:

```yaml
name: Validate and Build Site

on: [push, pull_request]

jobs:
  validate-and-build:
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
      
      - name: Validate Antora site
        run: ./scripts/validate-antora-site.sh
      
      - name: Build site
        run: ./utilities/lab-build
      
      - name: Upload site artifact
        uses: actions/upload-artifact@v3
        with:
          name: site
          path: www/
```

## Additional Resources

- [Antora Documentation](https://docs.antora.org/)
- [AsciiDoc Syntax Quick Reference](https://docs.asciidoctor.org/asciidoc/latest/syntax-quick-reference/)
- [Pre-Commit Hooks Documentation](PRE_COMMIT_HOOKS.md)
- [Developer Guide](../DEVELOPER_GUIDE.md)

