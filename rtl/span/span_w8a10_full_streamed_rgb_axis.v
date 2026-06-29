`timescale 1ns/1ps

// W8A10 board-path AXIS candidate shell.
//
// This module intentionally is not the final W8A10 SPAN compute core. It gives
// the W8A10 route a full-frame AXIS/JTAG integration target so bitstream,
// transfer, frame-cycle, and board-output plumbing can be tested while the
// realtime W8A10 compute array is still being reduced to a timing-clean form.
//
// Current image operation is still RGB888 nearest-neighbor x4, but the frame
// now passes through a real W8A10 streamed local-bank scheduler lifecycle:
// capture -> clear accumulator contexts -> run compute issue slots -> output.
// Board acceptance must not be claimed from this shell; image values are not
// produced by the W8A10 network yet.
module span_w8a10_full_streamed_rgb_axis #(
    parameter integer DATA_W = 24,
    parameter integer IMG_W = 8,
    parameter integer IMG_H = 8,
    parameter integer SCALE = 4,
    parameter integer ENABLE_W8A10_SCHEDULER = 1,
    parameter integer SCHED_INSTANCE_COUNT = 8,
    parameter integer SCHED_LANES = 16,
    parameter integer SCHED_CONTEXTS = 3,
    parameter integer SCHED_CONTEXT_W = 8,
    parameter integer SCHED_TAP_COUNTER_W = 9,
    parameter integer SCHED_TAPS_PER_CONTEXT = 432,
    parameter integer SCHED_PIPELINE = 2,
    parameter integer COMPUTE_ISSUES = 1296
) (
    input  wire              aclk,
    input  wire              aresetn,

    input  wire              s_axis_tvalid,
    output wire              s_axis_tready,
    input  wire [DATA_W-1:0] s_axis_tdata,
    input  wire              s_axis_tuser,
    input  wire              s_axis_tlast,

    output reg               m_axis_tvalid,
    input  wire              m_axis_tready,
    output reg  [DATA_W-1:0] m_axis_tdata,
    output reg               m_axis_tuser,
    output reg               m_axis_tlast
);
    localparam integer IN_PIXELS = IMG_W * IMG_H;
    localparam integer OUT_W = IMG_W * SCALE;
    localparam integer OUT_H = IMG_H * SCALE;
    localparam integer OUT_PIXELS = OUT_W * OUT_H;
    localparam integer IN_ADDR_W = (IN_PIXELS <= 2) ? 1 : $clog2(IN_PIXELS);
    localparam integer OUT_ADDR_W = (OUT_PIXELS <= 2) ? 1 : $clog2(OUT_PIXELS);
    localparam integer COMPUTE_COUNTER_W = (COMPUTE_ISSUES <= 2) ? 1 : $clog2(COMPUTE_ISSUES + 1);
    localparam [COMPUTE_COUNTER_W-1:0] COMPUTE_ISSUES_W = COMPUTE_ISSUES[COMPUTE_COUNTER_W-1:0];

    localparam [3:0] ST_CAPTURE          = 4'd0;
    localparam [3:0] ST_CLEAR_START      = 4'd1;
    localparam [3:0] ST_CLEAR_WAIT       = 4'd2;
    localparam [3:0] ST_COMPUTE          = 4'd3;
    localparam [3:0] ST_COMPUTE_DRAIN    = 4'd4;
    localparam [3:0] ST_OUTPUT_PREFETCH0 = 4'd5;
    localparam [3:0] ST_OUTPUT_PREFETCH1 = 4'd6;
    localparam [3:0] ST_OUTPUT_PREFETCH2 = 4'd7;
    localparam [3:0] ST_OUTPUT           = 4'd8;
    localparam [OUT_ADDR_W-1:0] OUT_ADDR_ZERO = 0;
    localparam [OUT_ADDR_W-1:0] OUT_ADDR_ONE = 1;
    localparam [OUT_ADDR_W-1:0] OUT_ADDR_TWO = 2;

    reg [3:0] state;
    reg [IN_ADDR_W-1:0] in_idx;
    reg [OUT_ADDR_W-1:0] out_idx;
    reg [IN_ADDR_W-1:0] frame_raddr_q;
    reg scheduler_clear_q;
    reg scheduler_enable_q;
    reg [COMPUTE_COUNTER_W-1:0] compute_issue_q;

    wire rst = !aresetn;
    wire output_fire = m_axis_tvalid && m_axis_tready;
    wire scheduler_clear_done_w;
    wire scheduler_active_w;
    wire [31:0] scheduler_status_w;
    wire scheduler_enabled_w = (ENABLE_W8A10_SCHEDULER != 0);

    assign s_axis_tready = (state == ST_CAPTURE);

    wire capture_fire = s_axis_tvalid && s_axis_tready;
    wire [IN_ADDR_W-1:0] frame_waddr_w =
        s_axis_tuser ? {IN_ADDR_W{1'b0}} : in_idx;
    wire signed [DATA_W-1:0] frame_rdata_s;
    wire [DATA_W-1:0] frame_rdata_w = frame_rdata_s[DATA_W-1:0];

    span_sync_ram_1r1w #(
        .DATA_W(DATA_W),
        .DEPTH(IN_PIXELS),
        .ADDR_W(IN_ADDR_W)
    ) u_frame_ram (
        .clk(aclk),
        .we(capture_fire),
        .waddr(frame_waddr_w),
        .wdata(s_axis_tdata),
        .raddr(frame_raddr_q),
        .rdata(frame_rdata_s)
    );

    generate
        if (ENABLE_W8A10_SCHEDULER != 0) begin : g_w8a10_scheduler
            span_w8a10_streamed_bank_scheduler_local_ooc #(
                .INSTANCE_COUNT(SCHED_INSTANCE_COUNT),
                .LANES(SCHED_LANES),
                .CONTEXTS(SCHED_CONTEXTS),
                .CONTEXT_W(SCHED_CONTEXT_W),
                .TAP_COUNTER_W(SCHED_TAP_COUNTER_W),
                .TAPS_PER_CONTEXT(SCHED_TAPS_PER_CONTEXT),
                .PIPELINE(SCHED_PIPELINE)
            ) u_scheduler (
                .clk(aclk),
                .rst(rst),
                .clear_i(scheduler_clear_q),
                .enable_i(scheduler_enable_q),
                .clear_busy_o(),
                .clear_done_o(scheduler_clear_done_w),
                .active_o(scheduler_active_w),
                .status_o(scheduler_status_w)
            );
        end else begin : g_no_w8a10_scheduler
            assign scheduler_clear_done_w = 1'b1;
            assign scheduler_active_w = 1'b0;
            assign scheduler_status_w = 32'h00000000;
        end
    endgenerate

    function automatic [IN_ADDR_W-1:0] output_to_input_addr;
        input [OUT_ADDR_W-1:0] out_linear;
        integer ox;
        integer oy;
        integer sx;
        integer sy;
        begin
            ox = out_linear % OUT_W;
            oy = out_linear / OUT_W;
            sx = ox / SCALE;
            sy = oy / SCALE;
            output_to_input_addr = sy * IMG_W + sx;
        end
    endfunction

    always @(posedge aclk) begin
        if (rst) begin
            state <= ST_CAPTURE;
            in_idx <= {IN_ADDR_W{1'b0}};
            out_idx <= {OUT_ADDR_W{1'b0}};
            frame_raddr_q <= {IN_ADDR_W{1'b0}};
            scheduler_clear_q <= 1'b0;
            scheduler_enable_q <= 1'b0;
            compute_issue_q <= {COMPUTE_COUNTER_W{1'b0}};
            m_axis_tvalid <= 1'b0;
            m_axis_tdata <= {DATA_W{1'b0}};
            m_axis_tuser <= 1'b0;
            m_axis_tlast <= 1'b0;
        end else begin
            scheduler_clear_q <= 1'b0;
            scheduler_enable_q <= 1'b0;

            case (state)
                ST_CAPTURE: begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tuser <= 1'b0;
                    m_axis_tlast <= 1'b0;

                    if (capture_fire) begin
                        if (s_axis_tuser)
                            in_idx <= {IN_ADDR_W{1'b0}};

                        if (frame_waddr_w == IN_PIXELS - 1) begin
                            out_idx <= {OUT_ADDR_W{1'b0}};
                            compute_issue_q <= {COMPUTE_COUNTER_W{1'b0}};
                            if (scheduler_enabled_w) begin
                                state <= ST_CLEAR_START;
                            end else begin
                                state <= ST_OUTPUT_PREFETCH0;
                            end
                        end else begin
                            in_idx <= frame_waddr_w + 1'b1;
                        end
                    end
                end

                ST_CLEAR_START: begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tuser <= 1'b0;
                    m_axis_tlast <= 1'b0;
                    scheduler_clear_q <= 1'b1;
                    state <= ST_CLEAR_WAIT;
                end

                ST_CLEAR_WAIT: begin
                    if (scheduler_clear_done_w) begin
                        compute_issue_q <= {COMPUTE_COUNTER_W{1'b0}};
                        state <= ST_COMPUTE;
                    end
                end

                ST_COMPUTE: begin
                    if (COMPUTE_ISSUES == 0) begin
                        state <= ST_COMPUTE_DRAIN;
                    end else if (compute_issue_q < COMPUTE_ISSUES_W) begin
                        scheduler_enable_q <= 1'b1;
                        compute_issue_q <= compute_issue_q + 1'b1;
                    end else begin
                        state <= ST_COMPUTE_DRAIN;
                    end
                end

                ST_COMPUTE_DRAIN: begin
                    if (!scheduler_active_w) begin
                        state <= ST_OUTPUT_PREFETCH0;
                    end
                end

                ST_OUTPUT_PREFETCH0: begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tuser <= 1'b0;
                    m_axis_tlast <= 1'b0;
                    out_idx <= {OUT_ADDR_W{1'b0}};
                    frame_raddr_q <= output_to_input_addr(OUT_ADDR_ZERO);
                    state <= ST_OUTPUT_PREFETCH1;
                end

                ST_OUTPUT_PREFETCH1: begin
                    if (OUT_PIXELS > 1) begin
                        frame_raddr_q <= output_to_input_addr(OUT_ADDR_ONE);
                    end else begin
                        frame_raddr_q <= output_to_input_addr(OUT_ADDR_ZERO);
                    end
                    state <= ST_OUTPUT_PREFETCH2;
                end

                ST_OUTPUT_PREFETCH2: begin
                    m_axis_tvalid <= 1'b1;
                    m_axis_tdata <= frame_rdata_w;
                    m_axis_tuser <= 1'b1;
                    m_axis_tlast <= (OUT_PIXELS == 1);
                    if (OUT_PIXELS > 2) begin
                        frame_raddr_q <= output_to_input_addr(OUT_ADDR_TWO);
                    end
                    state <= ST_OUTPUT;
                end

                ST_OUTPUT: begin
                    if (output_fire) begin
                        if (out_idx == OUT_PIXELS - 1) begin
                            m_axis_tvalid <= 1'b0;
                            m_axis_tuser <= 1'b0;
                            m_axis_tlast <= 1'b0;
                            in_idx <= {IN_ADDR_W{1'b0}};
                            state <= ST_CAPTURE;
                        end else begin
                            out_idx <= out_idx + 1'b1;
                            m_axis_tdata <= frame_rdata_w;
                            m_axis_tuser <= 1'b0;
                            m_axis_tlast <= ((out_idx + 1'b1) == OUT_PIXELS - 1);
                            if ((out_idx + 3) < OUT_PIXELS) begin
                                frame_raddr_q <= output_to_input_addr(out_idx + 3);
                            end
                        end
                    end
                end

                default: state <= ST_CAPTURE;
            endcase
        end
    end

    wire unused_input_flags = s_axis_tlast;
    wire [31:0] unused_scheduler_status = scheduler_status_w;
endmodule
