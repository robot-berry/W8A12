`timescale 1ns/1ps

module tb_w8a12_packed2d_x2_720p20_perf_scheduler;
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic start_resource;
    logic start_margin;
    logic start_unbounded;

    wire busy_resource;
    wire done_resource;
    wire pass15_resource;
    wire pass20_resource;
    wire pass30_resource;
    wire [31:0] output_lanes_resource;
    wire [31:0] tap_lanes_resource;
    wire [31:0] est_dsp_resource;
    wire [31:0] cpp_resource;
    wire [31:0] frame_pixels_resource;
    wire [63:0] frame_cycles_resource;
    wire [63:0] fps_x1000_resource;

    wire busy_margin;
    wire done_margin;
    wire pass15_margin;
    wire pass20_margin;
    wire pass30_margin;
    wire [31:0] output_lanes_margin;
    wire [31:0] tap_lanes_margin;
    wire [31:0] est_dsp_margin;
    wire [31:0] cpp_margin;
    wire [31:0] frame_pixels_margin;
    wire [63:0] frame_cycles_margin;
    wire [63:0] fps_x1000_margin;

    wire busy_unbounded;
    wire done_unbounded;
    wire pass15_unbounded;
    wire pass20_unbounded;
    wire pass30_unbounded;
    wire [31:0] output_lanes_unbounded;
    wire [31:0] tap_lanes_unbounded;
    wire [31:0] est_dsp_unbounded;
    wire [31:0] cpp_unbounded;
    wire [31:0] frame_pixels_unbounded;
    wire [63:0] frame_cycles_unbounded;
    wire [63:0] fps_x1000_unbounded;

    always #2 clk = ~clk;

    w8a12_packed2d_perf_scheduler #(
        .FRAME_W(640),
        .FRAME_H(360),
        .OUT_LANES(24),
        .TAP_LANES(64),
        .TAIL_OUT_CHANNELS(12),
        .CLOCK_MHZ_X1000(250000)
    ) dut_resource_24x64 (
        .clk(clk),
        .rst(rst),
        .start(start_resource),
        .busy(busy_resource),
        .done(done_resource),
        .target15_pass(pass15_resource),
        .target20_pass(pass20_resource),
        .target30_pass(pass30_resource),
        .output_lanes_o(output_lanes_resource),
        .tap_lanes_o(tap_lanes_resource),
        .est_dsp_o(est_dsp_resource),
        .cycles_per_lr_pixel_o(cpp_resource),
        .frame_pixels_o(frame_pixels_resource),
        .frame_cycles_o(frame_cycles_resource),
        .fps_x1000_o(fps_x1000_resource)
    );

    w8a12_packed2d_perf_scheduler #(
        .FRAME_W(640),
        .FRAME_H(360),
        .OUT_LANES(24),
        .TAP_LANES(72),
        .TAIL_OUT_CHANNELS(12),
        .CLOCK_MHZ_X1000(250000)
    ) dut_margin_24x72 (
        .clk(clk),
        .rst(rst),
        .start(start_margin),
        .busy(busy_margin),
        .done(done_margin),
        .target15_pass(pass15_margin),
        .target20_pass(pass20_margin),
        .target30_pass(pass30_margin),
        .output_lanes_o(output_lanes_margin),
        .tap_lanes_o(tap_lanes_margin),
        .est_dsp_o(est_dsp_margin),
        .cycles_per_lr_pixel_o(cpp_margin),
        .frame_pixels_o(frame_pixels_margin),
        .frame_cycles_o(frame_cycles_margin),
        .fps_x1000_o(fps_x1000_margin)
    );

    w8a12_packed2d_perf_scheduler #(
        .FRAME_W(640),
        .FRAME_H(360),
        .OUT_LANES(48),
        .TAP_LANES(144),
        .TAIL_OUT_CHANNELS(12),
        .CLOCK_MHZ_X1000(250000)
    ) dut_unbounded_48x144 (
        .clk(clk),
        .rst(rst),
        .start(start_unbounded),
        .busy(busy_unbounded),
        .done(done_unbounded),
        .target15_pass(pass15_unbounded),
        .target20_pass(pass20_unbounded),
        .target30_pass(pass30_unbounded),
        .output_lanes_o(output_lanes_unbounded),
        .tap_lanes_o(tap_lanes_unbounded),
        .est_dsp_o(est_dsp_unbounded),
        .cycles_per_lr_pixel_o(cpp_unbounded),
        .frame_pixels_o(frame_pixels_unbounded),
        .frame_cycles_o(frame_cycles_unbounded),
        .fps_x1000_o(fps_x1000_unbounded)
    );

    initial begin
        start_resource = 1'b0;
        start_margin = 1'b0;
        start_unbounded = 1'b0;
        repeat (5) @(posedge clk);
        rst = 1'b0;

        @(negedge clk);
        start_resource = 1'b1;
        start_margin = 1'b1;
        start_unbounded = 1'b1;
        @(negedge clk);
        start_resource = 1'b0;
        start_margin = 1'b0;
        start_unbounded = 1'b0;

        wait (done_resource && done_margin && done_unbounded);
        @(posedge clk);

        if (est_dsp_resource != 792)
            $fatal(1, "FAIL 24x64 est_dsp=%0d expected=792", est_dsp_resource);
        if (cpp_resource != 281)
            $fatal(1, "FAIL 24x64 cycles_per_lr_pixel=%0d expected=281", cpp_resource);
        if (frame_pixels_resource != 230400)
            $fatal(1, "FAIL 24x64 frame_pixels=%0d expected=230400", frame_pixels_resource);
        if (frame_cycles_resource != 64'd64742400)
            $fatal(1, "FAIL 24x64 frame_cycles=%0d expected=64742400", frame_cycles_resource);
        if (pass20_resource)
            $fatal(1, "FAIL 24x64 unexpectedly passed 20fps");

        if (est_dsp_margin != 888)
            $fatal(1, "FAIL 24x72 est_dsp=%0d expected=888", est_dsp_margin);
        if (cpp_margin != 242)
            $fatal(1, "FAIL 24x72 cycles_per_lr_pixel=%0d expected=242", cpp_margin);
        if (frame_pixels_margin != 230400)
            $fatal(1, "FAIL 24x72 frame_pixels=%0d expected=230400", frame_pixels_margin);
        if (frame_cycles_margin != 64'd55756800)
            $fatal(1, "FAIL 24x72 frame_cycles=%0d expected=55756800", frame_cycles_margin);
        if (pass20_margin)
            $fatal(1, "FAIL 24x72 unexpectedly passed 20fps");

        if (est_dsp_unbounded != 3504)
            $fatal(1, "FAIL 48x144 est_dsp=%0d expected=3504", est_dsp_unbounded);
        if (cpp_unbounded != 63)
            $fatal(1, "FAIL 48x144 cycles_per_lr_pixel=%0d expected=63", cpp_unbounded);
        if (frame_pixels_unbounded != 230400)
            $fatal(1, "FAIL 48x144 frame_pixels=%0d expected=230400", frame_pixels_unbounded);
        if (frame_cycles_unbounded != 64'd14515200)
            $fatal(1, "FAIL 48x144 frame_cycles=%0d expected=14515200", frame_cycles_unbounded);
        if (pass20_unbounded)
            $fatal(1, "FAIL 48x144 unexpectedly passed 20fps at 250MHz");

        $display("PASS w8a12_packed2d_x2_720p20_perf_scheduler candidate=24x64 output_lanes=%0d tap_lanes=%0d est_dsp=%0d cycles_per_lr_pixel=%0d frame_pixels=%0d frame_cycles=%0d fps_x1000=%0d pass15=%0d pass20=%0d pass30=%0d resource_gate=%0d",
                 output_lanes_resource, tap_lanes_resource, est_dsp_resource, cpp_resource,
                 frame_pixels_resource, frame_cycles_resource, fps_x1000_resource,
                 pass15_resource, pass20_resource, pass30_resource, est_dsp_resource <= 900);
        $display("PASS w8a12_packed2d_x2_720p20_perf_scheduler candidate=24x72 output_lanes=%0d tap_lanes=%0d est_dsp=%0d cycles_per_lr_pixel=%0d frame_pixels=%0d frame_cycles=%0d fps_x1000=%0d pass15=%0d pass20=%0d pass30=%0d resource_gate=%0d",
                 output_lanes_margin, tap_lanes_margin, est_dsp_margin, cpp_margin,
                 frame_pixels_margin, frame_cycles_margin, fps_x1000_margin,
                 pass15_margin, pass20_margin, pass30_margin, est_dsp_margin <= 900);
        $display("PASS w8a12_packed2d_x2_720p20_perf_scheduler candidate=48x144 output_lanes=%0d tap_lanes=%0d est_dsp=%0d cycles_per_lr_pixel=%0d frame_pixels=%0d frame_cycles=%0d fps_x1000=%0d pass15=%0d pass20=%0d pass30=%0d resource_gate=%0d",
                 output_lanes_unbounded, tap_lanes_unbounded, est_dsp_unbounded, cpp_unbounded,
                 frame_pixels_unbounded, frame_cycles_unbounded, fps_x1000_unbounded,
                 pass15_unbounded, pass20_unbounded, pass30_unbounded, est_dsp_unbounded <= 900);
        $finish;
    end
endmodule
