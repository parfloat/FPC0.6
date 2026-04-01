# FPChecker v0.6 - Absolute Error Analysis Instructions

This guide explains how to use FPChecker v0.6 to calculate the **absolute error** of floating-point variables that you select in your program.

## Overview

FPChecker v0.6 provides two instrumentation modes:
1. **Exception Detection** (`FPC_INSTRUMENT`) - Detects NaN, Inf, underflow, cancellation, etc.
2. **Error Tracking** (`FPC_INSTRUMENT_ERR_TRACKING`) - Calculates and tracks absolute/relative error propagation

For calculating absolute error of selected variables, we use the **Error Tracking** mode with the `FPC_CALCULATE_ERROR` annotation.

---

## Step 1: Install FPChecker v0.6

### Prerequisites
- LLVM/Clang 14+ (with plugin support)
- CMake 3.15+
- Python 3 with matplotlib

### Build and Install

```bash
cd /home/ganesh/repos/parfloat-class/FPC0.6

# Create build directory
mkdir -p build && cd build

# Configure with desired install prefix
cmake .. -DCMAKE_INSTALL_PREFIX=/home/ganesh/FPC/install

# Build
make -j$(nproc)

# Install
make install
```

After installation, you'll have:
- `clang-fpchecker` and `clang++-fpchecker` compiler wrappers
- `libfpchecker_error.so` LLVM pass for error tracking
- Runtime headers for instrumentation

---

## Step 2: Write Your Test Program with Annotations

Create `/home/ganesh/FPC/test1.c` with the `FPC_CALCULATE_ERROR` annotation on functions you want to track:

```c
#include <stdio.h>
#include <stdlib.h>

/* Include FPChecker annotations */
#include "FPC_Annotations.h"

/*
 * The FPC_CALCULATE_ERROR annotation tells FPChecker to:
 * 1. Track error propagation through all FP operations in this function
 * 2. Calculate absolute error = (computed_double - computed_float)
 * 3. Calculate relative error = |absolute_error| / |computed_double|
 */

FPC_CALCULATE_ERROR
float compute_sum(float *arr, int n) {
    float sum = 0.0f;
    for (int i = 0; i < n; i++) {
        sum += arr[i];  /* Error accumulates with each addition */
    }
    return sum;
}

FPC_CALCULATE_ERROR
float catastrophic_cancellation(float a, float b) {
    /* Subtracting nearly equal numbers causes large relative error */
    return a - b;
}

FPC_CALCULATE_ERROR
float polynomial_eval(float x) {
    /* Horner's method: p(x) = 1 + x + x^2 + x^3 */
    float result = 1.0f;
    result = result * x + 1.0f;
    result = result * x + 1.0f;
    result = result * x + 1.0f;
    return result;
}

int main(int argc, char **argv) {
    /* Test 1: Summation error accumulation */
    float arr[1000];
    for (int i = 0; i < 1000; i++) {
        arr[i] = 0.1f;  /* 0.1 is not exactly representable in float */
    }
    float sum = compute_sum(arr, 1000);
    printf("Sum of 1000 x 0.1 = %.10f (expected 100.0)\n", sum);

    /* Test 2: Catastrophic cancellation */
    float a = 1.0000001f;
    float b = 1.0000000f;
    float diff = catastrophic_cancellation(a, b);
    printf("Difference: %.15e\n", diff);

    /* Test 3: Polynomial evaluation */
    float x = 0.1f;
    float poly = polynomial_eval(x);
    printf("Polynomial at x=0.1: %.10f\n", poly);

    return 0;
}
```

### Key Annotation: `FPC_CALCULATE_ERROR`

Place this annotation **before any function** where you want FPChecker to:
- Track error through all floating-point operations
- Calculate absolute error for each operation
- Propagate errors through function calls and memory operations

---

## Step 3: Compile with FPChecker Error Tracking

### Option A: Using Compiler Wrappers (Recommended)

```bash
cd /home/ganesh/FPC

# Set environment variables
export PATH=/home/ganesh/FPC/install/bin:$PATH
export FPC_INSTRUMENT_ERR_TRACKING=1

# Compile with error tracking instrumentation
clang-fpchecker -O0 -g test1.c -o test1_instrumented -lm

# Or for C++:
# clang++-fpchecker -O0 -g test1.cpp -o test1_instrumented -lm
```

### Option B: Manual Compilation

```bash
cd /home/ganesh/FPC

# Set paths
FPC_INSTALL=/home/ganesh/FPC/install
FPC_LIB=$FPC_INSTALL/lib/libfpchecker_error.so
FPC_RUNTIME=$FPC_INSTALL/src/Runtime_error.h

# Compile with LLVM pass plugin
clang -O0 -g \
    -fpass-plugin=$FPC_LIB \
    -include $FPC_RUNTIME \
    test1.c -o test1_instrumented -lm
```

**Important Notes:**
- Use `-O0` to prevent optimizations from removing instrumentation
- Use `-g` to get file/line information in reports
- Link with `-lm` for math functions used by error calculations

---

## Step 4: Run the Instrumented Program

```bash
cd /home/ganesh/FPC

# Run with default settings
./test1_instrumented

# Or run with environment variables for additional output:

# Save error values at specific lines (comma-separated line numbers)
FPC_SAVE_LINE_ERRORS=15,22,30 ./test1_instrumented

# Enable debug output to see error calculations
FPC_DEBUG_ERROR_ANALYSIS=1 ./test1_instrumented
```

### Output Files

After execution, FPChecker creates a `.fpc_logs/` directory containing:

```
.fpc_logs/
├── fpc_<hostname>_<pid>.json         # Error tracking results
└── error_series_<hostname>_<pid>.json # Time-series error data (if FPC_SAVE_LINE_ERRORS is set)
```

---

## Step 5: Analyze the Results

### View Raw JSON Output

```bash
cat .fpc_logs/fpc_*.json | python3 -m json.tool
```

### Example Output Format

```json
[
  {
    "file": "/home/ganesh/FPC/test1.c",
    "line": 15,
    "register": "%sum",
    "absolute_error": 1.4901161e-06,
    "relative_error": 1.4901161e-08
  },
  {
    "file": "/home/ganesh/FPC/test1.c",
    "line": 22,
    "register": "%result",
    "absolute_error": 2.384186e-07,
    "relative_error": 2.384186e-07
  }
]
```

### Generate HTML Report

```bash
# Generate visual report
fpc-create-report .fpc_logs/

# This creates an HTML report in fpc_report/
```

---

## Step 6: Understanding the Error Calculations

### How FPChecker Calculates Absolute Error

For each floating-point operation in annotated functions:

1. **Compute in float precision:** `result_float = op(a_float, b_float)`
2. **Compute in double precision:** `result_double = op(a_double + err_a, b_double + err_b)`
3. **Absolute error:** `error = result_double - result_float`
4. **Relative error:** `relative_error = |error| / |result_double|`

### Error Propagation

FPChecker tracks error propagation through:
- **Arithmetic operations:** ADD, SUB, MUL, DIV, FMA
- **Memory operations:** LOAD, STORE (error follows data)
- **Function calls:** Error passes through arguments and return values
- **PHI nodes:** Error merges at control flow joins

---

## Advanced Usage

### Track Specific Lines Only

To reduce overhead, track error only at specific source lines:

```bash
# Track errors at lines 15, 22, and 30
FPC_SAVE_LINE_ERRORS=15,22,30 ./test1_instrumented
```

This generates `error_series_*.json` with time-series data for each tracked line.

### Quiet Mode

Suppress FPChecker startup messages:

```bash
FPC_QUIET=1 ./test1_instrumented
```

### Debug Mode

See detailed error calculations:

```bash
# Recompile with debug flag
cmake .. -DFPC_DEBUG=ON
make && make install

# Or at runtime:
FPC_DEBUG_ERROR_ANALYSIS=1 ./test1_instrumented
```

---

## Example: Complete Workflow

```bash
# 1. Setup
cd /home/ganesh/FPC
export PATH=/home/ganesh/FPC/install/bin:$PATH

# 2. Compile with error tracking
export FPC_INSTRUMENT_ERR_TRACKING=1
clang-fpchecker -O0 -g test1.c -o test1_instrumented -lm

# 3. Run and generate traces
./test1_instrumented

# 4. View results
cat .fpc_logs/fpc_*.json | python3 -m json.tool

# 5. Generate report
fpc-create-report .fpc_logs/
firefox fpc_report/index.html
```

---

## Troubleshooting

### "No instrumentation type specified"
Set `FPC_INSTRUMENT_ERR_TRACKING=1` before compilation.

### "Cannot find FPC_Annotations.h"
Add `-I/home/ganesh/FPC/install/src` to your compile command, or include the header with its full path.

### Large overhead / slow execution
- Use `-O0` but consider `-O1` if overhead is too high
- Use `FPC_SAVE_LINE_ERRORS` to track only specific lines
- Annotate only the functions you need to analyze

### Missing error data
- Ensure the function has the `FPC_CALCULATE_ERROR` annotation
- Check that compilation used `FPC_INSTRUMENT_ERR_TRACKING=1`
- Verify the `.fpc_logs/` directory was created

---

## References

- FPChecker Paper: Laguna, "FPChecker: Detecting Floating-point Exceptions in GPU Applications," ASE 2019
- Official Documentation: https://fpchecker.org/
- Source Repository: https://github.com/LLNL/FPChecker (branch v0.6)
