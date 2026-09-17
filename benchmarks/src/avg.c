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

#define BUFFER_SIZE 5
#define DATA_LENGTH 10

// This program implements a simple moving average filter
// which includes consecutive subtraction, addition, and division operations.

int main() {
    // ==========================================
    // Moving Average Filter Implementation
    // ==========================================
    int signal[DATA_LENGTH] = {100, 110, 105, 120, 115, 130, 125, 140, 135, 150};
    int buffer[BUFFER_SIZE] = {0};
    int sum = 0;
    int moving_average[DATA_LENGTH];

    for (int i = 0; i < DATA_LENGTH; i++) {
        // 1. Subtraction: Remove the oldest value from the sum (simulating a sliding window)
        sum = sum - buffer[i % BUFFER_SIZE];

        // 2. Addition: Add the new value to the buffer and the sum
        buffer[i % BUFFER_SIZE] = signal[i];
        sum = sum + buffer[i % BUFFER_SIZE];

        // 3. Division: Calculate the average (often done using bit shifts in hardware)
        // Standard division is used here
        moving_average[i] = sum / BUFFER_SIZE;
    }

    // ==========================================
    // Finalization and Exit
    // ==========================================
    // Consume the final result to prevent compiler optimization (dead code elimination)
    int final_result = moving_average[DATA_LENGTH - 1];

    tohost = 1;  // Signal Spike/Simulator to halt successfully
    while(1);    // Keep CPU busy in an infinite loop as a safeguard
    
    return final_result; 
}

