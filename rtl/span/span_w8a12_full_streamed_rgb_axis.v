`timescale 1ns/1ps

// AXI-stream style wrapper for the REDS W8A12 full streamed SPAN core.
// The internal core produces signed W8A12 PixelShuffle q values; this wrapper
// converts them to RGB888 bytes for the existing JTAG/AXI-Lite endpoint.
(* keep_hierarchy = "yes" *)
module span_w8a12_full_streamed_rgb_axis #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 4,
    parameter integer IMG_H = 4,
    parameter integer ACT_W = 12,
    parameter integer ACC_W = 48,
    parameter integer CH = 48,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer SCALE_LANES = 2,
    // round(pixelshuffle.output_scale * 255 * 2^30), exported from the
    // active REDS W8A12 quantization plan.
    parameter integer Q_TO_U8_MULT = 140277620,
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
    wire rst = !aresetn;
    wire signed [3*ACT_W-1:0] rgb_q;

    function [7:0] q_to_u8;
        input signed [ACT_W-1:0] q;
        reg signed [63:0] product;
        reg signed [63:0] rounded;
        begin
            if (q <= 0) begin
                q_to_u8 = 8'd0;
            end else begin
                product = q * Q_TO_U8_MULT;
                rounded = (product + (64'sd1 <<< (Q_TO_U8_SHIFT - 1))) >>> Q_TO_U8_SHIFT;
                if (rounded <= 0)
                    q_to_u8 = 8'd0;
                else if (rounded >= 255)
                    q_to_u8 = 8'd255;
                else
                    q_to_u8 = rounded[7:0];
            end
        end
    endfunction

    span_w8a12_full_streamed_rgb #(
        .DATA_W(DATA_W),
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .CH(CH),
        .OUT_LANES(OUT_LANES),
        .TAP_LANES(TAP_LANES),
        .SCALE_LANES(SCALE_LANES)
    ) u_core (
        .clk(aclk),
        .rst(rst),
        .s_valid(s_axis_tvalid),
        .s_ready(s_axis_tready),
        .s_data(s_axis_tdata),
        .s_user(s_axis_tuser),
        .s_last(s_axis_tlast),
        .m_valid(m_axis_tvalid),
        .m_ready(m_axis_tready),
        .m_rgb(rgb_q),
        .m_user(m_axis_tuser),
        .m_last(m_axis_tlast)
    );

    assign m_axis_tdata = {
        q_to_u8($signed(rgb_q[0*ACT_W +: ACT_W])),
        q_to_u8($signed(rgb_q[1*ACT_W +: ACT_W])),
        q_to_u8($signed(rgb_q[2*ACT_W +: ACT_W]))
    };
endmodule
