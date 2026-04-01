# How to Generate Error History Plots for Your Program

This guide explains how to use FPChecker's error tracking with the `watch_list.txt` mechanism to visualize floating-point error evolution in your own programs.

## Prerequisites

1. FPChecker v0.6 installed (see main README)
2. Python3 with matplotlib (`pip3 install matplotlib`)
3. Your C program with floating-point computations

## Step-by-Step Instructions

### Step 1: Annotate Your Functions

Add the `FPC_CALCULATE_ERROR` annotation to functions you want to track:

```c
#include "FPC_Annotations.h"

FPC_CALCULATE_ERROR
float my_computation(float x) {
    float y = x * x;        // Line 6: multiplication
    float z = y + 1.0f;     // Line 7: addition
    return z / x;           // Line 8: division
}
```

### Step 2: Identify Line Numbers to Watch

Compile your program once to get the final line numbers:

```bash
clang -E my_program.c | grep -n "interesting_operation"
```

Or simply look at your source file and note the line numbers of floating-point operations you want to track (e.g., lines 6, 7, 8 from the example above).

### Step 3: Create/Edit watch_list.txt

Edit `watch_list.txt` in the GGExamples directory. Put one line number per line:

```
# Lines to track in my_program.c
6     # multiplication: y = x * x
7     # addition: z = y + 1.0f
8     # division: return z / x
```

**Rules:**
- One line number per line
- Comments start with `#`
- Empty lines are ignored
- Line numbers must correspond to actual FP operations inside `FPC_CALCULATE_ERROR` functions

### Step 4: Copy Your Program to GGExamples

```bash
cp /path/to/my_program.c /path/to/FPC0.6/GGExamples/
```

### Step 5: Modify run_with_plot.sh (if needed)

If your program has a different name than `newton_root.c`, edit `run_with_plot.sh`:

```bash
# Change this line:
newton_root.c -o newton_root -lm

# To:
my_program.c -o my_program -lm
```

And update the execution line:
```bash
# Change:
./newton_root "$STARTING_X"

# To:
./my_program [your arguments]
```

**Or** create a copy of the script for your program:
```bash
cp run_with_plot.sh run_my_program.sh
# Edit run_my_program.sh with your program name
```

### Step 6: Run and Generate Plots

```bash
cd /path/to/FPC0.6/GGExamples
./run_with_plot.sh [FPC_INSTALL_PATH]
```

### Step 7: View Results

After running, you'll find:

| File | Description |
|------|-------------|
| `.fpc_logs/rounding_error_*.json` | Per-operation absolute/relative errors |
| `.fpc_logs/errors_per_line_*.json` | Error history time series |
| `error_history_plot.png` | Combined plot of all watched lines |
| `error_history_line_N.png` | Individual plot for line N |

## Example: Tracking a Simple Loop

```c
#include <stdio.h>
#include "FPC_Annotations.h"

FPC_CALCULATE_ERROR
float accumulate(int n) {
    float sum = 0.0f;
    for (int i = 0; i < n; i++) {
        sum += 0.1f;    // Line 8: track this addition
    }
    return sum;
}

int main() {
    float result = accumulate(1000);
    printf("Result: %f\n", result);
    return 0;
}
```

**watch_list.txt:**
```
8    # sum += 0.1f - accumulating error
```

**Expected output:** A plot showing error growing over 1000 iterations as rounding errors accumulate.

## Troubleshooting

### No errors_per_line_*.json file created

- Verify `FPC_SAVE_LINE_ERRORS` environment variable is set
- Check line numbers in `watch_list.txt` match actual FP operations
- Ensure the lines are inside `FPC_CALCULATE_ERROR` annotated functions

### Plot shows flat line at zero

- The operations at those lines may have zero error
- Try watching different lines with more complex operations
- Division and subtraction typically show more error

### "Line X not found" in plot

- Line numbers may have shifted after preprocessing
- Recount line numbers in your actual source file
- Lines with function calls may not be instrumented

## Quick Reference

```bash
# 1. Edit watch_list.txt with your line numbers
vim watch_list.txt

# 2. Run with plotting
./run_with_plot.sh ~/FPC/install

# 3. View results
ls -la .fpc_logs/
eog error_history_plot.png   # or your image viewer
```

## See Also

- `error_history_plot.svg` - Example output from Newton root-finding
- `newton_root.c` - Reference implementation with annotations
- `README.md` - Full FPChecker documentation
