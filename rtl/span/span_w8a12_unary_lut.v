`timescale 1ns/1ps

// Signed W8A12 unary lookup table.
//
// Address mapping is two's-complement signed input shifted by 2^(ACT_W-1):
//   -2048 -> 0, -1 -> 2047, 0 -> 2048, 2047 -> 4095.
module span_w8a12_unary_lut #(
    parameter integer ACT_W = 12,
    parameter LUT_FILE = ""
) (
    input  wire signed [ACT_W-1:0] x_i,
    output wire signed [ACT_W-1:0] y_o
);
    localparam integer LUT_DEPTH = 1 << ACT_W;

    reg signed [ACT_W-1:0] lut_mem [0:LUT_DEPTH-1];
    wire [ACT_W-1:0] sign_offset = {1'b1, {(ACT_W-1){1'b0}}};
    wire [ACT_W-1:0] lut_addr = x_i ^ sign_offset;

    initial begin
        if (LUT_FILE != "")
            $readmemh(LUT_FILE, lut_mem);
    end

    assign y_o = lut_mem[lut_addr];
endmodule
