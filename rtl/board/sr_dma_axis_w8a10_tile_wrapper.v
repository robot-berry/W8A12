// DMA-facing AXI4-Stream wrapper for the W8A10 32x32 tile path.
//
// This module is intentionally thin: AXI DMA owns DDR movement, while the
// W8A10 core owns pixel processing. AXI-Lite control/status should be added
// around this wrapper in the board-level BD or a later control shell.
module sr_dma_axis_w8a10_tile_wrapper #(
    parameter integer AXIS_DATA_W = 32,
    parameter integer PIXEL_DATA_W = 24,
    parameter integer IMG_W = 32,
    parameter integer IMG_H = 32,
    parameter integer SCALE = 4,
    parameter integer KEEP_W = AXIS_DATA_W / 8
) (
    input  wire                  aclk,
    input  wire                  aresetn,

    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire [AXIS_DATA_W-1:0] s_axis_tdata,
    input  wire [KEEP_W-1:0]     s_axis_tkeep,
    input  wire                  s_axis_tuser,
    input  wire                  s_axis_tlast,

    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready,
    output wire [AXIS_DATA_W-1:0] m_axis_tdata,
    output wire [KEEP_W-1:0]     m_axis_tkeep,
    output wire                  m_axis_tuser,
    output wire                  m_axis_tlast
);

    wire [PIXEL_DATA_W-1:0] core_s_tdata = s_axis_tdata[PIXEL_DATA_W-1:0];
    wire [PIXEL_DATA_W-1:0] core_m_tdata;

    span_w8a10_full_streamed_rgb_axis #(
        .DATA_W(PIXEL_DATA_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .SCALE(SCALE)
    ) u_w8a10_axis (
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
