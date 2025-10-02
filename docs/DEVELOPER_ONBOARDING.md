# Developer Onboarding Guide

Welcome to the Low-Latency Performance Workshop project! This guide will help you get started quickly.

## Quick Start (5 minutes)

### 1. Clone the Repository

```bash
git clone https://github.com/tosin2013/low-latency-performance-workshop.git
cd low-latency-performance-workshop
```

### 2. Run the Setup Script

```bash
./scripts/developer-setup.sh
```

This automated script will:
- ✅ Check for required tools (git, node, npm, python3)
- ✅ Install optional tools (yamllint, asciidoctor, markdownlint)
- ✅ Install Node.js dependencies
- ✅ Configure git hooks for automatic document validation
- ✅ Create local development configuration
- ✅ Show you next steps

### 3. Start Developing

```bash
# Build the documentation
make build

# Serve locally (opens on http://localhost:8080)
make serve

# Make your changes
vim content/modules/ROOT/pages/module-01-low-latency-intro.adoc

# Commit (validation happens automatically)
git add .
git commit -m "Your changes"
```

## What You Need to Know

### Project Structure

```
low-latency-performance-workshop/
├── content/                    # Workshop content (AsciiDoc)
│   └── modules/ROOT/pages/    # Module pages
├── gitops/                     # GitOps configurations
│   ├── kube-burner-configs/   # Performance testing configs
│   └── openshift-virtualization/ # CNV configs
├── scripts/                    # Utility scripts
│   ├── developer-setup.sh     # New developer setup
│   ├── validate-documents.sh  # Document validation
│   └── *.py                   # Analysis scripts
├── .githooks/                  # Git hooks
│   ├── pre-commit             # Pre-commit validation
│   └── README.md              # Hooks documentation
├── utilities/                  # Lab utilities
│   ├── lab-build              # Build documentation
│   ├── lab-serve              # Serve documentation
│   ├── lab-stop               # Stop server
│   └── lab-clean              # Clean build
├── Makefile                    # Build automation
├── DEVELOPER_GUIDE.md          # Comprehensive developer guide
└── README.adoc                 # Project README
```

### Key Files

- **`content/modules/ROOT/pages/*.adoc`** - Workshop module content
- **`content/antora.yml`** - Antora configuration
- **`default-site.yml`** - Site generation configuration
- **`gitops/`** - GitOps configurations for workshop deployment
- **`scripts/`** - Utility and analysis scripts

### Common Tasks

#### Build Documentation

```bash
# Using make (recommended)
make build

# Or manually
antora default-site.yml
```

#### Serve Documentation Locally

```bash
# Using make (recommended)
make serve

# Or manually
cd www && python3 -m http.server 8080
```

#### Validate Documents

```bash
# Validate all documents
./scripts/validate-documents.sh

# Validate specific file
./scripts/validate-documents.sh content/modules/ROOT/pages/module-01-low-latency-intro.adoc
```

#### Run Tests

```bash
# Run JavaScript tests
npm test

# Test all Python scripts
./scripts/test-all-scripts.sh
```

#### Clean Build

```bash
# Using make
make clean-build

# Or manually
make clean
make build
```

### Document Validation

The project uses **pre-commit hooks** to automatically validate documents before commits.

**What gets validated:**
- ✅ YAML syntax and structure
- ✅ AsciiDoc syntax and formatting
- ✅ Markdown syntax and formatting

**How it works:**
1. You make changes to documents
2. You stage changes: `git add file.adoc`
3. You commit: `git commit -m "message"`
4. Pre-commit hook validates staged documents
5. If validation passes, commit succeeds
6. If validation fails, commit is blocked with error messages

**Bypass validation** (not recommended):
```bash
git commit --no-verify -m "Skip validation"
```

### Writing Workshop Content

#### AsciiDoc Guidelines

```asciidoc
= Module Title (Level 0 - Document Title)

== Section Title (Level 1)

=== Subsection Title (Level 2)

==== Sub-subsection Title (Level 3)

// Use consistent formatting for code blocks
[source,bash,role=execute]
----
oc get nodes
----

// Use consistent formatting for YAML
[source,yaml]
----
apiVersion: v1
kind: Pod
metadata:
  name: example
----

// Use admonitions for important notes
[NOTE]
====
This is an important note.
====

[WARNING]
====
This is a warning.
====
```

#### Best Practices

1. **Use clear, descriptive headings**
2. **Include code examples** with proper syntax highlighting
3. **Add explanations** before and after code blocks
4. **Use admonitions** (NOTE, WARNING, TIP) appropriately
5. **Test all commands** in an actual workshop environment
6. **Keep modules focused** - one topic per module
7. **Use consistent terminology** throughout

### Git Workflow

```bash
# 1. Create a feature branch
git checkout -b feature/your-feature-name

# 2. Make your changes
vim content/modules/ROOT/pages/module-01-low-latency-intro.adoc

# 3. Test locally
make clean-build
make serve

# 4. Stage your changes
git add content/modules/ROOT/pages/module-01-low-latency-intro.adoc

# 5. Commit (validation runs automatically)
git commit -m "Update module 01: Add performance tuning section"

# 6. Push to your fork
git push origin feature/your-feature-name

# 7. Create a pull request on GitHub
```

### Useful Commands

```bash
# Build and serve in one command
make run-all

# Stop and clean
make stop-clean

# Show all make targets
make help

# Validate all documents
./scripts/validate-documents.sh

# Run all tests
npm test
./scripts/test-all-scripts.sh

# Check cluster health (requires OpenShift access)
python3 scripts/cluster-health-check.py

# Analyze performance results
python3 scripts/analyze-performance.py
```

## Prerequisites

### Required Tools

- **Git** - Version control
- **Node.js 16+** - For Antora
- **npm** - Node package manager
- **Python 3.x** - For scripts and validation

### Optional but Recommended

- **asciidoctor** - AsciiDoc validation
- **yamllint** - YAML validation (required for pre-commit hooks)
- **markdownlint** - Markdown validation
- **oc** - OpenShift CLI (for testing)

### Installation

**RHEL/Fedora:**
```bash
sudo dnf install git nodejs npm python3 python3-pip rubygem-asciidoctor
pip3 install --user yamllint
npm install -g markdownlint-cli
```

**Ubuntu/Debian:**
```bash
sudo apt-get install git nodejs npm python3 python3-pip asciidoctor
pip3 install --user yamllint
npm install -g markdownlint-cli
```

**macOS:**
```bash
brew install git node python3 asciidoctor
pip3 install yamllint
npm install -g markdownlint-cli
```

## Getting Help

### Documentation

- **[DEVELOPER_GUIDE.md](../DEVELOPER_GUIDE.md)** - Comprehensive developer guide
- **[ENVIRONMENT_CONFIG.md](../ENVIRONMENT_CONFIG.md)** - Environment configuration
- **[.githooks/README.md](../.githooks/README.md)** - Git hooks documentation
- **[scripts/README.md](../scripts/README.md)** - Scripts documentation

### Common Issues

**"Permission denied" when running scripts:**
```bash
chmod +x scripts/*.sh .githooks/*
```

**"yamllint not found":**
```bash
pip3 install --user yamllint
```

**"asciidoctor not found":**
```bash
# RHEL/Fedora
sudo dnf install rubygem-asciidoctor

# Ubuntu/Debian
sudo apt-get install asciidoctor

# macOS
brew install asciidoctor
```

**Pre-commit hook not running:**
```bash
git config core.hooksPath .githooks
chmod +x .githooks/*
```

**Build fails:**
```bash
# Clean and rebuild
make clean-build

# Check for syntax errors
./scripts/validate-documents.sh
```

### Support

- **Issues**: Open an issue on GitHub
- **Questions**: Check existing issues or create a new one
- **Contributions**: See [Contributing Guidelines](../DEVELOPER_GUIDE.md#contributing-guidelines)

## Next Steps

1. **Read the [DEVELOPER_GUIDE.md](../DEVELOPER_GUIDE.md)** for comprehensive information
2. **Explore the workshop content** in `content/modules/ROOT/pages/`
3. **Try building and serving** the documentation locally
4. **Make a small change** and test the validation workflow
5. **Review existing modules** to understand the structure and style

## Welcome to the Team! 🎉

You're now ready to contribute to the Low-Latency Performance Workshop. If you have any questions or run into issues, don't hesitate to ask for help!

Happy coding! 🚀

