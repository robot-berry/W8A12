`timescale 1ns/1ps

// Runtime-selected W8A12 unary lookup table across blocks.
//
// The LUT file is block-major concatenated by
// tools/build_span_w8a12_block_group_mem.py:
//   block_1 LUT, block_2 LUT, ..., block_6 LUT.
module span_w8a12_block_group_unary_lut #(
    parameter integer ACT_W = 12,
    parameter integer BLOCKS = 6,
    parameter integer BLOCK_W = (BLOCKS <= 2) ? 1 : $clog2(BLOCKS),
    parameter integer LUT_DEPTH = 1 << ACT_W,
    parameter integer TOTAL_LUT_DEPTH = BLOCKS * LUT_DEPTH,
    parameter LUT_FILE = ""
) (
    input  wire [BLOCK_W-1:0]          block_i,
    input  wire signed [ACT_W-1:0]     x_i,
    output wire signed [ACT_W-1:0]     y_o
);
    reg signed [ACT_W-1:0] lut_mem [0:TOTAL_LUT_DEPTH-1];

    wire block_in_range = (block_i < BLOCKS);
    wire [ACT_W-1:0] sign_offset = {1'b1, {(ACT_W-1){1'b0}}};
    wire [ACT_W-1:0] local_addr = x_i ^ sign_offset;
    wire [31:0] lut_addr = block_i * LUT_DEPTH + local_addr;

    integer i;
    // synthesis translate_off
    initial begin
        for (i = 0; i < TOTAL_LUT_DEPTH; i = i + 1)
            lut_mem[i] = {ACT_W{1'b0}};
    end
    // synthesis translate_on

    initial begin
        if (LUT_FILE != "")
            $readmemh(LUT_FILE, lut_mem);
    end

    assign y_o = (block_in_range && (lut_addr < TOTAL_LUT_DEPTH)) ?
                 lut_mem[lut_addr] : {ACT_W{1'b0}};
endmodule

// Synchronous-read variant for synthesis paths that should infer ROM resources
// instead of a very large combinational mux tree.
module span_w8a12_block_group_unary_lut_sync #(
    parameter integer ACT_W = 12,
    parameter integer BLOCKS = 6,
    parameter integer BLOCK_W = (BLOCKS <= 2) ? 1 : $clog2(BLOCKS),
    parameter integer LUT_DEPTH = 1 << ACT_W,
    parameter integer TOTAL_LUT_DEPTH = BLOCKS * LUT_DEPTH,
    parameter LUT_FILE = ""
) (
    input  wire                         clk,
    input  wire                         en,
    input  wire [BLOCK_W-1:0]           block_i,
    input  wire signed [ACT_W-1:0]      x_i,
    output reg  signed [ACT_W-1:0]      y_o
);
    (* rom_style = "block", ram_style = "block" *)
    reg signed [ACT_W-1:0] lut_mem [0:TOTAL_LUT_DEPTH-1];

    wire block_in_range = (block_i < BLOCKS);
    wire [ACT_W-1:0] sign_offset = {1'b1, {(ACT_W-1){1'b0}}};
    wire [ACT_W-1:0] local_addr = x_i ^ sign_offset;
    wire [31:0] lut_addr = block_i * LUT_DEPTH + local_addr;

    integer i;
    // synthesis translate_off
    initial begin
        for (i = 0; i < TOTAL_LUT_DEPTH; i = i + 1)
            lut_mem[i] = {ACT_W{1'b0}};
    end
    // synthesis translate_on

    initial begin
        if (LUT_FILE != "")
            $readmemh(LUT_FILE, lut_mem);
    end

    always @(posedge clk) begin
        if (en)
            y_o <= (block_in_range && (lut_addr < TOTAL_LUT_DEPTH)) ?
                   lut_mem[lut_addr] : {ACT_W{1'b0}};
    end
endmodule
