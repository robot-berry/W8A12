`timescale 1ns/1ps

// Streaming W8A10 tap MAC primitive for the 32x32/720p30 route.
//
// This block intentionally does not retain a full TAP_LANES activation vector,
// an OUT_LANES x TAP_LANES weight group, or a resident accumulator group. A
// higher-level scheduler reads the current activation tap, weight vector, and
// accumulator vector from banks, then writes the returned accumulator vector
// back to those banks. That keeps the packed 2-MAC/DSP arithmetic while moving
// large state out of replicated MAC tiles.
module span_w8a10_packed_tap_mac_stream #(
    parameter integer LANES = 16,
    parameter integer ACC_W = 48,
    parameter integer CONTEXT_W = 8,
    parameter integer PIPELINE = 2
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire [CONTEXT_W-1:0]         s_context_i,
    input  wire                         s_tap_last_i,
    input  wire signed [9:0]            act_i,
    input  wire [LANES*8-1:0]           weights_i,
    input  wire [LANES*ACC_W-1:0]       acc_i,

    output wire                         m_valid,
    input  wire                         m_ready,
    output wire [CONTEXT_W-1:0]         m_context_o,
    output wire                         m_tap_last_o,
    output wire [LANES*ACC_W-1:0]       acc_o
);
    initial begin
        if (LANES < 2 || (LANES % 2) != 0) begin
            $error("LANES must be an even integer >= 2");
        end
        if (CONTEXT_W < 1) begin
            $error("CONTEXT_W must be >= 1");
        end
    end

    wire vector_s_ready;
    wire vector_m_valid;

    span_w8a10_packed_vector_mac #(
        .LANES(LANES),
        .ACC_W(ACC_W),
        .PIPELINE(PIPELINE)
    ) u_vector_mac (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(vector_s_ready),
        .act_i(act_i),
        .weights_i(weights_i),
        .acc_i(acc_i),
        .m_valid(vector_m_valid),
        .m_ready(m_ready),
        .acc_o(acc_o)
    );

    assign s_ready = vector_s_ready;
    assign m_valid = vector_m_valid;

    generate
        if (PIPELINE == 0) begin : g_tag_comb
            assign m_context_o = s_context_i;
            assign m_tap_last_o = s_tap_last_i;
        end else if (PIPELINE == 1) begin : g_tag_pipe1
            reg [CONTEXT_W-1:0] context_q;
            reg tap_last_q;

            assign m_context_o = context_q;
            assign m_tap_last_o = tap_last_q;

            always @(posedge clk) begin
                if (rst) begin
                    context_q <= {CONTEXT_W{1'b0}};
                    tap_last_q <= 1'b0;
                end else if (vector_s_ready) begin
                    if (s_valid) begin
                        context_q <= s_context_i;
                        tap_last_q <= s_tap_last_i;
                    end
                end
            end
        end else begin : g_tag_pipe2
            reg tag_valid_s1_q;
            reg tag_valid_s2_q;
            reg [CONTEXT_W-1:0] context_s1_q;
            reg [CONTEXT_W-1:0] context_s2_q;
            reg tap_last_s1_q;
            reg tap_last_s2_q;

            wire stage2_ready = !tag_valid_s2_q || m_ready;
            wire stage1_ready = !tag_valid_s1_q || stage2_ready;

            assign m_context_o = context_s2_q;
            assign m_tap_last_o = tap_last_s2_q;

            always @(posedge clk) begin
                if (rst) begin
                    tag_valid_s1_q <= 1'b0;
                    tag_valid_s2_q <= 1'b0;
                    context_s1_q <= {CONTEXT_W{1'b0}};
                    context_s2_q <= {CONTEXT_W{1'b0}};
                    tap_last_s1_q <= 1'b0;
                    tap_last_s2_q <= 1'b0;
                end else begin
                    if (stage2_ready) begin
                        tag_valid_s2_q <= tag_valid_s1_q;
                        context_s2_q <= context_s1_q;
                        tap_last_s2_q <= tap_last_s1_q;
                    end

                    if (stage1_ready) begin
                        tag_valid_s1_q <= s_valid;
                        if (s_valid) begin
                            context_s1_q <= s_context_i;
                            tap_last_s1_q <= s_tap_last_i;
                        end
                    end
                end
            end
        end
    endgenerate
endmodule
