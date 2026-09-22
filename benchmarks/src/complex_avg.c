#include <stdio.h>

void *memcpy(void *dest, const void *src, unsigned long n) {
    char *d = (char *)dest;
    const char *s = (const char *)src;
    while (n--) {
        *d++ = *s++;
    }
    return dest;
}

void *memset(void *s, int c, unsigned long n) {
    unsigned char *p = (unsigned char *)s;
    while (n--) {
        *p++ = (unsigned char)c;
    }
    return s;
}

// HTIF (Host-Target Interface) variables for Spike/RISC-V simulator
volatile unsigned long tohost = 0;
volatile unsigned long fromhost = 0;

// Constants for the workload
#define DATA_LENGTH 200      // Increased outer loop iterations
#define BUFFER_SIZE 7        // Using a prime number makes division less optimizable
#define HEAVY_DIV_ITERATIONS 1000 // Controls the number of heavy divisions per data point

int main() {
    // ==========================================
    // Data Initialization
    // ==========================================
    int signal[DATA_LENGTH];
    for(int i = 0; i < DATA_LENGTH; ++i) {
        // Initialize with some non-trivial values
        signal[i] = 100 + (i * 7) % 50;
    }

    int buffer[BUFFER_SIZE] = {0};
    int sum = 0;
    int moving_average[DATA_LENGTH];

    // Main loop: Processes each data point
    for (int i = 0; i < DATA_LENGTH; i++) {
        // 1. Original moving average calculation (one division per loop)
        sum = sum - buffer[i % BUFFER_SIZE];
        buffer[i % BUFFER_SIZE] = signal[i];
        sum = sum + buffer[i % BUFFER_SIZE];
        moving_average[i] = sum / BUFFER_SIZE;

        // ==========================================
        // Intensive Division Workload
        // ==========================================
        // This block is added to heavily load the processor's division unit.
        // It performs a long chain of dependent division operations.

        // 'volatile' is used to discourage the compiler from optimizing this loop away.
        // It forces the CPU to execute the divisions.
        volatile int heavy_calc = 1000000;

        for (int j = 1; j <= HEAVY_DIV_ITERATIONS; j++) {
            // This division is the core of the heavy workload.
            // The divisor `(j % 100) + 2` changes in each iteration and is never zero.
            // The dependency `heavy_calc = heavy_calc / ...` creates a chain
            // that the CPU must follow step-by-step.
            heavy_calc = heavy_calc / ((j % 100) + 2);

            // If heavy_calc becomes 0, the subsequent divisions will be trivial.
            // We reset it to a large number to keep the workload high.
            if (heavy_calc == 0) {
                heavy_calc = 1000000;
            }
        }

        // To ensure this whole block is not removed by the compiler as "unused code",
        // its final result is combined with the main result of the program.
        moving_average[i] += heavy_calc;
    }

    // ==========================================
    // Finalization and Exit
    // ==========================================
    // Consume the final result to prevent dead code elimination.
    int final_result = moving_average[DATA_LENGTH - 1];

    tohost = 1;  // Signal Spike/Simulator to halt successfully
    while(1);    // Safeguard loop

    return final_result;
}

