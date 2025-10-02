#!/usr/bin/env python3
"""
Module-Specific Performance Analysis Script
Provides focused analysis for each workshop module without data contamination
"""

import sys
import os
import subprocess
from pathlib import Path

def run_module_analysis(module_num, base_dir="~/kube-burner-configs"):
    """Run module-specific analysis without data contamination"""
    base_path = Path(base_dir).expanduser()
    
    print(f"🎓 Module {module_num} Specific Performance Analysis")
    print("=" * 60)
    
    if module_num == 4:
        # Module 4: Focus on baseline vs tuned containers only
        print("🎯 Module 4 Focus: Container Performance Optimization")
        print("📊 Analyzing: Baseline vs Tuned container performance")
        print("🚫 Excluding: VMI data (analyzed in Module 5)")
        print()
        
        baseline_dir = base_path / "collected-metrics"
        tuned_dir = base_path / "collected-metrics-tuned"
        
        if not baseline_dir.exists():
            print("❌ Baseline metrics not found. Please complete Module 3 first.")
            return False
            
        if not tuned_dir.exists():
            print("❌ Tuned metrics not found. Please complete Module 4 performance tests first.")
            return False
        
        # Temporarily rename VMI directory to hide it from analysis
        vmi_dir = base_path / "collected-metrics-vmi"
        vmi_hidden = base_path / ".collected-metrics-vmi-hidden"
        
        vmi_was_hidden = False
        if vmi_dir.exists():
            vmi_dir.rename(vmi_hidden)
            vmi_was_hidden = True
            print("ℹ️  Temporarily hiding VMI data for focused Module 4 analysis")
        
        try:
            # Run analysis with VMI data hidden
            cmd = [
                "python3", 
                str(Path("~/low-latency-performance-workshop/scripts/analyze-performance.py").expanduser()),
                "--baseline", "collected-metrics",
                "--tuned", "collected-metrics-tuned"
            ]
            
            result = subprocess.run(cmd, cwd=base_path, capture_output=False)
            
        finally:
            # Restore VMI directory
            if vmi_was_hidden and vmi_hidden.exists():
                vmi_hidden.rename(vmi_dir)
                print("ℹ️  VMI data restored")
        
        return result.returncode == 0
        
    elif module_num == 5:
        # Module 5: Focus on VMI with container context
        print("🎯 Module 5 Focus: Virtual Machine Performance Analysis")
        print("📊 Analyzing: VMI performance with container context")
        print("🎓 Educational: Understanding virtualization overhead")
        print()
        
        vmi_dir = base_path / "collected-metrics-vmi"
        baseline_dir = base_path / "collected-metrics"
        tuned_dir = base_path / "collected-metrics-tuned"
        
        if not vmi_dir.exists():
            print("❌ VMI metrics not found. Please complete Module 5 VMI tests first.")
            return False
        
        # Determine what container context is available
        if baseline_dir.exists() and tuned_dir.exists():
            print("✅ Full context available: Baseline + Tuned + VMI")
            context = "full"
        elif baseline_dir.exists():
            print("✅ Baseline context available: Baseline + VMI")
            context = "baseline"
        else:
            print("ℹ️  VMI-only analysis (no container baseline)")
            context = "vmi-only"
        
        # Run appropriate analysis
        if context == "full":
            cmd = [
                "python3", 
                str(Path("~/low-latency-performance-workshop/scripts/analyze-performance.py").expanduser()),
                "--baseline", "collected-metrics",
                "--tuned", "collected-metrics-tuned", 
                "--vmi", "collected-metrics-vmi"
            ]
        elif context == "baseline":
            cmd = [
                "python3", 
                str(Path("~/low-latency-performance-workshop/scripts/analyze-performance.py").expanduser()),
                "--baseline", "collected-metrics",
                "--vmi", "collected-metrics-vmi"
            ]
        else:
            cmd = [
                "python3", 
                str(Path("~/low-latency-performance-workshop/scripts/analyze-performance.py").expanduser()),
                "--single", "collected-metrics-vmi"
            ]
        
        result = subprocess.run(cmd, cwd=base_path, capture_output=False)
        return result.returncode == 0
        
    elif module_num == 6:
        # Module 6: Comprehensive analysis of everything
        print("🎯 Module 6 Focus: Comprehensive Performance Validation")
        print("📊 Analyzing: All available performance data")
        print("🎓 Educational: End-to-end performance journey")
        print()
        
        # Run comprehensive analysis
        cmd = [
            "python3", 
            str(Path("~/low-latency-performance-workshop/scripts/analyze-performance.py").expanduser()),
            "--compare"
        ]
        
        result = subprocess.run(cmd, cwd=base_path, capture_output=False)
        return result.returncode == 0
        
    else:
        print(f"❌ Module {module_num} not supported. Supported modules: 4, 5, 6")
        return False

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 module-specific-analysis.py <module_number>")
        print("Example: python3 module-specific-analysis.py 4")
        print("Supported modules: 4, 5, 6")
        sys.exit(1)
    
    try:
        module_num = int(sys.argv[1])
    except ValueError:
        print("❌ Module number must be an integer (4, 5, or 6)")
        sys.exit(1)
    
    success = run_module_analysis(module_num)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
