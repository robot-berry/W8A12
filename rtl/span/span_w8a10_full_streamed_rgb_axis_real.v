`timescale 1ns/1ps

// W8A10 wrapper for the existing streamed REDS SPAN RGB AXIS path.
//
// The implementation reuses the W8A12-named streamed RTL with ACT_W=10 and
// expects the build script to define REDS_SPAN_USE_W8A10_GENERATED so the
// generated constants, postprocess LUTs, and group weights come from the W8A10
// export directory.
(* keep_hierarchy = "yes" *)
module span_w8a10_full_streamed_rgb_axis_real #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer SCALE_LANES = 2,
    parameter integer Q_TO_U8_MULT = 562883813,
    parameter integer Q_TO_U8_SHIFT = 30
) (
    input  wire              aclk,
    input  wire              aresetn,

    input  wire              s_axis_tvalid,
    output wire              s_axis_tready,
    input  wire [DATA_W-1:0] s_axis_tdata,
    input  wire              s_axis_tuser,
    input  wire              s_axis_tlast,

    output wire              m_axis_tvalid,
    input  wire              m_axis_tready,
    output wire [DATA_W-1:0] m_axis_tdata,
    output wire              m_axis_tuser,
    output wire              m_axis_tlast
);
    localparam integer ACT_W = 10;

    span_w8a12_full_streamed_rgb_axis #(
        .DATA_W(DATA_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .SCALE_LANES(SCALE_LANES),
        .Q_TO_U8_MULT(Q_TO_U8_MULT),
        .Q_TO_U8_SHIFT(Q_TO_U8_SHIFT)
    ) u_axis (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tlast(m_axis_tlast)
    );
endmodule
