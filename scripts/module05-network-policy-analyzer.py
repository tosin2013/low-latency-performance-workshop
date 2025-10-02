#!/usr/bin/env python3
"""
Network Policy Performance Analyzer for Low-Latency Workshop
Educational tool for analyzing network policy enforcement latency
"""

import json
import sys
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

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
    END = '\033[0m'
    
    @staticmethod
    def disable():
        Colors.RED = Colors.GREEN = Colors.YELLOW = Colors.BLUE = ''
        Colors.MAGENTA = Colors.CYAN = Colors.WHITE = Colors.BOLD = Colors.END = ''

class NetworkPolicyAnalyzer:
    """Educational network policy performance analysis"""
    
    def __init__(self, metrics_dir: str = "~/kube-burner-configs"):
        self.base_dir = Path(metrics_dir).expanduser()
        self.netpol_dir = self.base_dir / "collected-metrics-netpol"
        self.baseline_dir = self.base_dir / "collected-metrics"
        
    def load_network_policy_metrics(self) -> Dict:
        """Load network policy performance metrics"""
        print(f"{Colors.CYAN}🔍 Loading Network Policy Performance Metrics{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 45}{Colors.END}")
        
        if not self.netpol_dir.exists():
            print(f"{Colors.RED}❌ Network policy metrics directory not found: {self.netpol_dir}{Colors.END}")
            print(f"{Colors.YELLOW}💡 Run the network policy latency test first{Colors.END}")
            return {}
        
        netpol_metrics = {}
        
        # Load network policy latency quantiles
        netpol_files = list(self.netpol_dir.glob("*netpolLatencyQuantilesMeasurement*.json"))
        if netpol_files:
            try:
                with open(netpol_files[0]) as f:
                    data = json.load(f)
                
                for item in data:
                    if item.get('quantileName'):
                        netpol_metrics[item['quantileName']] = {
                            'P50': item.get('P50', 0),
                            'P95': item.get('P95', 0),
                            'P99': item.get('P99', 0),
                            'avg': item.get('avg', 0),
                            'max': item.get('max', 0)
                        }
                
                print(f"{Colors.GREEN}✅ Network policy metrics loaded successfully{Colors.END}")
                print(f"   • Found {len(netpol_metrics)} network policy measurement types")
                
            except Exception as e:
                print(f"{Colors.RED}❌ Error loading network policy metrics: {e}{Colors.END}")
                return {}
        else:
            print(f"{Colors.YELLOW}⚠️  No network policy latency measurement files found{Colors.END}")
            return {}
        
        return netpol_metrics
    
    def analyze_network_policy_latency(self, netpol_metrics: Dict, analysis_type: str = "latency") -> None:
        """Educational analysis of network policy enforcement latency"""
        if not netpol_metrics:
            return
        
        print(f"\n{Colors.MAGENTA}🌐 Network Policy Enforcement Analysis{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 40}{Colors.END}")
        
        if analysis_type == "comprehensive":
            print(f"\n{Colors.YELLOW}🎓 Educational Context:{Colors.END}")
            print(f"   Network policies add security but can impact performance:")
            print(f"   • {Colors.BOLD}Policy Evaluation{Colors.END}: Each connection checked against rules")
            print(f"   • {Colors.BOLD}Rule Complexity{Colors.END}: More rules = longer evaluation time")
            print(f"   • {Colors.BOLD}CNI Implementation{Colors.END}: Different CNIs have varying overhead")
            print(f"   • {Colors.BOLD}Connection Caching{Colors.END}: First connection slower, subsequent faster")
            print()
        
        for policy_type, metrics in netpol_metrics.items():
            # Educational assessment of network policy performance
            p99 = metrics['P99']
            avg = metrics['avg']
            
            # Performance thresholds for network policies
            if p99 < 1000:  # < 1 second
                color = Colors.GREEN
                status = "🚀 Excellent"
                explanation = "Very fast policy enforcement - minimal network overhead"
            elif p99 < 5000:  # < 5 seconds
                color = Colors.YELLOW
                status = "✅ Good"
                explanation = "Acceptable policy enforcement latency"
            elif p99 < 10000:  # < 10 seconds
                color = Colors.YELLOW
                status = "⚠️ Moderate"
                explanation = "Noticeable policy enforcement delay - consider optimization"
            else:  # >= 10 seconds
                color = Colors.RED
                status = "❌ Slow"
                explanation = "High policy enforcement latency - needs investigation"
            
            print(f"  {Colors.BOLD}{policy_type}{Colors.END} {color}({status}){Colors.END}:")
            print(f"    {Colors.GREEN}P50: {metrics['P50']:8.1f}ms{Colors.END}")
            print(f"    {Colors.YELLOW}P95: {metrics['P95']:8.1f}ms{Colors.END}")
            print(f"    {Colors.RED}P99: {metrics['P99']:8.1f}ms{Colors.END}")
            print(f"    {Colors.CYAN}Avg: {metrics['avg']:8.1f}ms{Colors.END}")
            print(f"    {Colors.WHITE}💭 {explanation}{Colors.END}")
            print()
    
    def generate_network_policy_insights(self, netpol_metrics: Dict, output_format: str = "terminal") -> None:
        """Generate educational insights about network policy performance"""
        if not netpol_metrics:
            return
        
        print(f"\n{Colors.CYAN}💡 Network Policy Performance Insights{Colors.END}")
        print(f"{Colors.BLUE}{'=' * 40}{Colors.END}")
        
        # Calculate overall performance assessment
        total_avg = 0
        total_p99 = 0
        count = 0
        
        for metrics in netpol_metrics.values():
            total_avg += metrics.get('avg', 0)
            total_p99 += metrics.get('P99', 0)
            count += 1
        
        if count > 0:
            overall_avg = total_avg / count
            overall_p99 = total_p99 / count
            
            print(f"\n{Colors.BOLD}📊 Overall Network Policy Performance:{Colors.END}")
            print(f"   • Average Enforcement Time: {Colors.CYAN}{overall_avg:.1f}ms{Colors.END}")
            print(f"   • P99 Enforcement Time: {Colors.YELLOW}{overall_p99:.1f}ms{Colors.END}")
            
            # Performance assessment
            if overall_p99 < 2000:  # < 2 seconds
                assessment = f"{Colors.GREEN}🚀 Excellent - Low network overhead{Colors.END}"
                recommendations = [
                    "✅ Current network policy configuration is well-optimized",
                    "📊 Monitor for performance regression as policies are added",
                    "🔍 Consider this baseline for future policy additions"
                ]
            elif overall_p99 < 5000:  # < 5 seconds
                assessment = f"{Colors.YELLOW}✅ Good - Acceptable for most workloads{Colors.END}"
                recommendations = [
                    "📈 Performance is acceptable for most applications",
                    "🎯 Consider optimizing critical path network policies",
                    "🔄 Review policy complexity and rule ordering"
                ]
            else:  # >= 5 seconds
                assessment = f"{Colors.RED}⚠️ Needs Attention - High network overhead{Colors.END}"
                recommendations = [
                    "🚨 Network policy enforcement is impacting performance",
                    "🔧 Review and simplify complex network policies",
                    "📋 Consider policy consolidation and rule optimization",
                    "🌐 Evaluate CNI configuration and performance"
                ]
            
            print(f"   • Assessment: {assessment}")
            
            print(f"\n{Colors.CYAN}🎯 Recommendations:{Colors.END}")
            for rec in recommendations:
                print(f"   {rec}")
            
            # Educational best practices
            print(f"\n{Colors.YELLOW}🎓 Network Policy Best Practices for Low-Latency:{Colors.END}")
            print(f"   • {Colors.BOLD}Minimize Rules{Colors.END}: Fewer, broader rules perform better than many specific ones")
            print(f"   • {Colors.BOLD}Rule Ordering{Colors.END}: Place most common matches first in policy rules")
            print(f"   • {Colors.BOLD}Namespace Isolation{Colors.END}: Use namespace-level policies when possible")
            print(f"   • {Colors.BOLD}Label Efficiency{Colors.END}: Use efficient label selectors for faster matching")
            print(f"   • {Colors.BOLD}Connection Reuse{Colors.END}: Design applications to reuse connections when possible")
            
            # Performance vs Security trade-offs
            print(f"\n{Colors.MAGENTA}⚖️ Performance vs Security Trade-offs:{Colors.END}")
            print(f"   • {Colors.BOLD}No Policies{Colors.END}: Fastest network performance, minimal security")
            print(f"   • {Colors.BOLD}Basic Policies{Colors.END}: Good performance, essential security controls")
            print(f"   • {Colors.BOLD}Complex Policies{Colors.END}: Enhanced security, potential performance impact")
            print(f"   • {Colors.BOLD}Micro-segmentation{Colors.END}: Maximum security, highest performance cost")
            
            if output_format == "educational":
                self._generate_educational_report(netpol_metrics, overall_avg, overall_p99)
    
    def _generate_educational_report(self, netpol_metrics: Dict, overall_avg: float, overall_p99: float) -> None:
        """Generate detailed educational report about network policy performance"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M")
        report_file = self.base_dir / f"network_policy_analysis_{timestamp}.md"
        
        with open(report_file, 'w') as f:
            f.write("# Network Policy Performance Analysis Report\n\n")
            f.write(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            f.write("## Executive Summary\n\n")
            f.write(f"- **Average Policy Enforcement:** {overall_avg:.1f}ms\n")
            f.write(f"- **P99 Policy Enforcement:** {overall_p99:.1f}ms\n")
            
            if overall_p99 < 2000:
                f.write("- **Assessment:** Excellent network policy performance\n")
            elif overall_p99 < 5000:
                f.write("- **Assessment:** Good network policy performance\n")
            else:
                f.write("- **Assessment:** Network policy performance needs attention\n")
            
            f.write("\n## Detailed Metrics\n\n")
            f.write("| Policy Type | P50 (ms) | P95 (ms) | P99 (ms) | Avg (ms) | Max (ms) |\n")
            f.write("|-------------|----------|----------|----------|----------|----------|\n")
            
            for policy_type, metrics in netpol_metrics.items():
                f.write(f"| {policy_type} | {metrics['P50']:.1f} | {metrics['P95']:.1f} | "
                       f"{metrics['P99']:.1f} | {metrics['avg']:.1f} | {metrics['max']:.1f} |\n")
            
            f.write("\n## Educational Insights\n\n")
            f.write("### Network Policy Impact on Performance\n\n")
            f.write("Network policies provide essential security controls but introduce performance overhead:\n\n")
            f.write("1. **Policy Evaluation Overhead**: Each network connection must be evaluated against policy rules\n")
            f.write("2. **Rule Complexity Impact**: More complex rules require more processing time\n")
            f.write("3. **First Connection Penalty**: Initial connections are slower due to policy evaluation\n")
            f.write("4. **CNI Implementation Differences**: Different CNI plugins have varying policy enforcement overhead\n\n")
            
            f.write("### Optimization Strategies\n\n")
            f.write("- **Simplify Rules**: Use broader, simpler rules when security requirements allow\n")
            f.write("- **Optimize Selectors**: Use efficient label selectors for faster rule matching\n")
            f.write("- **Namespace Isolation**: Prefer namespace-level policies over pod-level when possible\n")
            f.write("- **Connection Reuse**: Design applications to reuse network connections\n")
            f.write("- **Policy Consolidation**: Combine related rules into single policies where appropriate\n\n")
        
        print(f"\n{Colors.GREEN}📄 Educational report saved: {report_file}{Colors.END}")

def main():
    parser = argparse.ArgumentParser(description="Analyze network policy performance with educational insights")
    parser.add_argument("--metrics-dir", default="~/kube-burner-configs", 
                       help="Directory containing kube-burner metrics")
    parser.add_argument("--analysis-type", choices=["latency", "comprehensive"], default="latency",
                       help="Type of analysis to perform")
    parser.add_argument("--output-format", choices=["terminal", "educational"], default="terminal",
                       help="Output format for results")
    parser.add_argument("--no-color", action="store_true", help="Disable colored output")
    
    args = parser.parse_args()
    
    if args.no_color or not sys.stdout.isatty():
        Colors.disable()
    
    analyzer = NetworkPolicyAnalyzer(args.metrics_dir)
    
    # Load and analyze network policy metrics
    netpol_metrics = analyzer.load_network_policy_metrics()
    
    if netpol_metrics:
        analyzer.analyze_network_policy_latency(netpol_metrics, args.analysis_type)
        analyzer.generate_network_policy_insights(netpol_metrics, args.output_format)
    else:
        print(f"\n{Colors.YELLOW}💡 To use this analyzer:{Colors.END}")
        print(f"   1. Run the network policy latency test in Module 5")
        print(f"   2. Ensure metrics are collected in collected-metrics-netpol/")
        print(f"   3. Re-run this analyzer for educational insights")
        print(f"\n{Colors.CYAN}🌐 Network Policy Testing Benefits:{Colors.END}")
        print(f"   • Understand security vs performance trade-offs")
        print(f"   • Optimize policy rules for better performance")
        print(f"   • Validate network security controls")
        print(f"   • Measure impact on application response times")

if __name__ == "__main__":
    main()
