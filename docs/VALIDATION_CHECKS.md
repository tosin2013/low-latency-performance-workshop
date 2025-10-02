# Validation Checks Reference

This document lists all the validation checks performed by `scripts/validate-documents.sh` before building the site.

## AsciiDoc Validation Checks

### 1. Incorrect Anchor Format ❌ ERROR

**Check:** Detects `[id="anchor-name"]` format on a separate line before headings

**Why it's wrong:** This format doesn't render properly in Antora and causes broken anchor links

**Example - Wrong:**
```asciidoc
[id="openshift-virtualization"]
== OpenShift Virtualization Overview
```

**Example - Correct:**
```asciidoc
[[openshift-virtualization]]
== OpenShift Virtualization Overview
```

**How to fix:**
```bash
# Fix all files automatically
find content/modules/ROOT/pages -name "*.adoc" -exec sed -i 's/^\[id="\([^"]*\)"\]$/[[\1]]/g' {} \;
```

---

### 2. Unbalanced Code Blocks ❌ ERROR

**Check:** Counts `----` delimiters to ensure they're balanced (even number)

**Why it's wrong:** An unclosed code block breaks the entire page formatting

**Example - Wrong:**
```asciidoc
[source,bash]
----
echo "Command 1"
echo "Command 2"

. **Next step**:    ← Missing closing ---- here!
+
[source,bash]
----
echo "Command 3"
----
```

**Example - Correct:**
```asciidoc
[source,bash]
----
echo "Command 1"
echo "Command 2"
----

. **Next step**:
+
[source,bash]
----
echo "Command 3"
----
```

**How to fix:**
```bash
# Check code block count in a file
grep -n "^----$" content/modules/ROOT/pages/your-file.adoc

# Count should be even - manually add missing ---- delimiter
```

---

### 3. Missing Document Title ❌ ERROR

**Check:** Module files must have a top-level title starting with `=`

**Why it's wrong:** Antora requires a document title for proper navigation

**Example - Wrong:**
```asciidoc
== Section Title

Content here...
```

**Example - Correct:**
```asciidoc
= Module 05: Low-Latency Virtualization

== Section Title

Content here...
```

---

### 4. Trailing Whitespace ⚠️ WARNING

**Check:** Detects spaces or tabs at the end of lines

**Why it's a problem:** Inconsistent formatting, can cause issues with some tools

**How to fix:**
```bash
# Fix a single file
sed -i 's/[[:space:]]*$//' content/modules/ROOT/pages/your-file.adoc

# Fix all AsciiDoc files
find content/modules/ROOT/pages -name "*.adoc" -exec sed -i 's/[[:space:]]*$//' {} \;
```

---

### 5. Tabs Instead of Spaces ⚠️ WARNING

**Check:** Detects tab characters in the file

**Why it's a problem:** Inconsistent indentation, AsciiDoc prefers spaces

**How to fix:**
```bash
# Convert tabs to spaces (2 spaces per tab)
expand -t 2 your-file.adoc > your-file.adoc.tmp && mv your-file.adoc.tmp your-file.adoc
```

---

### 6. Deep Heading Hierarchy ⚠️ WARNING

**Check:** Detects level 5 headings (`======`)

**Why it's a problem:** Too many heading levels can indicate poor document structure

**Recommendation:** Restructure content to use fewer heading levels

---

### 7. Empty xref Link Text ⚠️ WARNING

**Check:** Detects `xref:page.adoc[]` without link text

**Why it's a problem:** Less readable, doesn't provide context

**Example - Not ideal:**
```asciidoc
See xref:module-01.adoc[] for details.
```

**Example - Better:**
```asciidoc
See xref:module-01.adoc[Module 01: Introduction] for details.
```

---

### 8. AsciiDoctor Validation (if installed)

**Check:** Runs `asciidoctor --safe-mode=safe --failure-level=WARN` on the file

**What it catches:**
- Invalid AsciiDoc syntax
- Broken includes
- Invalid attributes
- Malformed tables
- And more...

**Install:**
```bash
gem install asciidoctor
```

---

## YAML Validation Checks

### 1. YAML Syntax ❌ ERROR

**Check:** Validates YAML can be parsed by Python's yaml module

**What it catches:**
- Invalid YAML structure
- Missing colons
- Incorrect indentation
- Invalid characters

---

### 2. yamllint Checks (if installed) ❌ ERROR

**Check:** Runs `yamllint -d relaxed` on YAML files

**What it catches:**
- Trailing spaces
- Line too long
- Missing newline at end of file
- Inconsistent indentation
- And more...

**Install:**
```bash
pip3 install yamllint
```

---

## Markdown Validation Checks

### 1. Trailing Whitespace ⚠️ WARNING

Same as AsciiDoc check

---

### 2. Tabs Instead of Spaces ⚠️ WARNING

Same as AsciiDoc check

---

### 3. Missing Top-Level Heading ⚠️ WARNING

**Check:** Markdown files should start with `#` heading

**Exception:** README.md files are exempt from this check

---

### 4. markdownlint Checks (if installed) ⚠️ WARNING

**Check:** Runs `markdownlint` on Markdown files

**Install:**
```bash
npm install -g markdownlint-cli
```

---

## Validation Severity Levels

### ❌ ERROR
- **Blocks the build** (unless `--skip-validation` is used)
- Must be fixed before building
- Indicates a critical formatting issue

### ⚠️ WARNING
- **Does not block the build**
- Should be fixed for code quality
- Indicates a minor formatting issue

---

## Running Validation

### Automatic (Recommended)
```bash
# Runs automatically before build
make build
./utilities/lab-build
```

### Manual
```bash
# Validate all website content
./scripts/validate-documents.sh content/modules/ROOT/pages/*.adoc content/antora.yml default-site.yml

# Validate specific file
./scripts/validate-documents.sh content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc

# Validate all tracked files
make validate
```

### Skip Validation
```bash
# Not recommended, but available if needed
./utilities/lab-build --skip-validation
```

---

## Installing Validation Tools

### Required
- **Python 3** - For YAML validation
- **yamllint** - For YAML linting

```bash
pip3 install yamllint
```

### Optional (Recommended)
- **asciidoctor** - For comprehensive AsciiDoc validation
- **markdownlint** - For Markdown validation

```bash
# Install asciidoctor
gem install asciidoctor

# Install markdownlint
npm install -g markdownlint-cli
```

### Full Setup
```bash
# Run the developer setup script
./scripts/developer-setup.sh
```

---

## Validation Output

### Success
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

### Failure
```
ℹ Validating AsciiDoc: content/modules/ROOT/pages/module-05-low-latency-virtualization.adoc
✗ File uses [id="..."] format - use [[anchor-name]] or [#anchor-name] instead
ℹ Found problematic anchors:
[id="openshift-virtualization"]

==================================================
ℹ Validation Summary
==================================================
Total files checked: 1
Passed: 0
Failed: 1
Warnings: 0

✗ Document validation failed!
```

---

## See Also

- [Validation Quick Start](VALIDATION_QUICK_START.md)
- [Pre-Build Validation](PRE_BUILD_VALIDATION.md)
- [Pre-Commit Hooks](PRE_COMMIT_HOOKS.md)
- [Developer Guide](../DEVELOPER_GUIDE.md)

