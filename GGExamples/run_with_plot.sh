#!/bin/bash
#
# run_with_plot.sh - Compile and run Newton root-finding with error history plots
#
# This script:
#   1. Reads watch_list.txt to determine which lines to track
#   2. Compiles newton_root.c with FPChecker error instrumentation
#   3. Runs the program with FPC_SAVE_LINE_ERRORS set
#   4. Generates plots of error history for each watched line
#
# Usage: ./run_with_plot.sh [FPC_INSTALL_PATH] [STARTING_X]
#
# If FPC_INSTALL_PATH is not provided, defaults to ../install or ~/FPC/install
# STARTING_X is the initial guess for Newton's method (default: 0.5)

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
    echo "Usage: $0 [FPC_INSTALL_PATH] [STARTING_X]"
    echo ""
    echo "Please build and install FPChecker first:"
    echo "  cd /path/to/FPC0.6"
    echo "  mkdir build && cd build"
    echo "  cmake .. -DCMAKE_INSTALL_PREFIX=/path/to/install"
    echo "  make && make install"
    exit 1
fi

STARTING_X="${2:-0.5}"

echo "=============================================================="
echo "FPChecker v0.6 - Newton Root-Finding with Error History Plots"
echo "=============================================================="
echo ""
echo "FPChecker installation: $FPC_INSTALL"
echo "Starting point: x = $STARTING_X"
echo ""

# Verify installation
if [ ! -f "$FPC_INSTALL/lib/libfpchecker_error.so" ]; then
    echo "ERROR: libfpchecker_error.so not found in $FPC_INSTALL/lib/"
    exit 1
fi

# Check for watch_list.txt
if [ ! -f "watch_list.txt" ]; then
    echo "ERROR: watch_list.txt not found in current directory."
    echo "Create a file with line numbers to track, one per line."
    exit 1
fi

# Parse watch_list.txt to extract line numbers
echo "Step 1: Reading watch_list.txt..."
WATCH_LINES=""
while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    line=$(echo "$line" | sed 's/#.*//' | tr -d '[:space:]')
    if [ -n "$line" ]; then
        if [ -n "$WATCH_LINES" ]; then
            WATCH_LINES="$WATCH_LINES,$line"
        else
            WATCH_LINES="$line"
        fi
    fi
done < watch_list.txt

if [ -z "$WATCH_LINES" ]; then
    echo "ERROR: No valid line numbers found in watch_list.txt"
    exit 1
fi

echo "  Watching lines: $WATCH_LINES"
echo ""

# Clean previous logs
rm -rf .fpc_logs
rm -f newton_root

# Compile with FPChecker instrumentation
echo "Step 2: Compiling with FPChecker error tracking..."
echo ""

clang -O0 -g \
    -fpass-plugin="$FPC_INSTALL/lib/libfpchecker_error.so" \
    -include "$FPC_INSTALL/src/Runtime_error.h" \
    -I"$FPC_INSTALL/src" \
    newton_root.c -o newton_root -lm

echo ""
echo "Step 3: Running Newton root-finding with error tracking..."
echo ""
echo "--------------------------------------------------------------"

# Set environment variable for line tracking
export FPC_SAVE_LINE_ERRORS="$WATCH_LINES"

./newton_root "$STARTING_X"

echo "--------------------------------------------------------------"
echo ""
echo "Step 4: Generating error history plots..."
echo ""

# Check for error history file
ERROR_HISTORY=$(ls -t .fpc_logs/errors_per_line_*.json 2>/dev/null | head -1)

if [ -z "$ERROR_HISTORY" ]; then
    echo "WARNING: No errors_per_line_*.json found."
    echo "Line tracking may not have been activated."
    echo ""
    echo "Make sure FPC_SAVE_LINE_ERRORS is set and the line numbers"
    echo "in watch_list.txt correspond to actual FP operations."
else
    echo "Found error history: $ERROR_HISTORY"
    echo ""

    # Generate plots using Python
    if command -v python3 &> /dev/null; then
        python3 << 'PYEOF'
import json
import sys
import os

# Try to import matplotlib
try:
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend
    import matplotlib.pyplot as plt
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False
    print("WARNING: matplotlib not installed. Skipping plot generation.")
    print("Install with: pip3 install matplotlib")

# Find the error history file
import glob
files = sorted(glob.glob('.fpc_logs/errors_per_line_*.json'))
if not files:
    print("No error history files found.")
    sys.exit(0)

error_file = files[-1]  # Most recent
print(f"Processing: {error_file}")

try:
    with open(error_file, 'r') as f:
        data = json.load(f)
except Exception as e:
    print(f"Error reading JSON: {e}")
    sys.exit(1)

if not data:
    print("No error data found in file.")
    sys.exit(0)

# Print summary
print("\n" + "=" * 60)
print("Error History Summary")
print("=" * 60)
print(f"{'Line':<10} {'Samples':<10} {'Min Error':<15} {'Max Error':<15}")
print("-" * 60)

for series in data:
    line = series.get('line', 'unknown')
    values = series.get('values', [])
    if values:
        min_val = min(abs(v) for v in values)
        max_val = max(abs(v) for v in values)
        print(f"{line:<10} {len(values):<10} {min_val:<15.6e} {max_val:<15.6e}")

print("=" * 60)
print()

# Generate plots if matplotlib is available
if HAS_MATPLOTLIB and data:
    n_plots = len(data)

    if n_plots == 1:
        fig, axes = plt.subplots(1, 1, figsize=(10, 6))
        axes = [axes]
    else:
        rows = (n_plots + 1) // 2
        fig, axes = plt.subplots(rows, 2, figsize=(14, 4 * rows))
        axes = axes.flatten() if hasattr(axes, 'flatten') else [axes]

    for i, series in enumerate(data):
        if i >= len(axes):
            break

        line = series.get('line', 'unknown')
        values = series.get('values', [])

        if not values:
            continue

        ax = axes[i]
        iterations = range(len(values))

        # Plot absolute error values
        abs_values = [abs(v) for v in values]
        ax.semilogy(iterations, abs_values, 'b-', linewidth=1.5, marker='o', markersize=3)

        ax.set_xlabel('Iteration')
        ax.set_ylabel('Absolute Error')
        ax.set_title(f'Line {line}: Error History')
        ax.grid(True, alpha=0.3)

        # Add statistics annotation
        if abs_values:
            stats_text = f"Samples: {len(values)}\nMin: {min(abs_values):.2e}\nMax: {max(abs_values):.2e}"
            ax.text(0.98, 0.98, stats_text, transform=ax.transAxes,
                   fontsize=8, verticalalignment='top', horizontalalignment='right',
                   bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

    # Hide unused subplots
    for j in range(len(data), len(axes)):
        axes[j].set_visible(False)

    plt.suptitle('FPChecker Error History - Newton Root-Finding', fontsize=14)
    plt.tight_layout()

    output_file = 'error_history_plot.png'
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    print(f"Plot saved to: {output_file}")

    # Also save individual plots
    for series in data:
        line = series.get('line', 'unknown')
        values = series.get('values', [])

        if not values:
            continue

        fig2, ax2 = plt.subplots(figsize=(10, 6))
        iterations = range(len(values))
        abs_values = [abs(v) for v in values]

        ax2.semilogy(iterations, abs_values, 'b-', linewidth=1.5, marker='o', markersize=4)
        ax2.set_xlabel('Iteration', fontsize=12)
        ax2.set_ylabel('Absolute Error', fontsize=12)
        ax2.set_title(f'Error History for Line {line}', fontsize=14)
        ax2.grid(True, alpha=0.3)

        individual_file = f'error_history_line_{line}.png'
        plt.savefig(individual_file, dpi=150, bbox_inches='tight')
        plt.close(fig2)
        print(f"Individual plot saved: {individual_file}")

print()
PYEOF
    else
        echo "Python3 not found. Cannot generate plots."
        echo "Install Python3 to enable plot generation."
    fi
fi

echo ""
echo "=============================================================="
echo "Done!"
echo ""
echo "Output files:"
echo "  - newton_root: Compiled executable"
if [ -d ".fpc_logs" ]; then
    echo "  - .fpc_logs/: Error log directory"
    ls -la .fpc_logs/ 2>/dev/null | grep -v "^total" | head -5
fi
if [ -f "error_history_plot.png" ]; then
    echo "  - error_history_plot.png: Combined error history plot"
fi
if ls error_history_line_*.png 1>/dev/null 2>&1; then
    echo "  - error_history_line_*.png: Individual line plots"
fi
echo "=============================================================="
