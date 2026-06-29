// DMA-facing AXI4-Stream wrapper for the W8A12 32x32 tile path.
//
// AXI DMA owns DDR movement.  This wrapper keeps the W8A12 datapath as a
// plain AXI4-Stream transform: one XRGB888 LR pixel word in, one XRGB888 SR
// pixel word out.
module sr_dma_axis_w8a12_tile_wrapper #(
    parameter integer AXIS_DATA_W = 32,
    parameter integer PIXEL_DATA_W = 24,
    parameter integer IMG_W = 32,
    parameter integer IMG_H = 32,
    parameter integer SCALE = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 1,
    parameter integer TAP_LANES = 4,
    parameter integer SCALE_LANES = 1,
    parameter integer Q_TO_U8_MULT = 140277620,
    parameter integer Q_TO_U8_SHIFT = 30,
    parameter integer KEEP_W = AXIS_DATA_W / 8
) (
    input  wire                   aclk,
    input  wire                   aresetn,

    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire [AXIS_DATA_W-1:0] s_axis_tdata,
    input  wire [KEEP_W-1:0]      s_axis_tkeep,
    input  wire                   s_axis_tuser,
    input  wire                   s_axis_tlast,

    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire [AXIS_DATA_W-1:0] m_axis_tdata,
    output wire [KEEP_W-1:0]      m_axis_tkeep,
    output wire                   m_axis_tuser,
    output wire                   m_axis_tlast
);

    wire [PIXEL_DATA_W-1:0] core_s_tdata = s_axis_tdata[PIXEL_DATA_W-1:0];
    wire [PIXEL_DATA_W-1:0] core_m_tdata;

    span_w8a12_full_streamed_rgb_axis #(
        .DATA_W(PIXEL_DATA_W),
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
    ) u_w8a12_axis (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata(core_s_tdata),
        .s_axis_tuser(s_axis_tuser),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(core_m_tdata),
        .m_axis_tuser(m_axis_tuser),
        .m_axis_tlast(m_axis_tlast)
    );

    assign m_axis_tdata = {{(AXIS_DATA_W-PIXEL_DATA_W){1'b0}}, core_m_tdata};
    assign m_axis_tkeep = {KEEP_W{1'b1}};

    wire unused_s_keep = |s_axis_tkeep;

endmodule
