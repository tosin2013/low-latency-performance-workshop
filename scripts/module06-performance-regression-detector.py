#!/usr/bin/env python3
"""
Module 6: Performance Regression Detector
Detects performance regressions by comparing current vs historical metrics

This script compares current performance against historical baselines
to detect regressions and alert on performance degradation.
"""

import subprocess
import json
import sys
import argparse
import os
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from datetime import datetime
import statistics

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


class RegressionDetector:
    """Detects performance regressions"""
    
    def __init__(self, metrics_dir: str, baseline_file: str, threshold: float = 10.0):
        self.metrics_dir = Path(metrics_dir).expanduser()
        self.baseline_file = Path(baseline_file).expanduser() if baseline_file else None
        self.threshold = threshold  # Percentage threshold for regression
        self.regressions_found = []
        
    def print_header(self):
        """Print detector header"""
        print(f"\n{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}🔍 Performance Regression Detector{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}{'='*70}{Colors.END}\n")
        
        print(f"{Colors.BOLD}🎯 Detection Strategy:{Colors.END}")
        print(f"  • Compare current metrics against historical baseline")
        print(f"  • Alert on regressions exceeding {self.threshold}% threshold")
        print(f"  • Analyze P50, P95, and P99 latency percentiles")
        print(f"  • Identify performance degradation trends\n")
    
    def load_baseline(self) -> Optional[Dict]:
        """Load baseline performance data"""
        print(f"{Colors.BOLD}{Colors.BLUE}📊 Loading Baseline Data{Colors.END}")
        print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
        
        if not self.baseline_file or not self.baseline_file.exists():
            print(f"{Colors.YELLOW}⚠️  No baseline file found{Colors.END}")
            print(f"{Colors.CYAN}💡 Create baseline with: --save-baseline{Colors.END}\n")
            return None
        
        try:
            with open(self.baseline_file, 'r') as f:
                baseline = json.load(f)
            
            print(f"{Colors.GREEN}✅ Baseline loaded: {self.baseline_file}{Colors.END}")
            print(f"  • Created: {baseline.get('timestamp', 'Unknown')}")
            print(f"  • Metrics: {len(baseline.get('metrics', {}))} types")
            print()
            
            return baseline
        except Exception as e:
            print(f"{Colors.RED}❌ Failed to load baseline: {e}{Colors.END}\n")
            return None
    
    def parse_metrics_file(self, file_path: Path) -> Optional[Dict]:
        """Parse a metrics JSON file"""
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
            return data
        except Exception as e:
            print(f"{Colors.YELLOW}⚠️  Failed to parse {file_path.name}: {e}{Colors.END}")
            return None
    
    def extract_latency_metrics(self, metrics_data: Dict) -> Dict:
        """Extract latency percentiles from metrics"""
        latencies = {}
        
        # Handle different metric formats
        if isinstance(metrics_data, list):
            # Array of measurements
            for item in metrics_data:
                if 'quantileName' in item and 'P99' in item['quantileName']:
                    latencies['p99'] = item.get('value', 0)
                elif 'quantileName' in item and 'P95' in item['quantileName']:
                    latencies['p95'] = item.get('value', 0)
                elif 'quantileName' in item and 'P50' in item['quantileName']:
                    latencies['p50'] = item.get('value', 0)
        elif isinstance(metrics_data, dict):
            # Dictionary format
            latencies['p99'] = metrics_data.get('P99', metrics_data.get('p99', 0))
            latencies['p95'] = metrics_data.get('P95', metrics_data.get('p95', 0))
            latencies['p50'] = metrics_data.get('P50', metrics_data.get('p50', 0))
        
        return latencies
    
    def load_current_metrics(self) -> Dict:
        """Load current performance metrics"""
        print(f"{Colors.BOLD}{Colors.BLUE}📈 Loading Current Metrics{Colors.END}")
        print(f"{Colors.BLUE}{'─'*70}{Colors.END}\n")
        
        current_metrics = {}
        
        # Look for recent metric files
        metric_types = [
            ('pod_latency', 'collected-metrics/podLatencyQuantilesMeasurement*.json'),
            ('pod_latency_tuned', 'collected-metrics-tuned/podLatencyQuantilesMeasurement*.json'),
            ('vmi_latency', 'collected-metrics-vmi/vmiLatency*.json'),
            ('netpol_latency', '**/netpolLatency*.json')
        ]
        
        for metric_type, pattern in metric_types:
            files = list(self.metrics_dir.glob(pattern))
            if files:
                # Use most recent file
                latest_file = max(files, key=lambda p: p.stat().st_mtime)
                data = self.parse_metrics_file(latest_file)
                if data:
                    latencies = self.extract_latency_metrics(data)
                    if latencies:
                        current_metrics[metric_type] = latencies
                        print(f"{Colors.GREEN}✅ {metric_type}: {latest_file.name}{Colors.END}")
        
        if not current_metrics:
            print(f"{Colors.YELLOW}⚠️  No current metrics found{Colors.END}\n")
        else:
            print()
        
        return current_metrics
    
    def calculate_regression(self, baseline_value: float, current_value: float) -> float:
        """Calculate regression percentage"""
        if baseline_value == 0:
            return 0.0
        return ((current_value - baseline_value) / baseline_value) * 100
    
    def compare_metrics(self, baseline: Dict, current: Dict):
        """Compare baseline and current metrics"""
        print(f"{Colors.BOLD}{Colors.MAGENTA}🔬 Regression Analysis{Colors.END}")
        print(f"{Colors.MAGENTA}{'─'*70}{Colors.END}\n")
        
        baseline_metrics = baseline.get('metrics', {})
        
        for metric_type, current_latencies in current.items():
            if metric_type not in baseline_metrics:
                print(f"{Colors.CYAN}ℹ️  {metric_type}: No baseline for comparison{Colors.END}\n")
                continue
            
            baseline_latencies = baseline_metrics[metric_type]
            
            print(f"{Colors.BOLD}{metric_type.replace('_', ' ').title()}:{Colors.END}")
            
            has_regression = False
            
            for percentile in ['p50', 'p95', 'p99']:
                if percentile not in current_latencies or percentile not in baseline_latencies:
                    continue
                
                baseline_val = baseline_latencies[percentile]
                current_val = current_latencies[percentile]
                regression = self.calculate_regression(baseline_val, current_val)
                
                # Determine status
                if regression > self.threshold:
                    status = f"{Colors.RED}🚨 REGRESSION{Colors.END}"
                    has_regression = True
                    self.regressions_found.append({
                        'metric': metric_type,
                        'percentile': percentile,
                        'baseline': baseline_val,
                        'current': current_val,
                        'regression': regression
                    })
                elif regression > self.threshold / 2:
                    status = f"{Colors.YELLOW}⚠️  WARNING{Colors.END}"
                elif regression < -5:
                    status = f"{Colors.GREEN}✅ IMPROVED{Colors.END}"
                else:
                    status = f"{Colors.GREEN}✅ OK{Colors.END}"
                
                print(f"  {percentile.upper()}: {baseline_val:.2f}ms → {current_val:.2f}ms "
                      f"({regression:+.1f}%) {status}")
            
            print()
    
    def save_baseline(self, current_metrics: Dict):
        """Save current metrics as baseline"""
        baseline_data = {
            'timestamp': datetime.now().isoformat(),
            'threshold': self.threshold,
            'metrics': current_metrics
        }
        
        output_file = self.metrics_dir / "performance-baseline.json"
        
        try:
            with open(output_file, 'w') as f:
                json.dump(baseline_data, f, indent=2)
            
            print(f"{Colors.GREEN}✅ Baseline saved: {output_file}{Colors.END}\n")
        except Exception as e:
            print(f"{Colors.RED}❌ Failed to save baseline: {e}{Colors.END}\n")
    
    def print_summary(self):
        """Print regression detection summary"""
        print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}")
        print(f"{Colors.BOLD}{Colors.GREEN}📊 Regression Detection Summary{Colors.END}")
        print(f"{Colors.BOLD}{Colors.GREEN}{'='*70}{Colors.END}\n")
        
        if not self.regressions_found:
            print(f"{Colors.GREEN}{Colors.BOLD}🎉 NO REGRESSIONS DETECTED!{Colors.END}")
            print(f"{Colors.GREEN}All metrics are within acceptable thresholds.{Colors.END}\n")
        else:
            print(f"{Colors.RED}{Colors.BOLD}🚨 {len(self.regressions_found)} REGRESSION(S) DETECTED!{Colors.END}\n")
            
            print(f"{Colors.BOLD}Regressions Found:{Colors.END}")
            for reg in self.regressions_found:
                print(f"  • {reg['metric']} {reg['percentile'].upper()}: "
                      f"{reg['baseline']:.2f}ms → {reg['current']:.2f}ms "
                      f"({reg['regression']:+.1f}%)")
            print()
            
            print(f"{Colors.BOLD}Recommended Actions:{Colors.END}")
            print(f"  1. Review recent changes to the cluster")
            print(f"  2. Check for resource contention or node issues")
            print(f"  3. Verify performance profile configuration")
            print(f"  4. Run detailed performance analysis")
            print(f"  5. Consider rolling back recent changes\n")
        
        print(f"{Colors.BOLD}📚 Next Steps:{Colors.END}")
        print(f"  • Monitor trends over time")
        print(f"  • Set up automated regression detection")
        print(f"  • Configure alerting for critical regressions")
        print(f"  • Document performance baselines\n")
    
    def run_detection(self, save_baseline: bool = False):
        """Run regression detection"""
        self.print_header()
        
        # Load current metrics
        current_metrics = self.load_current_metrics()
        
        if not current_metrics:
            print(f"{Colors.RED}❌ No metrics available for analysis{Colors.END}\n")
            return False
        
        # Save baseline if requested
        if save_baseline:
            self.save_baseline(current_metrics)
            return True
        
        # Load baseline
        baseline = self.load_baseline()
        
        if not baseline:
            print(f"{Colors.YELLOW}⚠️  Cannot detect regressions without baseline{Colors.END}")
            print(f"{Colors.CYAN}💡 Run with --save-baseline to create one{Colors.END}\n")
            return False
        
        # Compare metrics
        self.compare_metrics(baseline, current_metrics)
        
        # Print summary
        self.print_summary()
        
        return len(self.regressions_found) == 0


def main():
    parser = argparse.ArgumentParser(
        description="Module 6: Performance Regression Detector",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This script detects performance regressions:

  ✓ Compare current vs historical performance
  ✓ Alert on regressions exceeding threshold
  ✓ Analyze P50, P95, P99 percentiles
  ✓ Save baselines for future comparison

Examples:
  # Save current metrics as baseline
  python3 module06-performance-regression-detector.py --save-baseline
  
  # Detect regressions against baseline
  python3 module06-performance-regression-detector.py
  
  # Use custom threshold (default: 10%)
  python3 module06-performance-regression-detector.py --threshold 15
  
  # Specify custom baseline file
  python3 module06-performance-regression-detector.py --baseline /path/to/baseline.json

Educational Focus:
  This script helps maintain performance over time by detecting
  regressions early before they impact production.
        """
    )
    
    parser.add_argument(
        "--metrics-dir",
        default="~/kube-burner-configs",
        help="Directory containing performance metrics"
    )
    
    parser.add_argument(
        "--baseline",
        help="Baseline file to compare against (default: metrics-dir/performance-baseline.json)"
    )
    
    parser.add_argument(
        "--threshold",
        type=float,
        default=10.0,
        help="Regression threshold percentage (default: 10%%)"
    )
    
    parser.add_argument(
        "--save-baseline",
        action="store_true",
        help="Save current metrics as baseline"
    )
    
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable colored output"
    )
    
    args = parser.parse_args()
    
    # Disable colors if requested or not in a TTY
    if args.no_color or not sys.stdout.isatty():
        Colors.disable()
    
    # Determine baseline file
    baseline_file = args.baseline
    if not baseline_file:
        baseline_file = str(Path(args.metrics_dir).expanduser() / "performance-baseline.json")
    
    # Create detector and run
    detector = RegressionDetector(
        metrics_dir=args.metrics_dir,
        baseline_file=baseline_file,
        threshold=args.threshold
    )
    
    success = detector.run_detection(save_baseline=args.save_baseline)
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

