#!/usr/bin/env python3
"""
Module 3: Baseline Performance Analyzer
Educational wrapper for baseline performance analysis

This script provides a simplified, educational interface for analyzing
baseline performance metrics collected in Module 3 of the workshop.
"""

import os
import sys
import argparse
import subprocess
from pathlib import Path
from datetime import datetime

# Color codes for terminal output
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'

    @staticmethod
    def disable():
        """Disable colors for non-terminal output"""
        Colors.RED = Colors.GREEN = Colors.YELLOW = Colors.BLUE = ''
        Colors.MAGENTA = Colors.CYAN = Colors.BOLD = Colors.END = ''


def print_educational_header():
    """Print educational header explaining baseline analysis"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}📊 Module 3: Baseline Performance Analysis{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}🎓 What is Baseline Performance?{Colors.END}")
    print(f"{Colors.CYAN}Baseline performance establishes the starting point for your cluster.")
    print(f"It measures how your cluster performs BEFORE any optimizations are applied.")
    print(f"This baseline is critical for measuring the impact of performance tuning.{Colors.END}\n")
    
    print(f"{Colors.BOLD}📈 Key Metrics We're Measuring:{Colors.END}")
    print(f"  • {Colors.GREEN}Pod Creation Latency{Colors.END} - How long it takes to create and start pods")
    print(f"  • {Colors.GREEN}Scheduling Latency{Colors.END} - How long it takes to schedule pods to nodes")
    print(f"  • {Colors.GREEN}Container Startup Time{Colors.END} - How long containers take to become ready")
    print(f"  • {Colors.GREEN}P50, P95, P99 Percentiles{Colors.END} - Statistical distribution of latencies\n")
    
    print(f"{Colors.BOLD}💡 Why This Matters:{Colors.END}")
    print(f"{Colors.CYAN}Without a baseline, you can't measure improvement!")
    print(f"Module 4 will apply performance tuning, and we'll compare against this baseline")
    print(f"to see exactly how much faster your cluster becomes.{Colors.END}\n")


def print_metric_explanation():
    """Print explanation of performance metrics"""
    print(f"\n{Colors.BOLD}{Colors.YELLOW}📚 Understanding Performance Metrics{Colors.END}")
    print(f"{Colors.YELLOW}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Percentiles Explained:{Colors.END}")
    print(f"  • {Colors.GREEN}P50 (Median){Colors.END} - 50% of operations complete in this time or less")
    print(f"    Example: P50 = 2s means half of pods start in 2 seconds or less")
    print(f"  • {Colors.GREEN}P95{Colors.END} - 95% of operations complete in this time or less")
    print(f"    Example: P95 = 5s means 95% of pods start in 5 seconds or less")
    print(f"  • {Colors.GREEN}P99{Colors.END} - 99% of operations complete in this time or less")
    print(f"    Example: P99 = 10s means 99% of pods start in 10 seconds or less\n")
    
    print(f"{Colors.BOLD}Why P99 Matters Most:{Colors.END}")
    print(f"{Colors.CYAN}P99 represents your 'worst case' performance for most users.")
    print(f"If P99 is 10 seconds, 1 out of 100 users will wait that long.")
    print(f"Low-latency systems focus on reducing P99 to ensure consistent performance.{Colors.END}\n")
    
    print(f"{Colors.BOLD}Good vs Bad Baseline Performance:{Colors.END}")
    print(f"  {Colors.GREEN}✅ Excellent{Colors.END}: P99 < 3 seconds")
    print(f"  {Colors.YELLOW}⚠️  Good{Colors.END}: P99 3-6 seconds")
    print(f"  {Colors.RED}❌ Needs Improvement{Colors.END}: P99 > 6 seconds\n")


def check_baseline_metrics_exist(metrics_dir: str) -> bool:
    """Check if baseline metrics directory exists"""
    metrics_path = Path(metrics_dir).expanduser()
    
    if not metrics_path.exists():
        print(f"{Colors.RED}❌ Baseline metrics not found at: {metrics_path}{Colors.END}")
        print(f"\n{Colors.YELLOW}💡 Have you completed Module 3 baseline testing?{Colors.END}")
        print(f"{Colors.CYAN}To collect baseline metrics, run:{Colors.END}")
        print(f"  cd ~/kube-burner-configs")
        print(f"  kube-burner init -c baseline-config.yml --log-level=info\n")
        return False
    
    # Check for expected metric files
    expected_files = [
        "podLatencyQuantilesMeasurement-baseline-workload.json",
        "podLatencyMeasurement-baseline-workload.json"
    ]
    
    missing_files = []
    for file in expected_files:
        if not (metrics_path / file).exists():
            missing_files.append(file)
    
    if missing_files:
        print(f"{Colors.YELLOW}⚠️  Some metric files are missing:{Colors.END}")
        for file in missing_files:
            print(f"  • {file}")
        print(f"\n{Colors.CYAN}The baseline test may not have completed successfully.{Colors.END}\n")
        return False
    
    print(f"{Colors.GREEN}✅ Baseline metrics found at: {metrics_path}{Colors.END}\n")
    return True


def run_baseline_analysis(metrics_dir: str, generate_report: bool = False):
    """Run the core analyze-performance.py script for baseline analysis"""
    script_dir = Path(__file__).parent
    analyzer_script = script_dir / "analyze-performance.py"
    
    if not analyzer_script.exists():
        print(f"{Colors.RED}❌ Core analyzer script not found: {analyzer_script}{Colors.END}")
        return False
    
    print(f"{Colors.BOLD}{Colors.BLUE}🔍 Analyzing Baseline Performance...{Colors.END}\n")
    
    # Build command
    cmd = [sys.executable, str(analyzer_script), "--single", metrics_dir]
    
    if generate_report:
        report_name = f"module3-baseline-report-{datetime.now().strftime('%Y%m%d-%H%M')}.md"
        cmd.extend(["--report", report_name])
        print(f"{Colors.CYAN}📄 Generating report: {report_name}{Colors.END}\n")
    
    # Run the analyzer
    try:
        result = subprocess.run(cmd, check=True)
        return result.returncode == 0
    except subprocess.CalledProcessError as e:
        print(f"\n{Colors.RED}❌ Analysis failed with error code: {e.returncode}{Colors.END}")
        return False
    except Exception as e:
        print(f"\n{Colors.RED}❌ Unexpected error: {e}{Colors.END}")
        return False


def print_next_steps():
    """Print next steps after baseline analysis"""
    print(f"\n{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}✅ Baseline Analysis Complete!{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}🎯 What You've Accomplished:{Colors.END}")
    print(f"  ✓ Established baseline performance metrics")
    print(f"  ✓ Measured pod creation and scheduling latency")
    print(f"  ✓ Identified current cluster performance characteristics\n")
    
    print(f"{Colors.BOLD}📚 Next Steps in the Workshop:{Colors.END}")
    print(f"  1️⃣  {Colors.CYAN}Module 4{Colors.END}: Apply performance tuning (CPU isolation, HugePages, RT kernel)")
    print(f"  2️⃣  {Colors.CYAN}Module 4{Colors.END}: Re-run performance tests to measure improvements")
    print(f"  3️⃣  {Colors.CYAN}Module 4{Colors.END}: Compare tuned performance against this baseline")
    print(f"  4️⃣  {Colors.CYAN}Module 5{Colors.END}: Optimize virtual machine performance")
    print(f"  5️⃣  {Colors.CYAN}Module 6{Colors.END}: Set up monitoring and validation\n")
    
    print(f"{Colors.BOLD}💡 Pro Tip:{Colors.END}")
    print(f"{Colors.YELLOW}Save your baseline results! You'll compare against them in Module 4.")
    print(f"Expected improvement with performance tuning: 50-70% reduction in P99 latency.{Colors.END}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Module 3: Baseline Performance Analyzer - Educational wrapper for baseline analysis",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Analyze baseline metrics from default location
  python3 module03-baseline-analyzer.py
  
  # Analyze baseline metrics from custom location
  python3 module03-baseline-analyzer.py --metrics-dir ~/custom-metrics/collected-metrics
  
  # Generate a markdown report
  python3 module03-baseline-analyzer.py --report
  
  # Disable colored output
  python3 module03-baseline-analyzer.py --no-color

Educational Focus:
  This script helps you understand baseline performance by:
  • Explaining what baseline metrics mean
  • Showing how to interpret P50, P95, P99 percentiles
  • Providing context for performance improvements in Module 4
        """
    )
    
    parser.add_argument(
        "--metrics-dir",
        default="collected-metrics",
        help="Directory containing baseline metrics (default: collected-metrics)"
    )
    
    parser.add_argument(
        "--report",
        action="store_true",
        help="Generate a markdown report of baseline performance"
    )
    
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable colored output"
    )
    
    parser.add_argument(
        "--skip-explanation",
        action="store_true",
        help="Skip educational explanations (for experienced users)"
    )
    
    args = parser.parse_args()
    
    # Disable colors if requested or not in a TTY
    if args.no_color or not sys.stdout.isatty():
        Colors.disable()
    
    # Print educational header
    if not args.skip_explanation:
        print_educational_header()
        print_metric_explanation()
    
    # Check if baseline metrics exist
    if not check_baseline_metrics_exist(args.metrics_dir):
        sys.exit(1)
    
    # Run baseline analysis
    success = run_baseline_analysis(args.metrics_dir, args.report)
    
    if success and not args.skip_explanation:
        print_next_steps()
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

