/*
 * FPChecker v0.6 - Absolute Error Analysis Example
 *
 * This program demonstrates how to use FPC_CALCULATE_ERROR to track
 * floating-point error propagation and calculate absolute/relative errors.
 *
 * Compile with:
 *   ./run_error_analysis.sh
 *
 * Or manually:
 *   export FPC_INSTALL=/path/to/FPC/install
 *   clang -O0 -g \
 *     -fpass-plugin=$FPC_INSTALL/lib/libfpchecker_error.so \
 *     -include $FPC_INSTALL/src/Runtime_error.h \
 *     -I$FPC_INSTALL/src \
 *     error_analysis_demo.c -o error_analysis_demo -lm
 *
 * Run with:
 *   ./error_analysis_demo
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "FPC_Annotations.h"

/*
 * Example 1: Summation Error Accumulation
 *
 * Adding many small numbers accumulates rounding errors.
 * The FPC_CALCULATE_ERROR annotation enables error tracking for this function.
 */
FPC_CALCULATE_ERROR
float compute_sum(float *arr, int n) {
    float sum = 0.0f;
    for (int i = 0; i < n; i++) {
        sum += arr[i];  /* Each addition may introduce rounding error */
    }
    return sum;
}

/*
 * Example 2: Catastrophic Cancellation
 *
 * Subtracting nearly equal numbers amplifies relative error.
 * This is one of the most common sources of numerical instability.
 */
FPC_CALCULATE_ERROR
float catastrophic_cancellation(float a, float b) {
    return a - b;  /* Small absolute difference, large relative error */
}

/*
 * Example 3: Polynomial Evaluation (Horner's Method)
 *
 * Evaluates p(x) = 1 + x + x^2 + x^3 using Horner's method.
 * Error propagates through chained multiply-add operations.
 */
FPC_CALCULATE_ERROR
float polynomial_eval(float x) {
    float result = 1.0f;
    result = result * x + 1.0f;  /* x + 1 */
    result = result * x + 1.0f;  /* x^2 + x + 1 */
    result = result * x + 1.0f;  /* x^3 + x^2 + x + 1 */
    return result;
}

/*
 * Example 4: Kahan Summation vs Naive Summation
 *
 * Kahan summation uses a compensation variable to reduce error.
 * Compare this with compute_sum() above.
 */
FPC_CALCULATE_ERROR
float kahan_sum(float *arr, int n) {
    float sum = 0.0f;
    float c = 0.0f;  /* Compensation for lost low-order bits */

    for (int i = 0; i < n; i++) {
        float y = arr[i] - c;      /* Compensated value */
        float t = sum + y;         /* Add to running sum */
        c = (t - sum) - y;         /* Recover lost bits */
        sum = t;
    }
    return sum;
}

/*
 * Example 5: Division with Small Denominator
 *
 * Division by small numbers can amplify errors.
 */
FPC_CALCULATE_ERROR
float risky_division(float numerator, float denominator) {
    return numerator / denominator;
}

int main(int argc, char **argv) {
    printf("FPChecker v0.6 - Absolute Error Analysis Demo\n");
    printf("==============================================\n\n");

    /* Test 1: Summation error accumulation */
    printf("Test 1: Summation of 1000 values of 0.1\n");
    printf("  (0.1 is not exactly representable in binary floating-point)\n");

    float arr[1000];
    for (int i = 0; i < 1000; i++) {
        arr[i] = 0.1f;
    }

    float naive_sum = compute_sum(arr, 1000);
    float kahan_result = kahan_sum(arr, 1000);

    printf("  Naive sum:  %.10f (expected 100.0)\n", naive_sum);
    printf("  Kahan sum:  %.10f (expected 100.0)\n", kahan_result);
    printf("  Naive error: %.10e\n", fabsf(naive_sum - 100.0f));
    printf("  Kahan error: %.10e\n\n", fabsf(kahan_result - 100.0f));

    /* Test 2: Catastrophic cancellation */
    printf("Test 2: Catastrophic Cancellation\n");
    printf("  Subtracting nearly equal numbers: 1.0000001 - 1.0000000\n");

    float a = 1.0000001f;
    float b = 1.0000000f;
    float diff = catastrophic_cancellation(a, b);

    printf("  Result: %.15e\n", diff);
    printf("  Expected: 1.0e-7, but result loses significant digits\n\n");

    /* Test 3: Polynomial evaluation */
    printf("Test 3: Polynomial Evaluation at x=0.1\n");
    printf("  p(x) = 1 + x + x^2 + x^3\n");

    float x = 0.1f;
    float poly = polynomial_eval(x);
    double exact = 1.0 + 0.1 + 0.01 + 0.001;  /* Computed in double */

    printf("  Computed (float):  %.10f\n", poly);
    printf("  Exact (double):    %.10f\n", exact);
    printf("  Absolute error:    %.10e\n\n", fabs((double)poly - exact));

    /* Test 4: Division with small denominator */
    printf("Test 4: Division by Small Number\n");

    float num = 1.0f;
    float denom = 1e-7f;
    float div_result = risky_division(num, denom);

    printf("  1.0 / 1e-7 = %.6e\n", div_result);
    printf("  (Small denominator amplifies any error in numerator)\n\n");

    printf("==============================================\n");
    printf("Check .fpc_logs/ directory for detailed error traces.\n");
    printf("Run 'cat .fpc_logs/rounding_error_*.json | python3 -m json.tool'\n");

    return 0;
}
