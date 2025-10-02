#!/usr/bin/env python3
"""
Module 3: Performance Metrics Explainer
Interactive educational tool for understanding performance metrics

This script provides interactive explanations of performance metrics
including P50, P95, P99 percentiles, latency concepts, and how to
interpret performance test results.
"""

import sys
import argparse
from typing import List

# Color codes for terminal output
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

    @staticmethod
    def disable():
        """Disable colors for non-terminal output"""
        Colors.RED = Colors.GREEN = Colors.YELLOW = Colors.BLUE = ''
        Colors.MAGENTA = Colors.CYAN = Colors.BOLD = Colors.UNDERLINE = Colors.END = ''


def print_header():
    """Print main header"""
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}📚 Module 3: Performance Metrics Explainer{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}\n")


def explain_percentiles():
    """Explain percentile metrics in detail"""
    print(f"{Colors.BOLD}{Colors.BLUE}📊 Understanding Percentiles{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}What are Percentiles?{Colors.END}")
    print(f"{Colors.CYAN}Percentiles tell you how data is distributed across all measurements.")
    print(f"They answer: 'What percentage of operations completed within X time?'{Colors.END}\n")
    
    print(f"{Colors.BOLD}The Three Key Percentiles:{Colors.END}\n")
    
    # P50 Explanation
    print(f"{Colors.GREEN}1. P50 (50th Percentile / Median){Colors.END}")
    print(f"   • 50% of operations complete in this time or less")
    print(f"   • Represents the 'typical' or 'average' user experience")
    print(f"   • Example: If P50 = 2 seconds, half of your pods start in 2s or less\n")
    
    print(f"   {Colors.BOLD}Real-World Analogy:{Colors.END}")
    print(f"   {Colors.CYAN}If 100 people order coffee, P50 is the time by which 50 people")
    print(f"   have received their coffee.{Colors.END}\n")
    
    # P95 Explanation
    print(f"{Colors.YELLOW}2. P95 (95th Percentile){Colors.END}")
    print(f"   • 95% of operations complete in this time or less")
    print(f"   • Only 5% of operations take longer than this")
    print(f"   • Represents 'most users' experience, excluding outliers")
    print(f"   • Example: If P95 = 5 seconds, 95% of pods start in 5s or less\n")
    
    print(f"   {Colors.BOLD}Real-World Analogy:{Colors.END}")
    print(f"   {Colors.CYAN}Out of 100 coffee orders, 95 people get their coffee within this time.")
    print(f"   Only 5 people wait longer.{Colors.END}\n")
    
    # P99 Explanation
    print(f"{Colors.RED}3. P99 (99th Percentile){Colors.END}")
    print(f"   • 99% of operations complete in this time or less")
    print(f"   • Only 1% of operations take longer than this")
    print(f"   • Represents your 'worst case' for most users")
    print(f"   • Example: If P99 = 10 seconds, 99% of pods start in 10s or less\n")
    
    print(f"   {Colors.BOLD}Real-World Analogy:{Colors.END}")
    print(f"   {Colors.CYAN}Out of 100 coffee orders, 99 people get their coffee within this time.")
    print(f"   Only 1 person waits longer.{Colors.END}\n")
    
    print(f"{Colors.BOLD}Visual Example:{Colors.END}")
    print(f"{Colors.CYAN}Imagine 100 pod creation times (in seconds):{Colors.END}")
    print(f"  [1, 1, 2, 2, 2, 3, 3, 3, 3, 4, ... 8, 9, 10, 15, 20]")
    print(f"  {Colors.GREEN}P50 = 3s{Colors.END}  (50th value)")
    print(f"  {Colors.YELLOW}P95 = 10s{Colors.END} (95th value)")
    print(f"  {Colors.RED}P99 = 15s{Colors.END} (99th value)\n")


def explain_why_p99_matters():
    """Explain why P99 is critical for low-latency systems"""
    print(f"{Colors.BOLD}{Colors.MAGENTA}🎯 Why P99 Matters Most for Low-Latency Systems{Colors.END}")
    print(f"{Colors.MAGENTA}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}The Problem with Averages:{Colors.END}")
    print(f"{Colors.CYAN}Average (mean) latency can be misleading!")
    print(f"Example: 99 pods start in 1 second, 1 pod takes 100 seconds")
    print(f"  • Average = 1.99 seconds (looks great!)")
    print(f"  • But 1% of users wait 100 seconds (terrible experience!){Colors.END}\n")
    
    print(f"{Colors.BOLD}Why Focus on P99?{Colors.END}")
    print(f"  1️⃣  {Colors.GREEN}User Experience{Colors.END}: P99 represents the worst experience most users see")
    print(f"  2️⃣  {Colors.GREEN}At Scale{Colors.END}: With millions of requests, 1% is still thousands of users")
    print(f"  3️⃣  {Colors.GREEN}SLA Compliance{Colors.END}: Service Level Agreements often target P99")
    print(f"  4️⃣  {Colors.GREEN}System Health{Colors.END}: High P99 indicates system instability\n")
    
    print(f"{Colors.BOLD}Real-World Impact:{Colors.END}")
    print(f"{Colors.YELLOW}If your application handles 1,000,000 requests per day:")
    print(f"  • P99 = 10s means 10,000 users wait 10+ seconds daily")
    print(f"  • P99 = 2s means only 10,000 users wait 2+ seconds daily")
    print(f"  • That's 8 seconds saved for 10,000 users!{Colors.END}\n")
    
    print(f"{Colors.BOLD}Low-Latency Goal:{Colors.END}")
    print(f"{Colors.GREEN}Reduce P99 to ensure consistent, predictable performance for ALL users,")
    print(f"not just the average user.{Colors.END}\n")


def explain_latency_types():
    """Explain different types of latency measured"""
    print(f"{Colors.BOLD}{Colors.BLUE}⏱️  Types of Latency in Kubernetes{Colors.END}")
    print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}1. Pod Creation Latency{Colors.END}")
    print(f"   {Colors.CYAN}Time from pod creation request to pod running")
    print(f"   Includes: API processing, scheduling, image pull, container start{Colors.END}")
    print(f"   {Colors.GREEN}Good{Colors.END}: < 5 seconds | {Colors.YELLOW}Acceptable{Colors.END}: 5-10s | {Colors.RED}Poor{Colors.END}: > 10s\n")
    
    print(f"{Colors.BOLD}2. Scheduling Latency{Colors.END}")
    print(f"   {Colors.CYAN}Time from pod creation to pod scheduled to a node")
    print(f"   Includes: Scheduler decision-making, resource availability checks{Colors.END}")
    print(f"   {Colors.GREEN}Good{Colors.END}: < 1 second | {Colors.YELLOW}Acceptable{Colors.END}: 1-3s | {Colors.RED}Poor{Colors.END}: > 3s\n")
    
    print(f"{Colors.BOLD}3. Container Startup Latency{Colors.END}")
    print(f"   {Colors.CYAN}Time from container creation to container ready")
    print(f"   Includes: Image pull, container runtime initialization{Colors.END}")
    print(f"   {Colors.GREEN}Good{Colors.END}: < 3 seconds | {Colors.YELLOW}Acceptable{Colors.END}: 3-8s | {Colors.RED}Poor{Colors.END}: > 8s\n")
    
    print(f"{Colors.BOLD}4. VMI (Virtual Machine Instance) Startup Latency{Colors.END}")
    print(f"   {Colors.CYAN}Time from VMI creation to VMI running")
    print(f"   Includes: VM scheduling, disk provisioning, OS boot{Colors.END}")
    print(f"   {Colors.GREEN}Good{Colors.END}: < 60 seconds | {Colors.YELLOW}Acceptable{Colors.END}: 60-120s | {Colors.RED}Poor{Colors.END}: > 120s\n")


def explain_performance_goals():
    """Explain performance goals and targets"""
    print(f"{Colors.BOLD}{Colors.GREEN}🎯 Performance Goals for This Workshop{Colors.END}")
    print(f"{Colors.GREEN}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Module 3: Baseline (Current State){Colors.END}")
    print(f"  • Measure current performance without optimizations")
    print(f"  • Typical P99 pod creation: 5-10 seconds")
    print(f"  • Establishes starting point for improvements\n")
    
    print(f"{Colors.BOLD}Module 4: Performance Tuning (Target State){Colors.END}")
    print(f"  • Apply CPU isolation, HugePages, RT kernel")
    print(f"  • Target: 50-70% reduction in P99 latency")
    print(f"  • Expected P99 pod creation: 2-5 seconds\n")
    
    print(f"{Colors.BOLD}Module 5: Virtualization Optimization{Colors.END}")
    print(f"  • Optimize VM startup and networking")
    print(f"  • Target: VMI P99 < 90 seconds")
    print(f"  • Network policy latency < 10 seconds\n")
    
    print(f"{Colors.BOLD}Module 6: Sustained Performance{Colors.END}")
    print(f"  • Monitor and validate optimizations")
    print(f"  • Ensure performance remains consistent")
    print(f"  • Detect and prevent regressions\n")


def explain_how_to_interpret():
    """Explain how to interpret performance test results"""
    print(f"{Colors.BOLD}{Colors.CYAN}🔍 How to Interpret Your Results{Colors.END}")
    print(f"{Colors.CYAN}{'─'*70}{Colors.END}\n")
    
    print(f"{Colors.BOLD}Step 1: Look at P99 First{Colors.END}")
    print(f"  • P99 tells you the worst experience most users will see")
    print(f"  • If P99 is good, your system is performing well\n")
    
    print(f"{Colors.BOLD}Step 2: Check the Spread (P99 - P50){Colors.END}")
    print(f"  • Small spread (< 2x): Consistent performance ✅")
    print(f"  • Large spread (> 5x): Inconsistent, needs tuning ⚠️")
    print(f"  • Example: P50=2s, P99=3s → Good (1.5x spread)")
    print(f"  • Example: P50=2s, P99=15s → Bad (7.5x spread)\n")
    
    print(f"{Colors.BOLD}Step 3: Compare Against Targets{Colors.END}")
    print(f"  • Baseline: Establish current state")
    print(f"  • Tuned: Should see 50-70% improvement")
    print(f"  • If not improving, investigate bottlenecks\n")
    
    print(f"{Colors.BOLD}Step 4: Identify Bottlenecks{Colors.END}")
    print(f"  • High scheduling latency → Scheduler overloaded")
    print(f"  • High container startup → Image pull or runtime issues")
    print(f"  • High overall latency → CPU/memory contention\n")


def interactive_quiz():
    """Interactive quiz to test understanding"""
    print(f"{Colors.BOLD}{Colors.YELLOW}🧪 Test Your Understanding{Colors.END}")
    print(f"{Colors.YELLOW}{'─'*70}{Colors.END}\n")
    
    questions = [
        {
            "question": "If P99 = 10 seconds, what percentage of operations complete in 10s or less?",
            "answer": "99%",
            "explanation": "P99 means 99% of operations complete within that time."
        },
        {
            "question": "Which metric best represents the 'worst case' for most users?",
            "answer": "P99",
            "explanation": "P99 shows the latency that 99% of users experience or better."
        },
        {
            "question": "If P50=2s and P99=20s, is this good or bad performance?",
            "answer": "Bad",
            "explanation": "Large spread (10x) indicates inconsistent performance. Needs tuning!"
        }
    ]
    
    for i, q in enumerate(questions, 1):
        print(f"{Colors.BOLD}Question {i}:{Colors.END} {q['question']}")
        print(f"{Colors.GREEN}Answer:{Colors.END} {q['answer']}")
        print(f"{Colors.CYAN}Explanation:{Colors.END} {q['explanation']}\n")


def print_summary():
    """Print summary and next steps"""
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}✅ Key Takeaways{Colors.END}")
    print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}\n")
    
    print(f"  1️⃣  {Colors.BOLD}Percentiles{Colors.END} show how data is distributed (P50, P95, P99)")
    print(f"  2️⃣  {Colors.BOLD}P99{Colors.END} is critical for low-latency systems")
    print(f"  3️⃣  {Colors.BOLD}Small spread{Colors.END} (P99-P50) indicates consistent performance")
    print(f"  4️⃣  {Colors.BOLD}Baseline{Colors.END} establishes starting point for improvements")
    print(f"  5️⃣  {Colors.BOLD}Target{Colors.END} 50-70% improvement with performance tuning\n")
    
    print(f"{Colors.BOLD}📚 Ready to Apply This Knowledge:{Colors.END}")
    print(f"  • Use {Colors.CYAN}module03-baseline-analyzer.py{Colors.END} to analyze your baseline")
    print(f"  • Proceed to Module 4 to apply performance tuning")
    print(f"  • Compare tuned results against baseline to measure improvement\n")


def main():
    parser = argparse.ArgumentParser(
        description="Module 3: Performance Metrics Explainer - Interactive educational tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This interactive tool helps you understand:
  • What percentiles (P50, P95, P99) mean
  • Why P99 is critical for low-latency systems
  • How to interpret performance test results
  • What performance goals to target

Run without arguments for full interactive explanation.
        """
    )
    
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable colored output"
    )
    
    parser.add_argument(
        "--topic",
        choices=["percentiles", "p99", "latency", "goals", "interpret", "quiz", "all"],
        default="all",
        help="Show specific topic only (default: all)"
    )
    
    args = parser.parse_args()
    
    # Disable colors if requested or not in a TTY
    if args.no_color or not sys.stdout.isatty():
        Colors.disable()
    
    print_header()
    
    if args.topic in ["percentiles", "all"]:
        explain_percentiles()
    
    if args.topic in ["p99", "all"]:
        explain_why_p99_matters()
    
    if args.topic in ["latency", "all"]:
        explain_latency_types()
    
    if args.topic in ["goals", "all"]:
        explain_performance_goals()
    
    if args.topic in ["interpret", "all"]:
        explain_how_to_interpret()
    
    if args.topic in ["quiz", "all"]:
        interactive_quiz()
    
    if args.topic == "all":
        print_summary()


if __name__ == "__main__":
    main()

