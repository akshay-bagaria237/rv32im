/* 
 * Projectile Motion Demo for RISC-V 32IM + FPU
 * This program calculates the path of a tank shell and 
 * sends coordinates over UART for visualization.
 */

#define LED_REG      (*(volatile int*) 0x80000000)
#define SWITCHES     (*(volatile int*) 0x80000004)
#define UART_TX_REG  (*(volatile char*)0x80000008)
#define UART_STAT_REG (*(volatile int*) 0x80000008)

// Simple delay function
void delay(int cycles) {
    for(volatile int i=0; i<cycles; i++);
}

// Function to send a byte over UART with busy-wait
void uart_send_byte(char c) {
    while(UART_STAT_REG & 1); // Wait for UART to not be busy
    UART_TX_REG = c;
}

// Binary protocol for visualization: [0xAA, X, Y, 0x55]
void send_coords(float x, float y) {
    int ix = (int)x;
    int iy = (int)y;
    
    uart_send_byte((char)0xAA);
    uart_send_byte((char)ix);
    uart_send_byte((char)iy);
    uart_send_byte((char)0x55);
    
    LED_REG = ix; // Also show distance on 7-segment display
}

int main() {
    float g = 0.1f;
    float dx = 0.5f;
    
    while(1) {
        int sw_val = SWITCHES;
        float vy = (float)((sw_val >> 4) & 0xF); 
        if (vy < 5.0f) vy = 5.0f; // Minimum power
        
        float x = 0.0f;
        float y = 0.0f;

        while(y >= 0.0f) {
            send_coords(x, y);
            
            x += dx;
            y += vy;
            vy -= g;
            
            delay(125000); // ~20ms delay for visualization
        }
        
        delay(12500000); // ~2s wait before next shot
    }
    return 0;
}
