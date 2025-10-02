# Pre-Build Website Validation

## Summary

The `utilities/lab-build` script now **automatically validates** all website content files before building the Antora site. This catches formatting errors early and prevents build failures.

## What Gets Validated

### Website Content Files
- ✅ All AsciiDoc pages in `content/modules/ROOT/pages/*.adoc`
- ✅ Antora configuration: `content/antora.yml`
- ✅ Site configuration: `default-site.yml`

### Validation Checks
- **YAML Syntax**: Valid structure, proper indentation, no trailing spaces
- **AsciiDoc Format**: Document titles, heading hierarchy, no tabs, no trailing whitespace
- **File Structure**: Required sections, proper formatting

## Usage

### Automatic Validation (Default)

```bash
# Validation runs automatically before build
make build

# Or directly
./utilities/lab-build
```

**Output:**
```
==================================================
Low-Latency Performance Workshop - Build
==================================================

ℹ Validating document formatting before build...

==================================================
ℹ Document Validation Script
==================================================

ℹ Found 10 document(s) to validate

ℹ Validating AsciiDoc: content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc
✓ AsciiDoc validation passed: content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc

...

✓ All documents validated successfully!

Starting build process...
```

### Skip Validation

```bash
# Only if you need to skip validation (not recommended)
./utilities/lab-build --skip-validation
```

### Manual Validation

```bash
# Validate specific file
./scripts/validate-documents.sh content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc

# Validate all website content
./scripts/validate-documents.sh content/modules/ROOT/pages/*.adoc content/antora.yml default-site.yml
```

## Example: Validation Catches Error

### Before Fix
```bash
$ make build

ℹ Validating document formatting before build...

ℹ Validating YAML: default-site.yml
✗ yamllint found errors in default-site.yml
default-site.yml
  3:69      error    trailing spaces  (trailing-spaces)

✗ Document validation failed!

Please fix the formatting issues above before building.
```

### After Fix
```bash
$ make build

ℹ Validating document formatting before build...

✓ All documents validated successfully!

Starting build process...
Building new site...
✓ Build process complete!
```

## Common Issues

### Trailing Whitespace

**Warning:** `File contains trailing whitespace`

This is a **warning** (not an error) but should be fixed for clean code:

```bash
# Fix trailing whitespace in a file
sed -i 's/[[:space:]]*$//' content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc

# Fix all AsciiDoc files
find content/modules/ROOT/pages -name "*.adoc" -exec sed -i 's/[[:space:]]*$//' {} \;
```

### YAML Trailing Spaces

**Error:** `trailing spaces`

```bash
# Fix trailing spaces in YAML files
sed -i 's/[[:space:]]*$//' default-site.yml
sed -i 's/[[:space:]]*$//' content/antora.yml
```

### Missing Document Title

**Error:** `Module file missing document title (= Title)`

Every AsciiDoc page must start with a title:

```asciidoc
= Module 05: Low-Latency Virtualization

Your content here...
```

## Integration with Pre-Commit Hooks

For even earlier validation, set up pre-commit hooks:

```bash
# One-time setup
./scripts/developer-setup.sh

# Now validation runs on every commit
git add content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc
git commit -m "Update module 05"
# ✓ Pre-commit validation runs automatically
```

## Workflow

```
Edit Content
     ↓
Commit (pre-commit validation)
     ↓
Build (pre-build validation) ← You are here
     ↓
Antora Build
     ↓
Serve Site
```

## Benefits

✅ **Catch errors early** - Before Antora build starts
✅ **Fast feedback** - Know immediately if there's a formatting issue
✅ **Prevent build failures** - Don't waste time on builds that will fail
✅ **Consistent quality** - Enforce formatting standards
✅ **Simple** - Just run `make build` as usual

## Files Validated

The following files are validated before each build:

```
content/modules/ROOT/pages/
├── index.adoc
├── module-01-low-latency-intro.adoc
├── module-02-rhacm-setup.adoc
├── module-03-baseline-performance.adoc
├── module-04-core-performance-tuning.adoc
├── module-05-low-latency-virtualization.adoc
├── module-06-monitoring-validation.adoc
└── module-07-case-study-conclusion.adoc

content/antora.yml
default-site.yml
```

## Validation Script

The validation is performed by: `scripts/validate-documents.sh`

This script:
- Checks YAML syntax with Python's yaml module
- Validates YAML formatting with yamllint (if installed)
- Checks AsciiDoc structure and formatting
- Validates with asciidoctor (if installed)
- Reports clear errors and warnings

## Additional Resources

- [Validation Quick Start](VALIDATION_QUICK_START.md)
- [Pre-Commit Hooks Documentation](PRE_COMMIT_HOOKS.md)
- [Developer Guide](../DEVELOPER_GUIDE.md)

## Troubleshooting

### Validation is too strict

If you need to build despite warnings:
```bash
# Warnings don't block the build, only errors do
# If you have errors and need to build anyway:
./utilities/lab-build --skip-validation
```

### Want to validate without building

```bash
# Just validate, don't build
./scripts/validate-documents.sh content/modules/ROOT/pages/*.adoc content/antora.yml default-site.yml
```

### Validation script not found

```bash
# Ensure you're in the repository root
cd /path/to/low-latency-performance-workshop

# Check script exists
ls -la scripts/validate-documents.sh

# Make it executable if needed
chmod +x scripts/validate-documents.sh
```

