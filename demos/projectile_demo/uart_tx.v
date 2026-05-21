`timescale 1ns / 1ps
module uart_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] tx_data,
    input  wire       tx_en,
    output reg        tx_pin,
    output wire       tx_busy
);

    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;

    reg [3:0]  state;
    reg [31:0] timer;
    reg [2:0]  bit_cnt;
    reg [7:0]  shift_reg;

    localparam IDLE  = 4'd0;
    localparam START = 4'd1;
    localparam DATA  = 4'd2;
    localparam STOP  = 4'd3;

    assign tx_busy = (state != IDLE);

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state     <= IDLE;
            timer     <= 0;
            bit_cnt   <= 0;
            shift_reg <= 0;
            tx_pin    <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    tx_pin <= 1'b1;
                    if (tx_en) begin
                        shift_reg <= tx_data;
                        state     <= START;
                        timer     <= 0;
                    end
                end

                START: begin
                    tx_pin <= 1'b0;
                    if (timer < BIT_PERIOD - 1) begin
                        timer <= timer + 1;
                    end else begin
                        timer <= 0;
                        state <= DATA;
                        bit_cnt <= 0;
                    end
                end

                DATA: begin
                    tx_pin <= shift_reg[0];
                    if (timer < BIT_PERIOD - 1) begin
                        timer <= timer + 1;
                    end else begin
                        timer <= 0;
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        if (bit_cnt < 7) begin
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_pin <= 1'b1;
                    if (timer < BIT_PERIOD - 1) begin
                        timer <= timer + 1;
                    end else begin
                        timer <= 0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
