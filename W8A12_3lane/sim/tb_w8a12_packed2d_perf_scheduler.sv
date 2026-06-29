`timescale 1ns/1ps

module tb_w8a12_packed2d_perf_scheduler;
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic start_min;
    logic start_margin;

    wire busy_min;
    wire done_min;
    wire pass15_min;
    wire pass20_min;
    wire pass30_min;
    wire [31:0] output_lanes_min;
    wire [31:0] tap_lanes_min;
    wire [31:0] est_dsp_min;
    wire [31:0] cpp_min;
    wire [31:0] frame_pixels_min;
    wire [63:0] frame_cycles_min;
    wire [63:0] fps_x1000_min;

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

    always #2 clk = ~clk;

    w8a12_packed2d_perf_scheduler #(
        .FRAME_W(320),
        .FRAME_H(180),
        .OUT_LANES(24),
        .TAP_LANES(64),
        .CLOCK_MHZ_X1000(250000)
    ) dut_min_resource (
        .clk(clk),
        .rst(rst),
        .start(start_min),
        .busy(busy_min),
        .done(done_min),
        .target15_pass(pass15_min),
        .target20_pass(pass20_min),
        .target30_pass(pass30_min),
        .output_lanes_o(output_lanes_min),
        .tap_lanes_o(tap_lanes_min),
        .est_dsp_o(est_dsp_min),
        .cycles_per_lr_pixel_o(cpp_min),
        .frame_pixels_o(frame_pixels_min),
        .frame_cycles_o(frame_cycles_min),
        .fps_x1000_o(fps_x1000_min)
    );

    w8a12_packed2d_perf_scheduler #(
        .FRAME_W(320),
        .FRAME_H(180),
        .OUT_LANES(24),
        .TAP_LANES(72),
        .CLOCK_MHZ_X1000(250000)
    ) dut_margin (
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

    initial begin
        start_min = 1'b0;
        start_margin = 1'b0;
        repeat (5) @(posedge clk);
        rst = 1'b0;

        @(negedge clk);
        start_min = 1'b1;
        start_margin = 1'b1;
        @(negedge clk);
        start_min = 1'b0;
        start_margin = 1'b0;

        wait (done_min && done_margin);
        @(posedge clk);

        if (output_lanes_min != 24 || tap_lanes_min != 64)
            $fatal(1, "FAIL min candidate lane echo mismatch");
        if (est_dsp_min != 792)
            $fatal(1, "FAIL min candidate est_dsp=%0d expected=792", est_dsp_min);
        if (cpp_min != 288)
            $fatal(1, "FAIL min candidate cycles_per_lr_pixel=%0d expected=288", cpp_min);
        if (frame_pixels_min != 57600)
            $fatal(1, "FAIL min candidate frame_pixels=%0d expected=57600", frame_pixels_min);
        if (frame_cycles_min != 64'd16588800)
            $fatal(1, "FAIL min candidate frame_cycles=%0d expected=16588800", frame_cycles_min);
        if (!pass15_min || pass20_min || pass30_min)
            $fatal(1, "FAIL min candidate fps gates pass15=%0d pass20=%0d pass30=%0d", pass15_min, pass20_min, pass30_min);

        if (output_lanes_margin != 24 || tap_lanes_margin != 72)
            $fatal(1, "FAIL margin candidate lane echo mismatch");
        if (est_dsp_margin != 888)
            $fatal(1, "FAIL margin candidate est_dsp=%0d expected=888", est_dsp_margin);
        if (cpp_margin != 248)
            $fatal(1, "FAIL margin candidate cycles_per_lr_pixel=%0d expected=248", cpp_margin);
        if (frame_pixels_margin != 57600)
            $fatal(1, "FAIL margin candidate frame_pixels=%0d expected=57600", frame_pixels_margin);
        if (frame_cycles_margin != 64'd14284800)
            $fatal(1, "FAIL margin candidate frame_cycles=%0d expected=14284800", frame_cycles_margin);
        if (!pass15_margin || pass20_margin || pass30_margin)
            $fatal(1, "FAIL margin candidate fps gates pass15=%0d pass20=%0d pass30=%0d", pass15_margin, pass20_margin, pass30_margin);

        $display("PASS w8a12_packed2d_perf_scheduler candidate=24x64 output_lanes=%0d tap_lanes=%0d est_dsp=%0d cycles_per_lr_pixel=%0d frame_pixels=%0d frame_cycles=%0d fps_x1000=%0d pass15=%0d pass20=%0d pass30=%0d",
                 output_lanes_min, tap_lanes_min, est_dsp_min, cpp_min, frame_pixels_min,
                 frame_cycles_min, fps_x1000_min, pass15_min, pass20_min, pass30_min);
        $display("PASS w8a12_packed2d_perf_scheduler candidate=24x72 output_lanes=%0d tap_lanes=%0d est_dsp=%0d cycles_per_lr_pixel=%0d frame_pixels=%0d frame_cycles=%0d fps_x1000=%0d pass15=%0d pass20=%0d pass30=%0d",
                 output_lanes_margin, tap_lanes_margin, est_dsp_margin, cpp_margin, frame_pixels_margin,
                 frame_cycles_margin, fps_x1000_margin, pass15_margin, pass20_margin, pass30_margin);
        $finish;
    end
endmodule
