`timescale 1ns/1ps

// Single-layer constant bank for the REDS-trained SPAN W8A12 datapath.
//
// Each instance binds one conv layer from span_w8a12_layers.vh:
//   - signed int8 weights
//   - signed int64 accumulator-domain bias
//   - signed Q31 requant multiplier per output channel
//   - 8-bit requant shift per output channel
module span_w8a12_layer_const_bank #(
    parameter integer WEIGHT_COUNT = 1,
    parameter integer OUT_CH = 1,
    parameter WEIGHT_FILE = "",
    parameter BIAS_I64_FILE = "",
    parameter REQUANT_Q31_FILE = "",
    parameter REQUANT_SHIFT_FILE = "",
    parameter integer SYNC_READ = 0
) (
    input  wire                         clk,
    input  wire [31:0]                  weight_addr,
    input  wire [7:0]                   out_ch_addr,
    output reg  signed [7:0]            weight_o,
    output reg  signed [63:0]           bias_i64_o,
    output reg  signed [31:0]           requant_q31_o,
    output reg  [7:0]                   requant_shift_o
);
    (* rom_style = "block" *) reg signed [7:0]  weight_mem [0:WEIGHT_COUNT-1];
    (* rom_style = "block" *) reg signed [63:0] bias_mem [0:OUT_CH-1];
    (* rom_style = "block" *) reg signed [31:0] requant_mem [0:OUT_CH-1];
    (* rom_style = "block" *) reg [7:0]         shift_mem [0:OUT_CH-1];

    integer i;
    initial begin
        for (i = 0; i < WEIGHT_COUNT; i = i + 1)
            weight_mem[i] = 8'sd0;
        for (i = 0; i < OUT_CH; i = i + 1) begin
            bias_mem[i] = 64'sd0;
            requant_mem[i] = 32'sd0;
            shift_mem[i] = 8'd31;
        end

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
                weight_o <= (weight_addr < WEIGHT_COUNT) ? weight_mem[weight_addr] : 8'sd0;
                if (out_ch_addr < OUT_CH) begin
                    bias_i64_o <= bias_mem[out_ch_addr];
                    requant_q31_o <= requant_mem[out_ch_addr];
                    requant_shift_o <= shift_mem[out_ch_addr];
                end else begin
                    bias_i64_o <= 64'sd0;
                    requant_q31_o <= 32'sd0;
                    requant_shift_o <= 8'd31;
                end
            end
        end else begin : g_comb_read
            always @(*) begin
                weight_o = (weight_addr < WEIGHT_COUNT) ? weight_mem[weight_addr] : 8'sd0;
                if (out_ch_addr < OUT_CH) begin
                    bias_i64_o = bias_mem[out_ch_addr];
                    requant_q31_o = requant_mem[out_ch_addr];
                    requant_shift_o = shift_mem[out_ch_addr];
                end else begin
                    bias_i64_o = 64'sd0;
                    requant_q31_o = 32'sd0;
                    requant_shift_o = 8'd31;
                end
            end
        end
    endgenerate
endmodule
