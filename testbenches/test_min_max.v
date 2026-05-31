module test;
    reg [31:0] a, b;
    wire [31:0] fmin_res, fmax_res;
    wire is_nan_a = (a[30:23] == 8'hFF) && (a[22:0] != 23'd0);
    wire is_nan_b = (b[30:23] == 8'hFF) && (b[22:0] != 23'd0);
    wire is_zero_a = (a[30:0] == 31'd0);
    wire is_zero_b = (b[30:0] == 31'd0);

    wire a_lt_b_mag = (a[30:0] < b[30:0]);
    wire a_eq_b_mag = (a[30:0] == b[30:0]);

    wire a_eq_b = (is_nan_a || is_nan_b) ? 1'b0 : 
                  (is_zero_a && is_zero_b) ? 1'b1 :
                  (a == b);

    wire a_lt_b = (is_nan_a || is_nan_b) ? 1'b0 :
                  (is_zero_a && is_zero_b) ? 1'b0 :
                  (a[31] != b[31]) ? (a[31] == 1'b1) :
                  (a[31] == 1'b0) ? a_lt_b_mag : (!a_lt_b_mag && !a_eq_b_mag);

    assign fmin_res = (is_nan_a && is_nan_b) ? 32'h7FC00000 : 
                      (is_nan_a) ? b :
                      (is_nan_b) ? a :
                      (is_zero_a && is_zero_b) ? ((a[31] == 1'b1) ? a : b) : 
                      (a_lt_b) ? a : b;

    assign fmax_res = (is_nan_a && is_nan_b) ? 32'h7FC00000 : 
                      (is_nan_a) ? b :
                      (is_nan_b) ? a :
                      (is_zero_a && is_zero_b) ? ((a[31] == 1'b0) ? a : b) : 
                      (a_lt_b) ? b : a;

    initial begin
        a = 32'h40000000; b = 32'h40400000;
        #1; $display("min(2, 3) = %h, max(2, 3) = %h", fmin_res, fmax_res);
        a = 32'hC0000000; b = 32'hC0400000;
        #1; $display("min(-2, -3) = %h, max(-2, -3) = %h", fmin_res, fmax_res);
    end
endmodule