`timescale 1ns / 1ps
module projectile_top (
    input  wire clk,        // 100 MHz
    input  wire reset,      // CPU_RESETN (Active Low)
    input  wire [7:0] sw,   // sw[3:0]=Angle, sw[7:4]=Power
    output wire uart_tx,    // Connected to USB-UART Bridge
    output wire [15:0] led,
    output reg [6:0] seg,
    output reg [7:0] an
);

    wire [31:0] pc_display;
    wire [31:0] led_display; // This will hold our LIVE DISTANCE
    wire exception;

    // Declare UART communication wires
    wire [7:0] uart_data;
    wire       uart_en_raw;
    wire       uart_tx_busy;
    
    // Clock division for 7-segment multiplexing
    reg [20:0] clk_div;
    always @(posedge clk or negedge reset) begin
        if (!reset) clk_div <= 0;
        else clk_div <= clk_div + 1;
    end
    
    // Logic for 7-segment scanning
    wire [2:0] seg_sel = clk_div[19:17];
    reg [3:0] hex_digit;

    always @(*) begin
        an = 8'b11111111;
        an[seg_sel] = 1'b0; // Enable one digit at a time
        case (seg_sel)
            3'b000: hex_digit = led_display[3:0];
            3'b001: hex_digit = led_display[7:4];
            3'b010: hex_digit = led_display[11:8];
            3'b011: hex_digit = led_display[15:12];
            3'b100: hex_digit = led_display[19:16];
            3'b101: hex_digit = led_display[23:20];
            3'b110: hex_digit = led_display[27:24];
            3'b111: hex_digit = led_display[31:28];
        endcase
    end

    // Hex to 7-Segment Decoder
    always @(*) begin
        case (hex_digit)
            4'h0: seg = 7'b1000000; 4'h1: seg = 7'b1111001; 4'h2: seg = 7'b0100100; 4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001; 4'h5: seg = 7'b0010010; 4'h6: seg = 7'b0000010; 4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000; 4'h9: seg = 7'b0010000; 4'hA: seg = 7'b0001000; 4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110; 4'hD: seg = 7'b0100001; 4'hE: seg = 7'b0000110; 4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase
    end

    // Use a 6.25 MHz clock (100MHz / 16) - very safe for timing/FPU
    wire sys_clk;
    BUFG bufg_sys ( .I(clk_div[3]), .O(sys_clk) ); 

    // UART Pulse Generator (Strict single-pulse at 100MHz)
    reg uart_en_sync, uart_en_sync_old;
    always @(posedge clk) begin
        uart_en_sync <= uart_en_raw;
        uart_en_sync_old <= uart_en_sync;
    end
    wire uart_pulse = uart_en_sync && !uart_en_sync_old;

    pipe #(
        .IMEM_INIT_FILE("C:/Users/parya/OneDrive/Desktop/lab5/final_till_22_4_26/riscv-32im/projectile_demo/projectile_imem.hex"),
        .DMEM_INIT_FILE("C:/Users/parya/OneDrive/Desktop/lab5/final_till_22_4_26/riscv-32im/projectile_demo/projectile_dmem.hex")
    ) cpu_core (
        .clk(sys_clk), .reset(reset), .stall(1'b0), .sw(sw),
        .exception(exception), .pc_out(pc_display), .led_out(led_display),
        .l1_hit_count(), .l1_miss_count(), .cycle_count(),
        .uart_tx_en(uart_en_raw), .uart_tx_data(uart_data),
        .uart_tx_busy(uart_tx_busy)
    );

    uart_tx #( .CLK_FREQ(100_000_000), .BAUD_RATE(115_200) ) uart_inst (
        .clk(clk), .reset(reset), .tx_data(uart_data), .tx_en(uart_pulse), .tx_pin(uart_tx), .tx_busy(uart_tx_busy)
    );

    // --- DIAGNOSTIC DEBUGGER ---
    // led[0]    : Reset State (On = Running, Off = Resetting)
    // led[1]    : Clock Alive (Should be blinking very fast)
    // led[15:4] : Actual PC (Program Counter). If this moves, the CPU is running!
    assign led[0] = reset;
    assign led[1] = sys_clk;
    assign led[15:4] = pc_display[13:2]; 
    assign led[3:2] = sw[1:0]; // Show some switches for feedback

endmodule
