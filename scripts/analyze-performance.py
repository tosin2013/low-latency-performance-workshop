#!/usr/bin/env python3
"""
Performance Analysis Script for Low-Latency Workshop
Analyzes kube-burner test results and generates comprehensive reports
"""

import json
import os
import sys
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import statistics

# Color codes for terminal output
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

    @staticmethod
    def disable():
        """Disable colors for non-terminal output"""
        Colors.RED = Colors.GREEN = Colors.YELLOW = Colors.BLUE = ''
        Colors.MAGENTA = Colors.CYAN = Colors.WHITE = Colors.BOLD = ''
        Colors.UNDERLINE = Colors.END = ''

class PerformanceAnalyzer:
    """Analyzes kube-burner performance test results"""
    
    def __init__(self, base_dir: str = "~/kube-burner-configs"):
        self.base_dir = Path(base_dir).expanduser()
        self.results = {}
        
    def load_metrics(self, metrics_dir: str) -> Dict:
        """Load metrics from a kube-burner results directory"""
        metrics_path = self.base_dir / metrics_dir
        
        if not metrics_path.exists():
            print(f"❌ Metrics directory not found: {metrics_path}")
            return {}
            
        results = {
            'directory': metrics_dir,
            'pod_latency_quantiles': {},
            'pod_latency_individual': [],
            'vmi_latency_quantiles': {},
            'test_summary': {}
        }
        
        # Load pod latency quantiles
        for file in metrics_path.glob("*podLatencyQuantilesMeasurement*.json"):
            try:
                with open(file) as f:
                    data = json.load(f)
                    for item in data:
                        if item.get('quantileName'):
                            results['pod_latency_quantiles'][item['quantileName']] = {
                                'P50': item.get('P50', 0),
                                'P95': item.get('P95', 0),
                                'P99': item.get('P99', 0),
                                'avg': item.get('avg', 0),
                                'max': item.get('max', 0)
                            }
            except Exception as e:
                print(f"⚠️  Error loading {file}: {e}")
        
        # Load VMI latency quantiles (if available)
        for file in metrics_path.glob("*vmiLatencyQuantilesMeasurement*.json"):
            try:
                with open(file) as f:
                    data = json.load(f)
                    for item in data:
                        if item.get('quantileName'):
                            results['vmi_latency_quantiles'][item['quantileName']] = {
                                'P50': item.get('P50', 0),
                                'P95': item.get('P95', 0),
                                'P99': item.get('P99', 0),
                                'avg': item.get('avg', 0),
                                'max': item.get('max', 0)
                            }
            except Exception as e:
                print(f"⚠️  Error loading VMI metrics {file}: {e}")
        
        # Load job summary
        for file in metrics_path.glob("jobSummary.json"):
            try:
                with open(file) as f:
                    data = json.load(f)
                    # Handle both list and dict formats
                    if isinstance(data, list) and len(data) > 0:
                        results['test_summary'] = data[0]
                    elif isinstance(data, dict):
                        results['test_summary'] = data
                    else:
                        results['test_summary'] = {}
            except Exception as e:
                print(f"⚠️  Error loading job summary {file}: {e}")
        
        return results
    
    def analyze_single_test(self, metrics_dir: str) -> None:
        """Analyze a single test result"""
        print(f"\n{Colors.CYAN}🔍 Analyzing {Colors.BOLD}{metrics_dir}{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 50}{Colors.END}")

        # Educational context
        is_baseline = "baseline" in metrics_dir.lower() or metrics_dir == "collected-metrics"
        is_tuned = "tuned" in metrics_dir.lower()

        if is_baseline:
            print(f"\n{Colors.YELLOW}📚 Educational Context:{Colors.END}")
            print(f"   This is your {Colors.BOLD}BASELINE{Colors.END} test - performance before tuning")
            print(f"   Use this as a reference point to measure improvements")
        elif is_tuned:
            print(f"\n{Colors.YELLOW}📚 Educational Context:{Colors.END}")
            print(f"   This is your {Colors.BOLD}TUNED{Colors.END} test - performance after optimization")
            print(f"   Compare with baseline to see the impact of performance tuning")

        results = self.load_metrics(metrics_dir)
        if not results:
            return

        # Pod latency analysis
        if results['pod_latency_quantiles']:
            print(f"\n{Colors.MAGENTA}📊 Pod Latency Metrics:{Colors.END}")
            print(f"\n{Colors.YELLOW}💡 What these metrics mean:{Colors.END}")
            print(f"   • {Colors.BOLD}PodScheduled{Colors.END}: Time to assign pod to a node")
            print(f"   • {Colors.BOLD}Initialized{Colors.END}: Time for init containers to complete")
            print(f"   • {Colors.BOLD}ContainersReady{Colors.END}: Time for all containers to start")
            print(f"   • {Colors.BOLD}Ready{Colors.END}: Total time until pod is fully ready")
            print(f"   • {Colors.BOLD}P50/P95/P99{Colors.END}: 50th/95th/99th percentile latencies")
            print("")

            for condition, metrics in results['pod_latency_quantiles'].items():
                # Color code based on performance
                p99 = metrics['P99']
                if p99 < 1000:  # < 1 second
                    color = Colors.GREEN
                    status = "🚀 Excellent"
                    explanation = "Very fast - ideal for low-latency workloads"
                elif p99 < 5000:  # < 5 seconds
                    color = Colors.YELLOW
                    status = "✅ Good"
                    explanation = "Acceptable performance for most workloads"
                else:  # >= 5 seconds
                    color = Colors.RED
                    status = "⚠️ Needs Attention"
                    explanation = "Slower than ideal - may indicate resource contention"

                print(f"  {Colors.BOLD}{condition}{Colors.END} {color}({status}){Colors.END}:")
                print(f"    {Colors.GREEN}P50: {metrics['P50']:.1f}ms{Colors.END}")
                print(f"    {Colors.YELLOW}P95: {metrics['P95']:.1f}ms{Colors.END}")
                print(f"    {Colors.RED}P99: {metrics['P99']:.1f}ms{Colors.END}")
                print(f"    {Colors.CYAN}Avg: {metrics['avg']:.1f}ms{Colors.END}")
                print(f"    {Colors.MAGENTA}Max: {metrics['max']:.1f}ms{Colors.END}")
                print(f"    {Colors.WHITE}💭 {explanation}{Colors.END}")
                print("")
        
        # VMI latency analysis (if available)
        if results['vmi_latency_quantiles']:
            print(f"\n{Colors.BLUE}🖥️  VMI Latency Metrics:{Colors.END}")
            for condition, metrics in results['vmi_latency_quantiles'].items():
                # Color code based on performance
                p99 = metrics['P99']
                if p99 < 2000:  # < 2 seconds for VMs
                    color = Colors.GREEN
                    status = "🚀 Excellent"
                elif p99 < 10000:  # < 10 seconds
                    color = Colors.YELLOW
                    status = "✅ Good"
                else:  # >= 10 seconds
                    color = Colors.RED
                    status = "⚠️ Needs Attention"

                print(f"  {Colors.BOLD}{condition}{Colors.END} {color}({status}){Colors.END}:")
                print(f"    {Colors.GREEN}P50: {metrics['P50']:.1f}ms{Colors.END}")
                print(f"    {Colors.YELLOW}P95: {metrics['P95']:.1f}ms{Colors.END}")
                print(f"    {Colors.RED}P99: {metrics['P99']:.1f}ms{Colors.END}")
                print(f"    {Colors.CYAN}Avg: {metrics['avg']:.1f}ms{Colors.END}")
                print(f"    {Colors.MAGENTA}Max: {metrics['max']:.1f}ms{Colors.END}")

        # Test summary
        if results['test_summary']:
            summary = results['test_summary']
            print(f"\n{Colors.CYAN}📋 Test Summary:{Colors.END}")

            total_jobs = summary.get('jobsTotal', 'N/A')
            successful_jobs = summary.get('jobsSuccessful', 'N/A')
            failed_jobs = summary.get('jobsFailed', 'N/A')

            # Color code job success rate
            if isinstance(total_jobs, (int, float)) and isinstance(successful_jobs, (int, float)):
                success_rate = (successful_jobs / total_jobs) * 100 if total_jobs > 0 else 0
                if success_rate >= 95:
                    job_color = Colors.GREEN
                    job_status = "✅"
                elif success_rate >= 80:
                    job_color = Colors.YELLOW
                    job_status = "⚠️"
                else:
                    job_color = Colors.RED
                    job_status = "❌"
            else:
                job_color = Colors.WHITE
                job_status = "ℹ️"

            print(f"  {job_color}Total Jobs: {total_jobs} {job_status}{Colors.END}")
            print(f"  {Colors.GREEN}Successful Jobs: {successful_jobs}{Colors.END}")
            print(f"  {Colors.RED}Failed Jobs: {failed_jobs}{Colors.END}")
            print(f"  {Colors.BLUE}Test Duration: {summary.get('elapsedTime', 'N/A')}{Colors.END}")

        # Educational summary for single test
        print(f"\n{Colors.BOLD}{Colors.CYAN}🎓 Learning Summary:{Colors.END}")
        if is_baseline:
            print(f"   📊 This baseline shows your cluster's {Colors.BOLD}default performance{Colors.END}")
            print(f"   🎯 Next: Apply performance tuning and compare results")
            print(f"   💡 Look for improvements in scheduling (PodScheduled) and overall latency")
        elif is_tuned:
            print(f"   📈 This shows performance {Colors.BOLD}after optimization{Colors.END}")
            print(f"   🔍 Key areas to evaluate:")
            print(f"      • PodScheduled should be much faster (ideally <100ms)")
            print(f"      • Overall Ready time should improve significantly")
            print(f"      • Some container operations may be slower due to CPU isolation")
            print(f"   💡 Run comparison: --compare to see the full improvement story")
        else:
            print(f"   📋 This test shows current cluster performance")
            print(f"   🔄 Compare with other tests to understand performance changes")
            print(f"   📚 Use --compare flag to see side-by-side improvements")

        # Suggest next steps based on available data
        baseline_exists = (self.base_dir / "collected-metrics").exists()
        tuned_exists = (self.base_dir / "collected-metrics-tuned").exists()

        print(f"\n{Colors.BOLD}{Colors.GREEN}🚀 Suggested Next Steps:{Colors.END}")
        if is_baseline and not tuned_exists:
            print(f"   1. Apply performance tuning (Module 4)")
            print(f"   2. Run tuned performance test")
            print(f"   3. Compare results with: --compare")
        elif is_tuned and baseline_exists:
            print(f"   1. Compare with baseline: {Colors.CYAN}--compare{Colors.END}")
            print(f"   2. Generate report: {Colors.CYAN}--report results.md{Colors.END}")
            print(f"   3. Analyze the performance improvements")
        elif baseline_exists and tuned_exists and not is_baseline and not is_tuned:
            print(f"   1. Compare baseline vs tuned: {Colors.CYAN}--compare{Colors.END}")
            print(f"   2. Analyze individual tests: {Colors.CYAN}--single collected-metrics{Colors.END}")
        else:
            print(f"   1. Run more tests to build comparison data")
            print(f"   2. Use {Colors.CYAN}--compare{Colors.END} when you have baseline and tuned results")
    
    def compare_tests(self, baseline_dir: str, tuned_dir: str) -> None:
        """Compare baseline vs tuned test results"""
        print(f"\n{Colors.BOLD}{Colors.MAGENTA}📊 Performance Comparison: {baseline_dir} vs {tuned_dir}{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 60}{Colors.END}")

        baseline = self.load_metrics(baseline_dir)
        tuned = self.load_metrics(tuned_dir)

        if not baseline or not tuned:
            print(f"{Colors.RED}❌ Cannot compare - missing test data{Colors.END}")
            return

        # Compare pod latency metrics
        print(f"\n{Colors.CYAN}🚀 Pod Latency Comparison:{Colors.END}")
        print(f"{Colors.BOLD}{'Metric':<20} {'Baseline':<12} {'Tuned':<12} {'Improvement':<15} {'Status'}{Colors.END}")
        print(f"{Colors.BLUE}{'-' * 75}{Colors.END}")
        
        for condition in baseline['pod_latency_quantiles']:
            if condition in tuned['pod_latency_quantiles']:
                baseline_metrics = baseline['pod_latency_quantiles'][condition]
                tuned_metrics = tuned['pod_latency_quantiles'][condition]
                
                for metric in ['P50', 'P95', 'P99', 'avg']:
                    baseline_val = baseline_metrics[metric]
                    tuned_val = tuned_metrics[metric]

                    if baseline_val > 0:
                        improvement = ((baseline_val - tuned_val) / baseline_val) * 100

                        # Color code improvements
                        if improvement > 20:
                            status_color = Colors.GREEN
                            status = "🚀 Excellent"
                        elif improvement > 5:
                            status_color = Colors.GREEN
                            status = "✅ Better"
                        elif improvement > -5:
                            status_color = Colors.YELLOW
                            status = "➖ Similar"
                        else:
                            status_color = Colors.RED
                            status = "⚠️ Worse"

                        # Color code the improvement percentage
                        if improvement > 0:
                            improvement_color = Colors.GREEN
                        elif improvement < -5:
                            improvement_color = Colors.RED
                        else:
                            improvement_color = Colors.YELLOW

                        print(f"{Colors.BOLD}{condition} {metric:<8}{Colors.END} "
                              f"{Colors.CYAN}{baseline_val:<8.1f}ms{Colors.END} "
                              f"{Colors.MAGENTA}{tuned_val:<8.1f}ms{Colors.END} "
                              f"{improvement_color}{improvement:<8.1f}%{Colors.END} "
                              f"{status_color}{status}{Colors.END}")
        
        # Generate improvement summary
        ready_baseline = baseline['pod_latency_quantiles'].get('Ready', {})
        ready_tuned = tuned['pod_latency_quantiles'].get('Ready', {})

        if ready_baseline and ready_tuned:
            p99_improvement = ((ready_baseline['P99'] - ready_tuned['P99']) / ready_baseline['P99']) * 100
            avg_improvement = ((ready_baseline['avg'] - ready_tuned['avg']) / ready_baseline['avg']) * 100

            print(f"\n{Colors.BOLD}{Colors.YELLOW}🎯 Key Improvements:{Colors.END}")

            # Color code P99 improvement
            p99_color = Colors.GREEN if p99_improvement > 0 else Colors.RED
            avg_color = Colors.GREEN if avg_improvement > 0 else Colors.RED

            print(f"  {Colors.BOLD}P99 Latency:{Colors.END} {p99_color}{p99_improvement:.1f}% improvement{Colors.END}")
            print(f"  {Colors.BOLD}Avg Latency:{Colors.END} {avg_color}{avg_improvement:.1f}% improvement{Colors.END}")

            # Overall assessment with colors and educational context
            if p99_improvement > 30:
                print(f"  {Colors.GREEN}{Colors.BOLD}🏆 Excellent performance improvement!{Colors.END}")
                print(f"  {Colors.WHITE}💡 This level of improvement shows your tuning is very effective{Colors.END}")
            elif p99_improvement > 10:
                print(f"  {Colors.GREEN}✅ Good performance improvement{Colors.END}")
                print(f"  {Colors.WHITE}💡 Solid gains - your performance tuning is working well{Colors.END}")
            elif p99_improvement > 0:
                print(f"  {Colors.YELLOW}📈 Modest performance improvement{Colors.END}")
                print(f"  {Colors.WHITE}💡 Some improvement seen - consider more aggressive tuning{Colors.END}")
            else:
                print(f"  {Colors.RED}⚠️ Performance may have degraded{Colors.END}")
                print(f"  {Colors.WHITE}💡 Check if tuning is too aggressive or causing resource contention{Colors.END}")

            # Educational explanation of what the improvements mean
            print(f"\n{Colors.BOLD}{Colors.CYAN}🎓 What These Improvements Mean:{Colors.END}")
            print(f"  📊 {Colors.BOLD}P99 improvements{Colors.END} show better worst-case performance")
            print(f"  📈 {Colors.BOLD}Average improvements{Colors.END} show overall system responsiveness")
            print(f"  🎯 {Colors.BOLD}Scheduling improvements{Colors.END} (0ms) show CPU isolation working")
            print(f"  ⚖️ {Colors.BOLD}Container delays{Colors.END} are expected trade-offs for better runtime performance")
    
    def generate_report(self, output_file: str, baseline_dir: str = None, tuned_dir: str = None, vmi_dir: str = None) -> None:
        """Generate a comprehensive markdown report"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        with open(output_file, 'w') as f:
            f.write(f"# Performance Analysis Report\n\n")
            f.write(f"**Generated:** {timestamp}\n\n")
            
            # Baseline analysis
            if baseline_dir:
                baseline = self.load_metrics(baseline_dir)
                if baseline:
                    f.write(f"## Baseline Test Results\n\n")
                    self._write_metrics_table(f, baseline['pod_latency_quantiles'], "Pod")
            
            # Tuned analysis
            if tuned_dir:
                tuned = self.load_metrics(tuned_dir)
                if tuned:
                    f.write(f"## Tuned Test Results\n\n")
                    self._write_metrics_table(f, tuned['pod_latency_quantiles'], "Pod")
            
            # VMI analysis
            if vmi_dir:
                vmi = self.load_metrics(vmi_dir)
                if vmi and vmi['vmi_latency_quantiles']:
                    f.write(f"## VMI Test Results\n\n")
                    self._write_metrics_table(f, vmi['vmi_latency_quantiles'], "VMI")
            
            # Comparison
            if baseline_dir and tuned_dir:
                f.write(f"## Performance Comparison\n\n")
                baseline = self.load_metrics(baseline_dir)
                tuned = self.load_metrics(tuned_dir)
                self._write_comparison_table(f, baseline, tuned)
        
        print(f"📄 Report generated: {output_file}")
    
    def _write_metrics_table(self, f, metrics: Dict, test_type: str) -> None:
        """Write metrics table to markdown file"""
        f.write(f"| {test_type} Condition | P50 (ms) | P95 (ms) | P99 (ms) | Avg (ms) | Max (ms) |\n")
        f.write("|---|---|---|---|---|---|\n")
        
        for condition, data in metrics.items():
            f.write(f"| {condition} | {data['P50']:.1f} | {data['P95']:.1f} | {data['P99']:.1f} | {data['avg']:.1f} | {data['max']:.1f} |\n")
        f.write("\n")
    
    def _write_comparison_table(self, f, baseline: Dict, tuned: Dict) -> None:
        """Write comparison table to markdown file"""
        f.write("| Metric | Baseline | Tuned | Improvement | Status |\n")
        f.write("|---|---|---|---|---|\n")
        
        for condition in baseline['pod_latency_quantiles']:
            if condition in tuned['pod_latency_quantiles']:
                baseline_metrics = baseline['pod_latency_quantiles'][condition]
                tuned_metrics = tuned['pod_latency_quantiles'][condition]
                
                for metric in ['P99', 'avg']:
                    baseline_val = baseline_metrics[metric]
                    tuned_val = tuned_metrics[metric]
                    
                    if baseline_val > 0:
                        improvement = ((baseline_val - tuned_val) / baseline_val) * 100
                        status = "✅ Better" if improvement > 0 else "⚠️ Worse"
                        
                        f.write(f"| {condition} {metric} | {baseline_val:.1f}ms | {tuned_val:.1f}ms | {improvement:.1f}% | {status} |\n")
        f.write("\n")

def main():
    parser = argparse.ArgumentParser(description="Analyze kube-burner performance test results")
    parser.add_argument("--baseline", help="Baseline metrics directory", default="collected-metrics")
    parser.add_argument("--tuned", help="Tuned metrics directory", default="collected-metrics-tuned")
    parser.add_argument("--vmi", help="VMI metrics directory", default="collected-metrics-vmi")
    parser.add_argument("--compare", action="store_true", help="Compare baseline vs tuned")
    parser.add_argument("--report", help="Generate markdown report to file")
    parser.add_argument("--single", help="Analyze single test directory")
    parser.add_argument("--no-color", action="store_true", help="Disable colored output")

    args = parser.parse_args()

    # Disable colors if requested or if not in a terminal
    if args.no_color or not sys.stdout.isatty():
        Colors.disable()
    
    analyzer = PerformanceAnalyzer()
    
    if args.single:
        analyzer.analyze_single_test(args.single)
    elif args.compare:
        analyzer.compare_tests(args.baseline, args.tuned)
    elif args.report:
        analyzer.generate_report(args.report, args.baseline, args.tuned, args.vmi)
    else:
        # Default: analyze all available tests
        print(f"{Colors.BOLD}{Colors.CYAN}🔍 Performance Analysis Summary{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 40}{Colors.END}")
        
        if Path(analyzer.base_dir / args.baseline).exists():
            analyzer.analyze_single_test(args.baseline)
        
        if Path(analyzer.base_dir / args.tuned).exists():
            analyzer.analyze_single_test(args.tuned)
        
        if Path(analyzer.base_dir / args.vmi).exists():
            analyzer.analyze_single_test(args.vmi)
        
        # Compare if both baseline and tuned exist
        if (Path(analyzer.base_dir / args.baseline).exists() and 
            Path(analyzer.base_dir / args.tuned).exists()):
            analyzer.compare_tests(args.baseline, args.tuned)

if __name__ == "__main__":
    main()
