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

volatile unsigned long tohost = 0;
volatile unsigned long fromhost = 0;

#define N 5
#define M 10

int main() {
    // ==========================================
    // Section 1: 5x5 Matrix Multiplication
    // ==========================================
    int A[N][N] = {
        {1,  2,  3,  4,  5},
        {6,  7,  8,  9,  10},
        {11, 12, 13, 14, 15},
        {16, 17, 18, 19, 20},
        {21, 22, 23, 24, 25}
    };

    int B[N][N] = {
        {1, 0, 0, 0, 0},
        {0, 1, 0, 0, 0},
        {0, 0, 1, 0, 0},
        {0, 0, 0, 1, 0},
        {0, 0, 0, 0, 1}
    };

    int C[N][N];

    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            C[i][j] = 0;
            for (int k = 0; k < N; k++) {
                C[i][j] += A[i][k] * B[k][j];
            }
        }
    }

    // ==========================================
    // Section 2: 10x10 Matrix Multiplication
    // ==========================================
    // Manual initialization with mixed values (positive, negative, and zero)
    int A_10[M][M] = {
        {  1, -2,  3, -4,  5, -6,  7, -8,  9, -10},
        { 11, 12, 13, 14, 15, 16, 17, 18, 19,  20},
        { -1, -3, -5, -7, -9, -2, -4, -6, -8, -10},
        {  2,  4,  6,  8, 10, 12, 14, 16, 18,  20},
        {  5,  0,  5,  0,  5,  0,  5,  0,  5,   0},
        {  1,  1,  1,  1,  1, -1, -1, -1, -1,  -1},
        {  9,  8,  7,  6,  5,  4,  3,  2,  1,   0},
        { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100},
        { -5,-10,-15,-20,-25,-30,-35,-40,-45, -50},
        {  0,  2,  0,  4,  0,  6,  0,  8,  0,  10}
    };

    int B_10[M][M] = {
        {  1,  2,  1,  2,  1,  2,  1,  2,  1,  2},
        {  3,  4,  3,  4,  3,  4,  3,  4,  3,  4},
        {  5,  6,  5,  6,  5,  6,  5,  6,  5,  6},
        { -1,  1, -1,  1, -1,  1, -1,  1, -1,  1},
        {  0,  5,  0,  5,  0,  5,  0,  5,  0,  5},
        {  7,  7,  7,  7,  7,  7,  7,  7,  7,  7},
        { -2, -2, -2, -2, -2, -2, -2, -2, -2, -2},
        {  1,  0,  1,  0,  1,  0,  1,  0,  1,  0},
        {  8,  9, 10, 11, 12, 13, 14, 15, 16, 17},
        { -5, -4, -3, -2, -1,  0,  1,  2,  3,  4}
    };

    int C_10[M][M];

    // 10x10 Matrix multiplication operation
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < M; j++) {
            C_10[i][j] = 0;
            for (int k = 0; k < M; k++) {
                C_10[i][j] += A_10[i][k] * B_10[k][j];
            }
        }
    }

    // ==========================================
    // Finalization and Exit
    // ==========================================
    // Consume both results to prevent compiler optimization (dead code elimination)
    int final_result = C[4][4] + C_10[9][9];

    tohost = 1;  // Signal Spike/Simulator to halt successfully
    while(1);    // Keep CPU busy in an infinite loop as a safeguard
    
    return final_result; 
}

