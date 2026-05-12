import serial
import pygame
import sys

# --- CONFIGURATION ---
SERIAL_PORT = 'COM6'  # Updated to COM7 for FPGA
BAUD_RATE = 115200
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600

# --- INITIALIZATION ---
try:
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.1)
except:
    print(f"Error: Could not open {SERIAL_PORT}. Check your COM port.")
    sys.exit()

pygame.init()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("RISC-V Tank Projectile Demo")
clock = pygame.time.Clock()

# Colors
BLACK = (0, 0, 0)
GREEN = (0, 255, 0)
RED   = (255, 0, 0)
WHITE = (255, 255, 255)

path = []

running = True
while running:
    screen.fill(BLACK)
    
    # Draw Ground
    pygame.draw.line(screen, WHITE, (0, 550), (SCREEN_WIDTH, 550), 2)
    
    # Draw Tank (at the left)
    pygame.draw.rect(screen, GREEN, (40, 530, 40, 20))
    pygame.draw.circle(screen, GREEN, (60, 530), 10)
    
    # Read from UART (Binary Protocol: [0xAA, X, Y, 0x55])
    if ser.in_waiting > 0:
        data = ser.read(ser.in_waiting)
        i = 0
        while i <= len(data) - 4:
            if data[i] == 170 and data[i+3] == 85: # Strict AA...55
                x_val = data[i+1]
                y_val = data[i+2]
                
                # New Scale: 2.8 (255 * 2.8 = 714 pixels, fits perfectly in 800)
                x_scale = x_val * 2.8
                y_scale = y_val * 2.8
                
                # Clear path if it's a new shot (low x and high prev x)
                if x_val < 3 and (not path or path[-1][0] > 100):
                    path = []
                
                path.append((70 + x_scale, 530 - y_scale))
                i += 4
            else:
                i += 1

    # Draw Text Info
    font = pygame.font.SysFont("Arial", 18)
    if path:
        last_x = int((path[-1][0] - 70) / 2.8)
        last_y = int((530 - path[-1][1]) / 2.8)
        img = font.render(f"Distance: {last_x}  Height: {last_y}", True, WHITE)
        screen.blit(img, (20, 20))
    else:
        img = font.render("Waiting for projectile...", True, WHITE)
        screen.blit(img, (20, 20))

    # Draw Projectile Path
    if len(path) > 1:
        pygame.draw.lines(screen, RED, False, path, 4) # Thicker path
    
    # Draw current projectile position
    if path:
        pygame.draw.circle(screen, RED, (int(path[-1][0]), int(path[-1][1])), 10) # Larger ball

    # Draw Ground more clearly
    pygame.draw.line(screen, WHITE, (0, 550), (SCREEN_WIDTH, 550), 5)

    # Event handling
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    pygame.display.flip()
    clock.tick(60)

pygame.quit()
ser.close()
