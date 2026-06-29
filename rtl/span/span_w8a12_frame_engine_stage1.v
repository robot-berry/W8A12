`timescale 1ns/1ps
`include "../generated/reds_span_x4_f48_w8a12/frame_engine/span_w8a12_frame_engine_plan.vh"

// Stage 1 of the REDS-trained W8A12 SPAN frame engine.
//
// This is not the final SR image engine. It is the first synthesizable slice
// of the xsim-proven schedule:
//
//   RGB stream -> 3x3 RGB window -> W8A12 normalization -> conv_1 -> feat0 banks
//
// The stored feat0 banks are the long skip consumed later by conv_cat.
module span_w8a12_frame_engine_stage1 #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 8,
    parameter integer IMG_H = 8,
    parameter integer ACT_W = `W8A12_FRAME_ACT_W,
    parameter integer CH = `W8A12_FRAME_CHANNELS,
    parameter integer BANKS = 4,
    parameter integer BANK_CH = CH / BANKS,
    parameter integer ACC_W = 48,
    parameter integer FRAME_PIXELS = IMG_W * IMG_H,
    parameter integer FRAME_ADDR_W = (FRAME_PIXELS <= 2) ? 1 : $clog2(FRAME_PIXELS)
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire [DATA_W-1:0]            s_data,
    input  wire                         s_user,
    input  wire                         s_last,

    output reg                          busy,
    output reg                          done,
    output reg  [31:0]                  input_count,
    output reg  [31:0]                  feat_count,

    input  wire                         feat_rd_en,
    input  wire [FRAME_ADDR_W-1:0]      feat_rd_addr,
    output wire signed [BANK_CH*ACT_W-1:0] feat_bank0_rdata,
    output wire signed [BANK_CH*ACT_W-1:0] feat_bank1_rdata,
    output wire signed [BANK_CH*ACT_W-1:0] feat_bank2_rdata,
    output wire signed [BANK_CH*ACT_W-1:0] feat_bank3_rdata
);
    wire conv1_valid;
    wire conv1_ready;
    wire [CH*ACT_W-1:0] conv1_feat;
    wire conv1_user;
    wire conv1_last;

    wire take_input = s_valid && s_ready;
    wire take_feat = conv1_valid && conv1_ready;
    wire frame_input_first = take_input && s_user;
    wire frame_feat_last = take_feat && (feat_count == FRAME_PIXELS-1);

    span_w8a12_conv1_frontend #(
        .DATA_W(DATA_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .OUT_CH(CH)
    ) u_conv1_frontend (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_user(s_user),
        .s_last(s_last),
        .m_valid(conv1_valid),
        .m_ready(conv1_ready),
        .m_feat(conv1_feat),
        .m_user(conv1_user),
        .m_last(conv1_last)
    );

    assign conv1_ready = 1'b1;

    reg [FRAME_ADDR_W-1:0] feat_waddr;
    wire feat_we = take_feat;
    wire [FRAME_ADDR_W-1:0] feat_raddr = feat_rd_en ? feat_rd_addr : {FRAME_ADDR_W{1'b0}};

    wire signed [BANK_CH*ACT_W-1:0] feat_bank0_wdata = conv1_feat[0*BANK_CH*ACT_W +: BANK_CH*ACT_W];
    wire signed [BANK_CH*ACT_W-1:0] feat_bank1_wdata = conv1_feat[1*BANK_CH*ACT_W +: BANK_CH*ACT_W];
    wire signed [BANK_CH*ACT_W-1:0] feat_bank2_wdata = conv1_feat[2*BANK_CH*ACT_W +: BANK_CH*ACT_W];
    wire signed [BANK_CH*ACT_W-1:0] feat_bank3_wdata = conv1_feat[3*BANK_CH*ACT_W +: BANK_CH*ACT_W];

    span_sync_ram_1r1w #(
        .DATA_W(BANK_CH*ACT_W),
        .DEPTH(FRAME_PIXELS),
        .ADDR_W(FRAME_ADDR_W)
    ) u_feat0_bank0 (
        .clk(clk),
        .we(feat_we),
        .waddr(feat_waddr),
        .wdata(feat_bank0_wdata),
        .raddr(feat_raddr),
        .rdata(feat_bank0_rdata)
    );

    span_sync_ram_1r1w #(
        .DATA_W(BANK_CH*ACT_W),
        .DEPTH(FRAME_PIXELS),
        .ADDR_W(FRAME_ADDR_W)
    ) u_feat0_bank1 (
        .clk(clk),
        .we(feat_we),
        .waddr(feat_waddr),
        .wdata(feat_bank1_wdata),
        .raddr(feat_raddr),
        .rdata(feat_bank1_rdata)
    );

    span_sync_ram_1r1w #(
        .DATA_W(BANK_CH*ACT_W),
        .DEPTH(FRAME_PIXELS),
        .ADDR_W(FRAME_ADDR_W)
    ) u_feat0_bank2 (
        .clk(clk),
        .we(feat_we),
        .waddr(feat_waddr),
        .wdata(feat_bank2_wdata),
        .raddr(feat_raddr),
        .rdata(feat_bank2_rdata)
    );

    span_sync_ram_1r1w #(
        .DATA_W(BANK_CH*ACT_W),
        .DEPTH(FRAME_PIXELS),
        .ADDR_W(FRAME_ADDR_W)
    ) u_feat0_bank3 (
        .clk(clk),
        .we(feat_we),
        .waddr(feat_waddr),
        .wdata(feat_bank3_wdata),
        .raddr(feat_raddr),
        .rdata(feat_bank3_rdata)
    );

    always @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0;
            done <= 1'b0;
            input_count <= 32'd0;
            feat_count <= 32'd0;
            feat_waddr <= {FRAME_ADDR_W{1'b0}};
        end else begin
            if (frame_input_first) begin
                busy <= 1'b1;
                done <= 1'b0;
                input_count <= 32'd1;
                feat_count <= 32'd0;
                feat_waddr <= {FRAME_ADDR_W{1'b0}};
            end else if (take_input) begin
                input_count <= input_count + 32'd1;
            end

            if (take_feat) begin
                if (frame_feat_last) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    feat_count <= feat_count + 32'd1;
                    feat_waddr <= {FRAME_ADDR_W{1'b0}};
                end else begin
                    feat_count <= feat_count + 32'd1;
                    feat_waddr <= feat_waddr + 1'b1;
                end
            end
        end
    end

    wire unused_flags = conv1_user | conv1_last;
endmodule
