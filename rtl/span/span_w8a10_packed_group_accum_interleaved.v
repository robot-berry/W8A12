`timescale 1ns/1ps

// Multi-context W8A10 tap-group accumulator prototype.
//
// A pipelined packed vector MAC cannot consume the next tap of the same
// accumulator context until the prior result returns. This prototype keeps
// several independent contexts resident and round-robins ready contexts so a
// PIPELINE=2 MAC can still be issued close to once per cycle.
module span_w8a10_packed_group_accum_interleaved #(
    parameter integer OUT_LANES = 16,
    parameter integer TAP_LANES = 16,
    parameter integer ACC_W = 48,
    parameter integer CONTEXTS = 3,
    parameter integer PIPELINE = 2
) (
    input  wire                                  clk,
    input  wire                                  rst,

    input  wire                                  s_valid,
    output wire                                  s_ready,
    input  wire signed [TAP_LANES*10-1:0]        act_i,
    input  wire signed [OUT_LANES*ACC_W-1:0]     acc_i,
    input  wire signed [OUT_LANES*TAP_LANES*8-1:0] weight_i,

    output reg                                   m_valid,
    input  wire                                  m_ready,
    output reg [$clog2(CONTEXTS)-1:0]            m_context_o,
    output reg signed [OUT_LANES*ACC_W-1:0]      acc_o
);
    localparam integer TAP_W = (TAP_LANES <= 2) ? 1 : $clog2(TAP_LANES);
    localparam integer CTX_W = (CONTEXTS <= 2) ? 1 : $clog2(CONTEXTS);

    initial begin
        if (OUT_LANES < 2 || (OUT_LANES % 2) != 0) begin
            $error("OUT_LANES must be an even integer >= 2");
        end
        if (TAP_LANES < 1) begin
            $error("TAP_LANES must be >= 1");
        end
        if (CONTEXTS < 2) begin
            $error("CONTEXTS must be >= 2");
        end
        if (PIPELINE < 1) begin
            $error("PIPELINE must be >= 1 for interleaved feedback tracking");
        end
    end

    reg active_q [0:CONTEXTS-1];
    reg pending_q [0:CONTEXTS-1];
    reg [TAP_W-1:0] tap_idx_q [0:CONTEXTS-1];
    reg signed [TAP_LANES*10-1:0] act_q [0:CONTEXTS-1];
    reg signed [OUT_LANES*TAP_LANES*8-1:0] weight_q [0:CONTEXTS-1];
    reg signed [OUT_LANES*ACC_W-1:0] acc_q [0:CONTEXTS-1];

    reg [CTX_W-1:0] rr_q;
    reg [CTX_W-1:0] accept_ctx;
    reg accept_found;
    reg [CTX_W-1:0] issue_ctx;
    reg issue_found;
    reg [CTX_W-1:0] scan_ctx;
    reg [CTX_W-1:0] ret_ctx_pipe [0:PIPELINE-1];
    reg ret_valid_pipe [0:PIPELINE-1];

    reg signed [9:0] vector_act;
    reg signed [OUT_LANES*8-1:0] vector_weight;
    wire vector_s_ready;
    wire vector_m_valid;
    wire signed [OUT_LANES*ACC_W-1:0] vector_acc_o;

    integer i;
    integer lane_idx;

    always @(*) begin
        accept_found = 1'b0;
        accept_ctx = {CTX_W{1'b0}};
        for (i = 0; i < CONTEXTS; i = i + 1) begin
            if (!accept_found && !active_q[i]) begin
                accept_found = 1'b1;
                accept_ctx = i[CTX_W-1:0];
            end
        end
    end

    always @(*) begin
        issue_found = 1'b0;
        issue_ctx = rr_q;
        for (i = 0; i < CONTEXTS; i = i + 1) begin
            scan_ctx = rr_q + i[CTX_W-1:0];
            if (scan_ctx >= CONTEXTS[CTX_W-1:0])
                scan_ctx = scan_ctx - CONTEXTS[CTX_W-1:0];
            if (!issue_found && active_q[scan_ctx] && !pending_q[scan_ctx]) begin
                issue_found = 1'b1;
                issue_ctx = scan_ctx;
            end
        end
    end

    always @(*) begin
        vector_act = act_q[issue_ctx][tap_idx_q[issue_ctx]*10 +: 10];
        vector_weight = {OUT_LANES*8{1'b0}};
        for (lane_idx = 0; lane_idx < OUT_LANES; lane_idx = lane_idx + 1) begin
            vector_weight[lane_idx*8 +: 8] =
                weight_q[issue_ctx][(lane_idx*TAP_LANES + tap_idx_q[issue_ctx])*8 +: 8];
        end
    end

    span_w8a10_packed_vector_mac #(
        .LANES(OUT_LANES),
        .ACC_W(ACC_W),
        .PIPELINE(PIPELINE)
    ) u_vector_mac (
        .clk(clk),
        .rst(rst),
        .s_valid(issue_found && vector_s_ready && (!m_valid || m_ready)),
        .s_ready(vector_s_ready),
        .act_i(vector_act),
        .weights_i(vector_weight),
        .acc_i(acc_q[issue_ctx]),
        .m_valid(vector_m_valid),
        .m_ready(1'b1),
        .acc_o(vector_acc_o)
    );

    assign s_ready = accept_found;

    always @(posedge clk) begin
        if (rst) begin
            rr_q <= {CTX_W{1'b0}};
            m_valid <= 1'b0;
            m_context_o <= {CTX_W{1'b0}};
            acc_o <= {OUT_LANES*ACC_W{1'b0}};
            for (i = 0; i < CONTEXTS; i = i + 1) begin
                active_q[i] <= 1'b0;
                pending_q[i] <= 1'b0;
                tap_idx_q[i] <= {TAP_W{1'b0}};
                act_q[i] <= {TAP_LANES*10{1'b0}};
                weight_q[i] <= {OUT_LANES*TAP_LANES*8{1'b0}};
                acc_q[i] <= {OUT_LANES*ACC_W{1'b0}};
            end
            for (i = 0; i < PIPELINE; i = i + 1) begin
                ret_ctx_pipe[i] <= {CTX_W{1'b0}};
                ret_valid_pipe[i] <= 1'b0;
            end
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            if (s_valid && s_ready) begin
                active_q[accept_ctx] <= 1'b1;
                pending_q[accept_ctx] <= 1'b0;
                tap_idx_q[accept_ctx] <= {TAP_W{1'b0}};
                act_q[accept_ctx] <= act_i;
                weight_q[accept_ctx] <= weight_i;
                acc_q[accept_ctx] <= acc_i;
            end

            ret_valid_pipe[0] <= issue_found && vector_s_ready && (!m_valid || m_ready);
            ret_ctx_pipe[0] <= issue_ctx;
            for (i = 1; i < PIPELINE; i = i + 1) begin
                ret_valid_pipe[i] <= ret_valid_pipe[i-1];
                ret_ctx_pipe[i] <= ret_ctx_pipe[i-1];
            end

            if (issue_found && vector_s_ready && (!m_valid || m_ready)) begin
                pending_q[issue_ctx] <= 1'b1;
                if (issue_ctx == CONTEXTS - 1)
                    rr_q <= {CTX_W{1'b0}};
                else
                    rr_q <= issue_ctx + 1'b1;
            end

            if (vector_m_valid && ret_valid_pipe[PIPELINE-1]) begin
                pending_q[ret_ctx_pipe[PIPELINE-1]] <= 1'b0;
                acc_q[ret_ctx_pipe[PIPELINE-1]] <= vector_acc_o;

                if (tap_idx_q[ret_ctx_pipe[PIPELINE-1]] == TAP_LANES - 1) begin
                    active_q[ret_ctx_pipe[PIPELINE-1]] <= 1'b0;
                    m_valid <= 1'b1;
                    m_context_o <= ret_ctx_pipe[PIPELINE-1];
                    acc_o <= vector_acc_o;
                end else begin
                    tap_idx_q[ret_ctx_pipe[PIPELINE-1]] <=
                        tap_idx_q[ret_ctx_pipe[PIPELINE-1]] + 1'b1;
                end
            end
        end
    end
endmodule
