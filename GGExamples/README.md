# FPChecker v0.6 - Error Analysis Examples

This directory contains examples demonstrating FPChecker's floating-point error analysis capabilities, including absolute error tracking, relative error calculation, and error history plotting.

## Prerequisites

1. **FPChecker v0.6 Installation**: Build and install FPChecker first:
   ```bash
   cd /path/to/FPC0.6
   mkdir build && cd build
   cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/FPC/install
   make && make install
   ```

2. **Clang/LLVM**: FPChecker requires clang (tested with clang-14)

3. **Python3 with matplotlib** (optional, for plots):
   ```bash
   pip3 install matplotlib
   ```

## Examples

### 1. Basic Error Analysis (`error_analysis_demo.c`)

Demonstrates common sources of floating-point error:

- **Summation Error Accumulation**: Adding many small numbers (0.1 * 1000)
- **Catastrophic Cancellation**: Subtracting nearly equal numbers
- **Polynomial Evaluation**: Error propagation through Horner's method
- **Kahan Summation**: Compensated summation vs naive summation
- **Division by Small Numbers**: Error amplification

**Run:**
```bash
./run_error_analysis.sh [FPC_INSTALL_PATH]
```

**Output:**
- Console output showing computed vs expected values
- `.fpc_logs/rounding_error_*.json`: Per-operation error data

### 2. Newton Root-Finding with Error History (`newton_root.c`)

A numerically challenging root-finding problem that demonstrates:

- Error evolution over iterations
- Variable watching via `watch_list.txt`
- Error history plotting

**The Function:**
```
f(x) = x * atan(1/x) - 1e-8
```

This function is designed to be challenging:
- Asymptotic behavior near x=0
- Ill-conditioned derivative near the root
- All float precision to amplify errors

**Run:**
```bash
./run_with_plot.sh [FPC_INSTALL_PATH] [STARTING_X]
```

**Output:**
- Iteration-by-iteration convergence data
- `.fpc_logs/errors_per_line_*.json`: Error history per watched line
- `error_history_plot.png`: Combined plot of all watched variables
- `error_history_line_N.png`: Individual plots per line

## How FPChecker Error Tracking Works

### The `FPC_CALCULATE_ERROR` Annotation

Mark functions for error tracking:
```c
#include "FPC_Annotations.h"

FPC_CALCULATE_ERROR
float my_function(float x) {
    // All FP operations here will be tracked
    return x * x + 1.0f;
}
```

### Compilation

```bash
export FPC_INSTALL=/path/to/FPC/install
clang -O0 -g \
    -fpass-plugin=$FPC_INSTALL/lib/libfpchecker_error.so \
    -include $FPC_INSTALL/src/Runtime_error.h \
    -I$FPC_INSTALL/src \
    your_program.c -o your_program -lm
```

### Error Tracking Output

#### Per-Operation Errors (`.fpc_logs/rounding_error_*.json`)

Each floating-point operation logs:
```json
{
    "file": "your_program.c",
    "line": 42,
    "error": 1.234e-7,
    "relative_error": 1.5e-6
}
```

#### Error History Per Line (`.fpc_logs/errors_per_line_*.json`)

When `FPC_SAVE_LINE_ERRORS` is set, tracks error evolution:
```json
[
    {
        "line": 42,
        "values": [1.0e-7, 1.2e-7, 1.5e-7, ...]
    }
]
```

## Using `watch_list.txt`

The `watch_list.txt` file specifies which source lines to track for error history:

```
# Lines to track (comments start with #)
42    # division in main loop
45    # subtraction operation
58    # multiplication
```

The script extracts these line numbers and sets `FPC_SAVE_LINE_ERRORS=42,45,58`.

**Tips:**
- Use line numbers corresponding to actual FP operations
- The line must be in a function marked with `FPC_CALCULATE_ERROR`
- Check your source file line numbers after any edits

## Environment Variables

| Variable | Description |
|----------|-------------|
| `FPC_SAVE_LINE_ERRORS` | Comma-separated list of line numbers to track |
| `FPC_DEBUG` | Enable verbose debug output |

## Understanding the Error Metrics

### Absolute Error
```
absolute_error = |computed_value - exact_value|
```

FPChecker computes "exact" values using extended precision arithmetic internally.

### Relative Error
```
relative_error = absolute_error / |exact_value|
```

Note: Relative error is `inf` when the exact value is zero.

## Common Floating-Point Error Sources

1. **Representation Error**: 0.1 cannot be exactly represented in binary
2. **Catastrophic Cancellation**: Subtracting nearly equal numbers
3. **Error Accumulation**: Many operations compound small errors
4. **Ill-Conditioned Operations**: Division by small numbers, large powers

## File Structure

```
GGExamples/
├── README.md                    # This file
├── error_analysis_demo.c        # Basic error analysis example
├── run_error_analysis.sh        # Script to run basic example
├── newton_root.c                # Newton root-finding with error history
├── run_with_plot.sh             # Script with plot generation
├── watch_list.txt               # Lines to track for error history
└── .fpc_logs/                   # Generated error logs (after running)
    ├── rounding_error_*.json    # Per-operation errors
    └── errors_per_line_*.json   # Error history per line
```

## Troubleshooting

### "libfpchecker_error.so not found"
- Verify FPChecker installation path
- Check that `make install` completed successfully

### No error logs generated
- Ensure functions have `FPC_CALCULATE_ERROR` annotation
- Compile with `-O0` (optimization can eliminate operations)
- Include `Runtime_error.h` with `-include` flag

### Empty errors_per_line.json
- Verify line numbers in `watch_list.txt` match actual FP operations
- Lines must be inside `FPC_CALCULATE_ERROR` annotated functions
- Check `FPC_SAVE_LINE_ERRORS` environment variable is set

### Plots not generated
- Install matplotlib: `pip3 install matplotlib`
- Check Python3 is available

## References

- FPChecker: https://github.com/LLNL/FPChecker
- IEEE 754 Floating-Point Standard
- "What Every Computer Scientist Should Know About Floating-Point Arithmetic" by David Goldberg
