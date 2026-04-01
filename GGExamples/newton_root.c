/*
 * FPChecker v0.6 - Newton Root-Finding with Error History Tracking
 *
 * This program demonstrates FPChecker's ability to track error evolution
 * over iterations using the FPC_SAVE_LINE_ERRORS environment variable.
 *
 * The function f(x) = x * atan(1/x) - small_offset is designed to be
 * numerically challenging:
 *   - Near x=0, f(x) approaches 0 asymptotically
 *   - f(x) < 0 for small negative x, f(x) > 0 for small positive x
 *   - The derivative becomes ill-conditioned near the root
 *   - All computations use float precision to amplify errors
 *
 * The watch_list.txt file specifies which source lines to track.
 * Each line in watch_list.txt should contain a single line number.
 *
 * Compile with:
 *   ./run_with_plot.sh
 *
 * Or manually:
 *   export FPC_INSTALL=/path/to/FPC/install
 *   export FPC_SAVE_LINE_ERRORS=45,52,59  # Lines to track
 *   clang -O0 -g \
 *     -fpass-plugin=$FPC_INSTALL/lib/libfpchecker_error.so \
 *     -include $FPC_INSTALL/src/Runtime_error.h \
 *     -I$FPC_INSTALL/src \
 *     newton_root.c -o newton_root -lm
 *
 *   ./newton_root
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "FPC_Annotations.h"

/* Small offset to shift the root away from exactly zero */
#define SMALL_OFFSET 1e-8f

/*
 * Asymptotic function: f(x) = x * atan(1/x) - offset
 *
 * Properties:
 *   - As x -> 0+, f(x) -> pi/2 * 0 - offset = -offset (small negative)
 *   - As x -> 0-, f(x) -> -pi/2 * 0 - offset = -offset (small negative)
 *   - For very small positive x: f(x) ≈ x * (pi/2) - offset
 *   - For very small negative x: f(x) ≈ x * (-pi/2) - offset
 *   - The function has a root near x = 2*offset/pi
 *
 * This function is numerically challenging because:
 *   1. atan(1/x) has a discontinuity at x=0
 *   2. The product x * atan(1/x) involves cancellation
 *   3. Near the root, small errors in f(x) lead to large errors in x
 */
FPC_CALCULATE_ERROR
float asymptotic_f(float x) {
    if (fabsf(x) < 1e-30f) {
        return -SMALL_OFFSET;  /* Avoid division by zero */
    }
    float inv_x = 1.0f / x;              /* Line 59: Track error here */
    float atan_val = atanf(inv_x);       /* Line 60: Track error here */
    float product = x * atan_val;        /* Line 61: Track error here */
    float result = product - SMALL_OFFSET;
    return result;
}

/*
 * Derivative: f'(x) = atan(1/x) - 1/(x*(1 + 1/x^2))
 *                   = atan(1/x) - x/(x^2 + 1)
 *
 * This derivative is also numerically challenging near x=0.
 */
FPC_CALCULATE_ERROR
float asymptotic_df(float x) {
    if (fabsf(x) < 1e-30f) {
        return 1e30f;  /* Large derivative at discontinuity */
    }
    float inv_x = 1.0f / x;
    float atan_val = atanf(inv_x);
    float x_sq = x * x;
    float denom = x_sq + 1.0f;
    float term2 = x / denom;             /* Line 79: Track error here */
    float result = atan_val - term2;     /* Line 80: Track error here */
    return result;
}

/*
 * Newton-Raphson iteration: x_{n+1} = x_n - f(x_n) / f'(x_n)
 *
 * This function performs a single Newton step and returns the new x.
 * Error tracking is enabled to monitor how errors propagate through
 * the division operation.
 */
FPC_CALCULATE_ERROR
float newton_step(float x, float fx, float dfx) {
    if (fabsf(dfx) < 1e-30f) {
        printf("  WARNING: Derivative too small, returning same x\n");
        return x;
    }
    float ratio = fx / dfx;              /* Line 95: Division - track error */
    float new_x = x - ratio;             /* Line 96: Subtraction - track error */
    return new_x;
}

/*
 * Main Newton root-finding loop
 */
int main(int argc, char **argv) {
    printf("FPChecker v0.6 - Newton Root-Finding with Error History\n");
    printf("========================================================\n\n");

    /* Starting point in the interval [-1.1, 1.1] */
    float x = 0.5f;  /* Start away from the problematic region */

    /* Allow override from command line */
    if (argc > 1) {
        x = (float)atof(argv[1]);
        if (x < -1.1f || x > 1.1f) {
            printf("Warning: x=%.6f is outside [-1.1, 1.1], clamping\n", x);
            x = fmaxf(-1.1f, fminf(1.1f, x));
        }
    }

    printf("Function: f(x) = x * atan(1/x) - %.2e\n", SMALL_OFFSET);
    printf("Starting point: x = %.10f\n", x);
    printf("Search interval: [-1.1, 1.1]\n");
    printf("Expected root: near x = %.10e (approx 2*offset/pi)\n\n",
           2.0 * SMALL_OFFSET / M_PI);

    int max_iterations = 50;
    float tolerance = 1e-10f;

    printf("%-5s  %-15s  %-15s  %-15s  %-15s\n",
           "Iter", "x", "f(x)", "f'(x)", "|f(x)|");
    printf("----------------------------------------------------------------------\n");

    for (int i = 0; i < max_iterations; i++) {
        float fx = asymptotic_f(x);
        float dfx = asymptotic_df(x);

        printf("%-5d  %+.8e  %+.8e  %+.8e  %.8e\n",
               i, x, fx, dfx, fabsf(fx));

        /* Check convergence */
        if (fabsf(fx) < tolerance) {
            printf("\nConverged after %d iterations!\n", i + 1);
            break;
        }

        /* Check if we're stuck */
        if (fabsf(dfx) < 1e-20f) {
            printf("\nDerivative too small, stopping.\n");
            break;
        }

        /* Perform Newton step */
        float new_x = newton_step(x, fx, dfx);

        /* Clamp to search interval */
        if (new_x < -1.1f || new_x > 1.1f) {
            printf("  (clamped from %.8e to interval)\n", new_x);
            new_x = fmaxf(-1.1f, fminf(1.1f, new_x));
        }

        /* Check for oscillation/stagnation */
        if (fabsf(new_x - x) < 1e-15f) {
            printf("\nStep size too small, stopping.\n");
            break;
        }

        x = new_x;
    }

    printf("\n========================================================\n");
    printf("Final result: x = %.15e\n", x);
    printf("Final f(x)  : %.15e\n", asymptotic_f(x));
    printf("\nCheck .fpc_logs/ for error traces:\n");
    printf("  - rounding_error_*.json: Per-operation absolute/relative errors\n");
    printf("  - errors_per_line_*.json: Error history for watched lines\n");
    printf("\nRun './run_with_plot.sh' to generate error history plots.\n");

    return 0;
}
