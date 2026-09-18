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

int main() {
    // ==========================================
    // USER CUSTOM CODE GOES HERE
    // ==========================================
    
    
    
    // ==========================================
    // PROGRAM TERMINATION AND EXIT
    // ==========================================
    
    // Signal successful completion to the simulator (Spike/Verilator)
    tohost = 1;  
    
    // Trap the processor in an infinite loop to prevent executing junk memory
    while(1);    
    
    return 0; 
}

