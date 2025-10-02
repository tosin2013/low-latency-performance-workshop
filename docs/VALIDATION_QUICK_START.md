# Document Validation Quick Start

## Overview

The workshop includes automatic document validation to catch formatting errors **before** building the site with `utilities/lab-build`.

## What Gets Validated

✅ **YAML files** (`.yml`, `.yaml`)
- Syntax errors
- Indentation issues
- Trailing spaces

✅ **AsciiDoc files** (`.adoc`)
- Document structure
- Heading hierarchy
- Trailing whitespace
- Tabs vs spaces

✅ **Markdown files** (`.md`)
- Syntax errors
- Formatting issues

## Quick Usage

### Validate Before Building

```bash
# Validation runs automatically when you build
make build
# or
./utilities/lab-build
```

### Manual Validation

```bash
# Validate all documents
make validate

# Validate specific file
./scripts/validate-documents.sh content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc

# Validate multiple files
./scripts/validate-documents.sh content/modules/ROOT/pages/*.adoc
```

### Skip Validation (Not Recommended)

```bash
./utilities/lab-build --skip-validation
```

## Example Output

### ✅ Success
```
==================================================
ℹ Document Validation Script
==================================================

ℹ Found 10 document(s) to validate

ℹ Validating AsciiDoc: content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc
✓ AsciiDoc validation passed: content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc

==================================================
ℹ Validation Summary
==================================================
Total files checked: 10
Passed: 10
Failed: 0
Warnings: 0

✓ All documents validated successfully!
```

### ❌ Failure
```
ℹ Validating YAML: default-site.yml
✗ yamllint found errors in default-site.yml
default-site.yml
  3:69      error    trailing spaces  (trailing-spaces)

✗ Document validation failed!
```

## Common Issues and Fixes

### Incorrect Anchor Format

**Error:** `File uses [id="..."] format - use [[anchor-name]] or [#anchor-name] instead`

This is a **critical formatting error** that causes incorrect rendering of section anchors.

**Wrong:**
```asciidoc
[id="openshift-virtualization"]
== OpenShift Virtualization Overview
```

**Correct:**
```asciidoc
[[openshift-virtualization]]
== OpenShift Virtualization Overview
```

**Fix all files automatically:**
```bash
find content/modules/ROOT/pages -name "*.adoc" -exec sed -i 's/^\[id="\([^"]*\)"\]$/[[\1]]/g' {} \;
```

### Unbalanced Code Blocks

**Error:** `File has unbalanced code block delimiters (----)`

This means a code block was opened with `----` but never closed (or vice versa).

**Example of broken formatting:**
```asciidoc
[source,bash]
----
echo "Some command"
echo "More commands"

. **Next step**:    ← Missing closing ---- before this!
```

**How to find and fix:**
```bash
# Check a specific file
grep -n "^----$" content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc

# Count should be even (each opening ---- needs a closing ----)
# Manually add the missing ---- delimiter
```

### Trailing Whitespace

**Warning:** `File contains trailing whitespace`

**Fix:**
```bash
# Remove trailing whitespace from all files
find content/modules/ROOT/pages -name "*.adoc" -exec sed -i 's/[[:space:]]*$//' {} \;

# Or configure your editor to remove trailing whitespace on save
```

### YAML Indentation

**Error:** `YAML syntax error`

**Fix:**
- Use 2 spaces for indentation (not tabs)
- Ensure consistent indentation
- Check for missing colons

### Missing Document Title

**Error:** `Module file missing document title (= Title)`

**Fix:**
```asciidoc
= Your Page Title

Your content here...
```

## Integration with Git Hooks

The validation also runs automatically when you commit:

```bash
# Setup (one time)
./scripts/developer-setup.sh

# Normal workflow - validation runs on commit
git add content/modules/ROOT/pages/my-page.adoc
git commit -m "Update content"
```

## Workflow

```
┌─────────────────────┐
│  Edit Documents     │
│  (AsciiDoc, YAML)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Validate           │
│  make validate      │
└──────────┬──────────┘
           │
           ▼
    ┌──────────┐
    │ Passed?  │
    └─┬────┬───┘
      │    │
   No │    │ Yes
      │    │
      ▼    ▼
   ┌────┐ ┌─────────────────┐
   │Fix │ │  Build Site     │
   │    │ │  make build     │
   └────┘ └────────┬────────┘
                   │
                   ▼
           ┌───────────────┐
           │  Serve Site   │
           │  make serve   │
           └───────────────┘
```

## Additional Resources

- [Pre-Commit Hooks Documentation](PRE_COMMIT_HOOKS.md)
- [Site Validation Guide](SITE_VALIDATION.md)
- [Developer Guide](../DEVELOPER_GUIDE.md)

