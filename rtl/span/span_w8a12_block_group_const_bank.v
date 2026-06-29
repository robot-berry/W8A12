`timescale 1ns/1ps

// Runtime-selected W8A12 layer constants for one c1/c2/c3 stage across blocks.
//
// The memory files are built by tools/build_span_w8a12_block_group_mem.py as
// block-major concatenations:
//   block_1 entries, block_2 entries, ..., block_6 entries.
module span_w8a12_block_group_const_bank #(
    parameter integer BLOCKS = 6,
    parameter integer BLOCK_W = (BLOCKS <= 2) ? 1 : $clog2(BLOCKS),
    parameter integer WEIGHT_COUNT_PER_BLOCK = 20736,
    parameter integer OUT_CH = 48,
    parameter integer TOTAL_WEIGHT_COUNT = BLOCKS * WEIGHT_COUNT_PER_BLOCK,
    parameter integer TOTAL_OUT_CH = BLOCKS * OUT_CH,
    parameter WEIGHT_FILE = "",
    parameter BIAS_I64_FILE = "",
    parameter REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = "",
    parameter integer SYNC_READ = 1
) (
    input  wire                         clk,
    input  wire [BLOCK_W-1:0]           block_i,
    input  wire [31:0]                  weight_addr,
    input  wire [7:0]                   out_ch_addr,
    output reg  signed [7:0]            weight_o,
    output reg  signed [63:0]           bias_i64_o,
    output reg  signed [31:0]           requant_q31_o,
    output reg  [7:0]                   requant_shift_o
);
    (* rom_style = "block" *) reg signed [7:0]  weight_mem [0:TOTAL_WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [63:0] bias_mem [0:TOTAL_OUT_CH-1];
    (* rom_style = "block" *) reg signed [31:0] requant_mem [0:TOTAL_OUT_CH-1];
    (* rom_style = "block" *) reg [7:0]         shift_mem [0:TOTAL_OUT_CH-1];

    wire block_in_range = (block_i < BLOCKS);
    wire [31:0] block_weight_base = block_i * WEIGHT_COUNT_PER_BLOCK;
    wire [31:0] block_ch_base = block_i * OUT_CH;
    wire [31:0] weight_idx = block_weight_base + weight_addr;
    wire [31:0] ch_idx = block_ch_base + out_ch_addr;
    wire weight_in_range = block_in_range && (weight_addr < WEIGHT_COUNT_PER_BLOCK) &&
                           (weight_idx < TOTAL_WEIGHT_COUNT);
    wire ch_in_range = block_in_range && (out_ch_addr < OUT_CH) && (ch_idx < TOTAL_OUT_CH);

    // Keep large simulation defaults out of synthesis. Vivado treats the
    // TOTAL_WEIGHT_COUNT loop as over its initial-block limit and then drops
    // the following $readmemh initializers too.
    integer i;
    // synthesis translate_off
    initial begin
        for (i = 0; i < TOTAL_WEIGHT_COUNT; i = i + 1)
            weight_mem[i] = 8'sd0;
        for (i = 0; i < TOTAL_OUT_CH; i = i + 1) begin
            bias_mem[i] = 64'sd0;
            requant_mem[i] = 32'sd0;
            shift_mem[i] = 8'd31;
        end
    end
    // synthesis translate_on

    initial begin
        if (WEIGHT_FILE != "")
            $readmemh(WEIGHT_FILE, weight_mem);
        if (BIAS_I64_FILE != "")
            $readmemh(BIAS_I64_FILE, bias_mem);
        if (REQUANT_Q31_FILE != "")
            $readmemh(REQUANT_Q31_FILE, requant_mem);
        if (REQUANT_SHIFT_FILE != "")
            $readmemh(REQUANT_SHIFT_FILE, shift_mem);
    end

    generate
        if (SYNC_READ != 0) begin : g_sync_read
            always @(posedge clk) begin
                weight_o <= weight_in_range ? weight_mem[weight_idx] : 8'sd0;
                if (ch_in_range) begin
                    bias_i64_o <= bias_mem[ch_idx];
                    requant_q31_o <= requant_mem[ch_idx];
                    requant_shift_o <= shift_mem[ch_idx];
                end else begin
                    bias_i64_o <= 64'sd0;
                    requant_q31_o <= 32'sd0;
                    requant_shift_o <= 8'd31;
                end
            end
        end else begin : g_comb_read
            always @(*) begin
                weight_o = weight_in_range ? weight_mem[weight_idx] : 8'sd0;
                if (ch_in_range) begin
                    bias_i64_o = bias_mem[ch_idx];
                    requant_q31_o = requant_mem[ch_idx];
                    requant_shift_o = shift_mem[ch_idx];
                end else begin
                    bias_i64_o = 64'sd0;
                    requant_q31_o = 32'sd0;
                    requant_shift_o = 8'd31;
                end
            end
        end
    endgenerate
endmodule
