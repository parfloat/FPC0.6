#!/bin/bash
#
# run_error_analysis.sh - Compile and run FPChecker error analysis demo
#
# Usage: ./run_error_analysis.sh [FPC_INSTALL_PATH]
#
# If FPC_INSTALL_PATH is not provided, defaults to ../install or ~/FPC/install

set -e

# Determine FPChecker installation path
if [ -n "$1" ]; then
    FPC_INSTALL="$1"
elif [ -d "../install" ]; then
    FPC_INSTALL="$(cd .. && pwd)/install"
elif [ -d "$HOME/FPC/install" ]; then
    FPC_INSTALL="$HOME/FPC/install"
else
    echo "ERROR: Cannot find FPChecker installation."
    echo "Usage: $0 [FPC_INSTALL_PATH]"
    echo ""
    echo "Please build and install FPChecker first:"
    echo "  cd /path/to/FPC0.6"
    echo "  mkdir build && cd build"
    echo "  cmake .. -DCMAKE_INSTALL_PREFIX=/path/to/install"
    echo "  make && make install"
    exit 1
fi

echo "=============================================="
echo "FPChecker v0.6 - Error Analysis Demo"
echo "=============================================="
echo ""
echo "FPChecker installation: $FPC_INSTALL"
echo ""

# Verify installation
if [ ! -f "$FPC_INSTALL/lib/libfpchecker_error.so" ]; then
    echo "ERROR: libfpchecker_error.so not found in $FPC_INSTALL/lib/"
    exit 1
fi

# Clean previous logs
rm -rf .fpc_logs
rm -f error_analysis_demo

# Compile with FPChecker instrumentation
echo "Step 1: Compiling with FPChecker error tracking..."
echo ""

clang -O0 -g \
    -fpass-plugin="$FPC_INSTALL/lib/libfpchecker_error.so" \
    -include "$FPC_INSTALL/src/Runtime_error.h" \
    -I"$FPC_INSTALL/src" \
    error_analysis_demo.c -o error_analysis_demo -lm

echo ""
echo "Step 2: Running instrumented program..."
echo ""
echo "----------------------------------------------"

./error_analysis_demo

echo "----------------------------------------------"
echo ""
echo "Step 3: Displaying error analysis results..."
echo ""

if [ -d ".fpc_logs" ]; then
    echo "Error log files in .fpc_logs/:"
    ls -la .fpc_logs/
    echo ""

    # Find the most recent error log
    ERROR_LOG=$(ls -t .fpc_logs/rounding_error_*.json 2>/dev/null | head -1)

    if [ -n "$ERROR_LOG" ]; then
        echo "Contents of $ERROR_LOG:"
        echo ""

        # Pretty print JSON if python3 is available
        if command -v python3 &> /dev/null; then
            # Handle potential JSON parsing issues
            python3 << 'PYEOF'
import json
import sys
import glob
import re

files = sorted(glob.glob('.fpc_logs/rounding_error_*.json'), key=lambda x: -1)
if files:
    try:
        with open(files[0], 'r') as f:
            content = f.read().strip()
            # Fix trailing comma if present
            if content.endswith(',\n]'):
                content = content[:-3] + '\n]'
            # Replace inf with a large number for JSON parsing
            content = re.sub(r':\s*inf\b', ': 1e308', content)
            content = re.sub(r':\s*-inf\b', ': -1e308', content)
            content = re.sub(r':\s*nan\b', ': null', content, flags=re.IGNORECASE)
            data = json.loads(content)

            print("=" * 70)
            print(f"{'File':<40} {'Line':<8} {'Abs Error':<15} {'Rel Error':<15}")
            print("=" * 70)

            for entry in data:
                filename = entry.get('file', 'unknown')
                # Shorten filename
                if '/' in filename:
                    filename = '...' + filename[-35:]
                line = entry.get('line', 0)
                error = entry.get('error', 0)
                rel_error = entry.get('relative_error', 0)

                # Format scientific notation
                if abs(error) < 1e-3 or abs(error) > 1e3:
                    err_str = f"{error:.3e}"
                else:
                    err_str = f"{error:.6f}"

                if rel_error is None or rel_error >= 1e307:
                    rel_str = "inf"
                elif abs(rel_error) < 1e-3 or abs(rel_error) > 1e3:
                    rel_str = f"{rel_error:.3e}"
                else:
                    rel_str = f"{rel_error:.6f}"

                print(f"{filename:<40} {line:<8} {err_str:<15} {rel_str:<15}")

            print("=" * 70)
            print(f"Total entries: {len(data)}")
    except Exception as e:
        print(f"Error parsing JSON: {e}")
        print("Raw content:")
        with open(files[0], 'r') as f:
            print(f.read()[:2000])
PYEOF
        else
            cat "$ERROR_LOG"
        fi
    fi
else
    echo "No .fpc_logs directory found - error tracking may not have been activated."
fi

echo ""
echo "=============================================="
echo "Done!"
echo "=============================================="
