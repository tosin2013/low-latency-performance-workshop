# Workshop Scripts

This directory contains scripts for development, validation, analysis, and testing for the Low-Latency Performance Workshop.

## Scripts Overview

### 🚀 Developer Tools

#### `developer-setup.sh`
**Purpose**: Automated setup script for new developers joining the project.

**Features**:
- ✅ Checks for required tools (git, node, npm, python3)
- ✅ Installs optional tools (yamllint, asciidoctor, markdownlint)
- ✅ Installs Node.js dependencies
- ✅ Configures git hooks for automatic document validation
- ✅ Creates local development configuration
- ✅ Displays next steps and useful commands

**Usage**:
```bash
# Run from repository root
./scripts/developer-setup.sh
```

**What it does**:
1. Validates system prerequisites
2. Offers to install missing optional tools
3. Installs npm packages
4. Configures git hooks directory
5. Creates `.env` file for local development
6. Shows helpful next steps

**First-time setup**:
```bash
git clone https://github.com/tosin2013/low-latency-performance-workshop.git
cd low-latency-performance-workshop
./scripts/developer-setup.sh
```

#### `validate-documents.sh`
**Purpose**: Validates document formatting for YAML, AsciiDoc, and Markdown files.

**Features**:
- ✅ YAML syntax and structure validation
- ✅ AsciiDoc syntax and formatting validation
- ✅ Markdown syntax and formatting validation
- ✅ Checks for common issues (trailing whitespace, tabs, etc.)
- ✅ Integrates with pre-commit hooks
- ✅ Detailed error reporting

**Usage**:
```bash
# Validate all tracked documents
./scripts/validate-documents.sh

# Validate specific files
./scripts/validate-documents.sh content/modules/ROOT/pages/module-01-low-latency-intro.adoc

# Validate multiple files
./scripts/validate-documents.sh file1.adoc file2.yaml file3.md
```

**Validation checks**:
- **YAML**: Syntax, structure, yamllint rules
- **AsciiDoc**: Syntax, heading hierarchy, asciidoctor validation
- **Markdown**: Syntax, heading structure, markdownlint rules

**Prerequisites**:
- `python3` (required)
- `yamllint` (required)
- `asciidoctor` (optional but recommended)
- `markdownlint` or `mdl` (optional but recommended)

**Exit codes**:
- `0` - All validations passed
- `1` - Validation failed or missing required tools

### 📊 Analysis Tools

### 🔍 `analyze-performance.py`
**Purpose**: Analyzes kube-burner test results and generates comprehensive performance reports.

**Features**:
- Parses JSON metrics from kube-burner output
- Compares baseline vs tuned performance
- Generates markdown reports
- Calculates improvement percentages
- Supports both pod and VMI metrics

**Usage Examples**:
```bash
# Analyze single test results
python3 scripts/analyze-performance.py --single collected-metrics

# Compare baseline vs tuned results
python3 scripts/analyze-performance.py --compare

# Generate comprehensive markdown report
python3 scripts/analyze-performance.py --report performance-report.md

# Analyze all available tests (default)
python3 scripts/analyze-performance.py
```

### 🏥 `cluster-health-check.py`
**Purpose**: Validates cluster state and performance profile application.

**Features**:
- Detects cluster architecture (SNO, Multi-Node, Multi-Master)
- Checks performance profile status
- Validates RT kernel installation
- Verifies CPU isolation configuration
- Tests pod scheduling functionality
- Color-coded status indicators

**Usage Examples**:
```bash
# Run comprehensive health check
python3 scripts/cluster-health-check.py

# Save results to JSON file
python3 scripts/cluster-health-check.py --save
```

### 🎯 `performance-summary.py`
**Purpose**: Provides quick overview of current performance settings and recommendations.

**Features**:
- Analyzes CPU allocation strategy
- Categorizes tuning level (Aggressive/Balanced/Conservative/Minimal)
- Provides color-coded recommendations
- Calculates isolation percentages
- Suggests optimizations based on cluster type

**Usage Examples**:
```bash
# Get performance tuning summary
python3 scripts/performance-summary.py

# Disable colors for scripting
python3 scripts/performance-summary.py --no-color
```

### 🖥️ `vmi_performance_analyzer.py` *(NEW)*
**Purpose**: Educational analysis of OpenShift Virtualization performance with container comparison.

**Features**:
- VMI startup phase analysis with educational explanations
- Comparison between VMI and container performance
- Color-coded performance assessment with thresholds
- Educational insights about virtualization overhead
- Optimization recommendations based on performance data

**Usage Examples**:
```bash
# Analyze VMI performance with educational insights
python3 scripts/vmi_performance_analyzer.py --metrics-dir ~/kube-burner-configs

# Disable colors for scripting
python3 scripts/vmi_performance_analyzer.py --metrics-dir ~/kube-burner-configs --no-color
```

### 🌐 `network_policy_analyzer.py` *(NEW)*
**Purpose**: Educational analysis of network policy performance impact with security trade-off insights.

**Features**:
- Network policy enforcement latency analysis
- Performance vs security trade-off explanations
- Best practices for low-latency network policies
- Educational report generation with optimization strategies
- CNI performance impact insights

**Usage Examples**:
```bash
# Basic network policy performance analysis
python3 scripts/network_policy_analyzer.py --metrics-dir ~/kube-burner-configs --analysis-type latency

# Comprehensive analysis with educational report
python3 scripts/network_policy_analyzer.py --metrics-dir ~/kube-burner-configs --analysis-type comprehensive --output-format educational
```

## Requirements

### Python Dependencies
```bash
# Install required packages
pip install PyYAML

# Or using system packages (RHEL/CentOS)
sudo dnf install python3-pyyaml
```

### OpenShift CLI
- `oc` command must be available and configured
- User must have cluster-admin or sufficient permissions

## Integration with Workshop Modules

### Module 3: Baseline Performance
```bash
# After running baseline tests
cd ~/kube-burner-configs
python3 ~/low-latency-performance-workshop/scripts/analyze-performance.py --single collected-metrics
```

### Module 4: Performance Tuning
```bash
# Verify cluster health after applying performance profile
python3 ~/low-latency-performance-workshop/scripts/cluster-health-check.py

# Compare baseline vs tuned performance
cd ~/kube-burner-configs
python3 ~/low-latency-performance-workshop/scripts/analyze-performance.py --compare

# Generate comprehensive report
python3 ~/low-latency-performance-workshop/scripts/analyze-performance.py --report tuning-results.md
```

### Module 5: Virtualization
```bash
# Analyze VMI performance with educational insights
cd ~/low-latency-performance-workshop/scripts
python3 vmi_performance_analyzer.py --metrics-dir ~/kube-burner-configs

# Compare VMI vs container performance
python3 analyze-performance.py --baseline collected-metrics --vmi collected-metrics-vmi --compare

# Analyze network policy performance impact
python3 network_policy_analyzer.py --metrics-dir ~/kube-burner-configs --analysis-type comprehensive --output-format educational

# Generate comprehensive VMI performance report
python3 analyze-performance.py --baseline collected-metrics --vmi collected-metrics-vmi --report ~/kube-burner-configs/vmi_performance_report.md
```

## Output Examples

### Performance Analysis Output
```
🔍 Analyzing collected-metrics-tuned
==================================================

📊 Pod Latency Metrics:
  Ready:
    P50: 1234.5ms
    P95: 2345.6ms
    P99: 3456.7ms
    Avg: 1500.2ms
    Max: 4567.8ms

📋 Test Summary:
  Total Jobs: 20
  Successful Jobs: 20
  Failed Jobs: 0
  Test Duration: 120.5s
```

### Health Check Output
```
🏥 Comprehensive Cluster Health Check
==================================================

🔍 Detecting cluster architecture...
✅ Detected: SNO
   Total nodes: 1
   Master nodes: 1
   Worker nodes: 0

🔍 Checking Performance Profile...
✅ Found Performance Profile: sno-low-latency-profile
   Isolated CPUs: 4-15
   Reserved CPUs: 0-3
   RT Kernel: True

📊 Health Check Summary
==============================
Cluster Nodes: ✅ All Ready
Performance Profile: ✅ Available
RT Kernel: ✅ 1/1 nodes
CPU Isolation: ✅ 1/1 nodes
Pod Scheduling: ✅ Working

Overall Status: ✅ Healthy
```

## Educational Benefits of Python Scripts

The workshop's Python scripts transform the learning experience from "copy-paste commands" to genuine educational opportunities:

### 🎓 **Educational Value**
- **Visual Learning**: Color-coded output helps identify performance issues quickly
- **Educational Context**: Each metric includes explanations of what it means and why it matters
- **Comparative Analysis**: Scripts compare different approaches and explain trade-offs
- **Best Practices**: Built-in recommendations based on performance analysis results
- **Statistical Insights**: Proper percentile analysis and performance assessment

### 📊 **Performance Analysis Features**
- **VMI vs Container Comparison**: Understand virtualization overhead and trade-offs
- **Network Policy Impact**: Learn how security controls affect performance
- **Phase-by-Phase Analysis**: Break down complex startup processes into understandable phases
- **Threshold-Based Assessment**: Color-coded performance evaluation with clear criteria

### 🔍 **Learning Outcomes**
- Understand performance percentiles (P50, P95, P99) and their significance
- Learn to interpret performance data and identify optimization opportunities
- Gain insights into OpenShift performance characteristics
- Develop skills in performance analysis and troubleshooting

## Benefits Over Bash Scripts

### ✅ **Cleaner and More Readable**
- No complex bash/jq/awk combinations
- Clear error handling and status reporting
- Structured data processing with educational explanations

### ✅ **More Reliable**
- Proper JSON parsing instead of text manipulation
- Better error handling and edge case management
- Consistent output formatting with educational context

### ✅ **More Powerful**
- Statistical calculations and comparisons
- Comprehensive report generation with insights
- Extensible for future educational enhancements

### ✅ **Better User Experience**
- Clear visual indicators (✅ ❌ ⚠️) with explanations
- Structured output with educational sections
- Actionable insights and learning-focused recommendations

## Troubleshooting

### Common Issues

**Script not found**:
```bash
# Make sure you're in the workshop directory
cd ~/low-latency-performance-workshop
python3 scripts/analyze-performance.py
```

**Permission denied**:
```bash
# Make scripts executable
chmod +x scripts/*.py
```

**PyYAML not found**:
```bash
# Install PyYAML
pip install PyYAML
# or
sudo dnf install python3-pyyaml
```

**No metrics found**:
```bash
# Check if kube-burner tests have been run
ls ~/kube-burner-configs/collected-metrics*/
```

## Contributing

When adding new analysis features:

1. Follow the existing code structure
2. Add proper error handling
3. Include clear status indicators
4. Update this README with usage examples
5. Test with different cluster configurations

## Future Enhancements

Potential improvements:
- Historical performance tracking
- Automated regression detection
- Integration with monitoring systems
- Custom threshold configuration
- Multi-cluster comparison support
