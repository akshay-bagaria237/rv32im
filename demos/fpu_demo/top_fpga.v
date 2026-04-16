`timescale 1ns / 1ps
module top_fpga #(
    parameter IMEMSIZE = 4096,
    parameter DMEMSIZE = 4096
)(
    input  wire clk,        // Fast board clock (100 MHz)
    input  wire reset,      // Active-low reset
    input  wire [2:0] sw,   // Slide switches [2:0]
    output [15:0] led,
    output reg [6:0] seg,   // 7-segment display segments (A-G)
    output reg [7:0] an     // 7-segment anodes (8 digits for Nexys A7)
);

wire [31:0] pc_display;
wire [31:0] led_display;
wire exception;

// PC shown on LEDs for progress tracking
assign led = pc_display[15:0]; 

reg [25:0] clk_div;
always @(posedge clk or negedge reset) begin
    if (!reset) clk_div <= 0;
    else clk_div <= clk_div + 1;
end

wire slow_clk;
BUFG bufg_inst (
    .I(clk_div[23]),  // ~12 Hz
    .O(slow_clk)
);

wire [31:0] l1_hit_cnt, l1_miss_cnt, cycle_cnt;

pipe pipe_u (
    .clk(slow_clk), .reset(reset), .stall(1'b0), .sw(sw),
    .exception(exception), .pc_out(pc_display), .led_out(led_display),
    .l1_hit_count(l1_hit_cnt), .l1_miss_count(l1_miss_cnt), .cycle_count(cycle_cnt)
);

// Multiplexing logic for 8 digits
reg [2:0] seg_sel;
always @(posedge clk or negedge reset) begin
    if (!reset) seg_sel <= 0;
    else if (clk_div[16:0] == 0) seg_sel <= seg_sel + 1;
end

reg [3:0] hex_digit;
wire [15:0] metrics_val = (sw[1:0] == 2'b00) ? l1_hit_cnt[15:0]  :
                          (sw[1:0] == 2'b01) ? l1_miss_cnt[15:0] :
                          (sw[1:0] == 2'b10) ? (l1_hit_cnt[15:0] + l1_miss_cnt[15:0]) :
                                               cycle_cnt[15:0];

always @(*) begin
    an = 8'b11111111; // Default all OFF
    hex_digit = 4'h0;
    if (sw[2]) begin
        // --- PROGRAM OUTPUT MODE (8 DIGITS) ---
        an[seg_sel] = 1'b0; // Enable the current digit
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
    end else begin
        // --- METRICS MODE (LOWER 4 DIGITS ONLY) ---
        if (seg_sel < 4) begin
            an[seg_sel] = 1'b0;
            case (seg_sel)
                3'b000: hex_digit = metrics_val[3:0];
                3'b001: hex_digit = metrics_val[7:4];
                3'b010: hex_digit = metrics_val[11:8];
                3'b011: hex_digit = metrics_val[15:12];
                default: hex_digit = 4'h0;
            endcase
        end
    end
end

always @(*) begin
    case (hex_digit)
        4'h0: seg = 7'b1000000; 4'h1: seg = 7'b1111001; 4'h2: seg = 7'b0100100; 4'h3: seg = 7'b0110000;
        4'h4: seg = 7'b0011001; 4'h5: seg = 7'b0010010; 4'h6: seg = 7'b0000010; 4'h7: seg = 7'b1111000;
        4'h8: seg = 7'b0000000; 4'h9: seg = 7'b0010000; 4'hA: seg = 7'b0001000; 4'hB: seg = 7'b0000011;
        4'hC: seg = 7'b1000110; 4'hD: seg = 7'b0100001; 4'hE: seg = 7'b0000110; 4'hF: seg = 7'b0001110;
        default: seg = 7'b1111111; 
    endcase
end
endmodule
