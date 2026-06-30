`timescale 1ns/1ps

// Performance-only scheduler for the next W8A12 frame-engine route.
//
// This module does not compute pixels. It makes the packed 2-D convolution
// schedule explicit so xsim can gate the 720p FPS target with the same layer
// shapes used by the REDS SPAN x4/F48 W8A12 manifest.
module w8a12_packed2d_perf_scheduler #(
    parameter integer FRAME_W = 320,
    parameter integer FRAME_H = 180,
    parameter integer OUT_LANES = 24,
    parameter integer TAP_LANES = 64,
    parameter integer TAIL_OUT_CHANNELS = 48,
    parameter integer CLOCK_MHZ_X1000 = 250000,
    parameter integer PACKED_MACS_PER_DSP = 2,
    parameter integer REQUANT_DSP_PER_OUT_LANE = 1,
    parameter integer REQUANT_PIPELINE_CYCLES = 0
) (
    input  wire clk,
    input  wire rst,
    input  wire start,
    output reg  busy,
    output reg  done,
    output reg  target15_pass,
    output reg  target20_pass,
    output reg  target30_pass,
    output reg  [31:0] output_lanes_o,
    output reg  [31:0] tap_lanes_o,
    output reg  [31:0] est_dsp_o,
    output reg  [31:0] cycles_per_lr_pixel_o,
    output reg  [31:0] frame_pixels_o,
    output reg  [63:0] frame_cycles_o,
    output reg  [63:0] fps_x1000_o
);
    function integer ceil_div;
        input integer num;
        input integer den;
        begin
            ceil_div = (num + den - 1) / den;
        end
    endfunction

    function integer layer_taps;
        input integer idx;
        begin
            if (idx == 0)
                layer_taps = 27;      // conv_1: 3 input channels * 3x3
            else if (idx == 20)
                layer_taps = 192;     // conv_cat: 192 input channels * 1x1
            else
                layer_taps = 432;     // all 48-channel 3x3 convolutions
        end
    endfunction

    function integer layer_out_channels;
        input integer idx;
        begin
            if (idx == 21)
                layer_out_channels = TAIL_OUT_CHANNELS;
            else
                layer_out_channels = 48;
        end
    endfunction

    function integer calc_cycles_per_lr_pixel;
        input integer unused;
        integer idx;
        integer out_groups;
        integer tap_groups;
        begin
            calc_cycles_per_lr_pixel = 0;
            for (idx = 0; idx < 22; idx = idx + 1) begin
                out_groups = ceil_div(layer_out_channels(idx), OUT_LANES);
                tap_groups = ceil_div(layer_taps(idx), TAP_LANES);
                calc_cycles_per_lr_pixel =
                    calc_cycles_per_lr_pixel +
                    out_groups * tap_groups +
                    out_groups * REQUANT_PIPELINE_CYCLES;
            end
        end
    endfunction

    localparam integer FRAME_PIXELS = FRAME_W * FRAME_H;
    localparam integer CYCLES_PER_LR_PIXEL = calc_cycles_per_lr_pixel(0);
    localparam [63:0] FRAME_CYCLES = FRAME_PIXELS * CYCLES_PER_LR_PIXEL;
    localparam [63:0] CLOCK_MHZ_X1000_U64 = CLOCK_MHZ_X1000;
    localparam [63:0] FPS_X1000 =
        (FRAME_CYCLES == 0) ? 64'd0 : ((CLOCK_MHZ_X1000_U64 * 64'd1000000) / FRAME_CYCLES);
    localparam integer EST_PACKED_MAC_DSP =
        ceil_div(OUT_LANES * TAP_LANES, PACKED_MACS_PER_DSP);
    localparam integer EST_DSP =
        EST_PACKED_MAC_DSP + OUT_LANES * REQUANT_DSP_PER_OUT_LANE;

    always @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0;
            done <= 1'b0;
            target15_pass <= 1'b0;
            target20_pass <= 1'b0;
            target30_pass <= 1'b0;
            output_lanes_o <= 32'd0;
            tap_lanes_o <= 32'd0;
            est_dsp_o <= 32'd0;
            cycles_per_lr_pixel_o <= 32'd0;
            frame_pixels_o <= 32'd0;
            frame_cycles_o <= 64'd0;
            fps_x1000_o <= 64'd0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                busy <= 1'b1;
            end else if (busy) begin
                busy <= 1'b0;
                done <= 1'b1;
                target15_pass <= (FPS_X1000 >= 64'd15000);
                target20_pass <= (FPS_X1000 >= 64'd20000);
                target30_pass <= (FPS_X1000 >= 64'd30000);
                output_lanes_o <= OUT_LANES;
                tap_lanes_o <= TAP_LANES;
                est_dsp_o <= EST_DSP;
                cycles_per_lr_pixel_o <= CYCLES_PER_LR_PIXEL;
                frame_pixels_o <= FRAME_PIXELS;
                frame_cycles_o <= FRAME_CYCLES;
                fps_x1000_o <= FPS_X1000;
            end
        end
    end
endmodule
