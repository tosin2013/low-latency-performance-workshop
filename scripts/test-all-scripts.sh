#!/bin/bash
# Test script to verify all Python analysis scripts are working

echo "🧪 Testing All Workshop Analysis Scripts"
echo "========================================"

SCRIPT_DIR="$HOME/low-latency-performance-workshop/scripts"
FAILED_TESTS=0

# Test 1: Performance Summary
echo ""
echo "🎯 Test 1: Performance Summary Script"
echo "------------------------------------"
if python3 "$SCRIPT_DIR/performance-summary.py" --no-color > /dev/null 2>&1; then
    echo "✅ Performance summary script working"
else
    echo "❌ Performance summary script failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 2: Cluster Health Check
echo ""
echo "🏥 Test 2: Cluster Health Check Script"
echo "-------------------------------------"
if python3 "$SCRIPT_DIR/cluster-health-check.py" > /dev/null 2>&1; then
    echo "✅ Cluster health check script working"
else
    echo "❌ Cluster health check script failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test 3: Performance Analysis (if metrics exist)
echo ""
echo "📊 Test 3: Performance Analysis Script"
echo "-------------------------------------"
cd ~/kube-burner-configs 2>/dev/null || cd ~

if [ -d "collected-metrics-tuned" ]; then
    if python3 "$SCRIPT_DIR/analyze-performance.py" --single collected-metrics-tuned --no-color > /dev/null 2>&1; then
        echo "✅ Performance analysis script working"
    else
        echo "❌ Performance analysis script failed"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo "ℹ️  No test metrics found - skipping performance analysis test"
fi

# Test 4: Performance Comparison (if both metrics exist)
echo ""
echo "🔄 Test 4: Performance Comparison"
echo "--------------------------------"
if [ -d "collected-metrics" ] && [ -d "collected-metrics-tuned" ]; then
    if python3 "$SCRIPT_DIR/analyze-performance.py" --compare --no-color > /dev/null 2>&1; then
        echo "✅ Performance comparison working"
    else
        echo "❌ Performance comparison failed"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo "ℹ️  Missing baseline or tuned metrics - skipping comparison test"
fi

# Summary
echo ""
echo "📋 Test Summary"
echo "==============="
if [ $FAILED_TESTS -eq 0 ]; then
    echo "🎉 All tests passed! Scripts are ready for workshop use."
    exit 0
else
    echo "⚠️  $FAILED_TESTS test(s) failed. Check script dependencies and cluster access."
    exit 1
fi
