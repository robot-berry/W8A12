`timescale 1ns/1ps

// Local-bank scheduler OOC probe for the streamed W8A10 path.
//
// This version avoids the global accumulator-bank mux from
// span_w8a10_streamed_bank_scheduler_ooc. Each replicated group owns a local
// CONTEXTS-deep accumulator/activation/weight bank, which is closer to the
// placement-friendly shape needed for a 192-group realtime array.
(* keep_hierarchy = "yes" *)
module span_w8a10_streamed_bank_scheduler_local_ooc #(
    parameter integer INSTANCE_COUNT = 8,
    parameter integer LANES = 16,
    parameter integer ACC_W = 48,
    parameter integer CONTEXTS = 3,
    parameter integer CONTEXT_W = 8,
    parameter integer TAP_COUNTER_W = 9,
    parameter integer TAPS_PER_CONTEXT = 432,
    parameter integer PIPELINE = 2
) (
    input  wire         clk,
    input  wire         rst,
    input  wire         clear_i,
    input  wire         enable_i,
    output wire         clear_busy_o,
    output wire         clear_done_o,
    output wire         active_o,
    output wire [31:0]  status_o
);
    localparam integer CONTEXT_IDX_W = (CONTEXTS <= 2) ? 1 : $clog2(CONTEXTS);
    localparam integer ACC_VEC_W = LANES * ACC_W;
    localparam integer WEIGHT_VEC_W = LANES * 8;

    initial begin
        if (INSTANCE_COUNT < 1) begin
            $error("INSTANCE_COUNT must be >= 1");
        end
        if (LANES < 2 || (LANES % 2) != 0) begin
            $error("LANES must be an even integer >= 2");
        end
        if (CONTEXTS < PIPELINE + 1) begin
            $error("CONTEXTS must be at least PIPELINE+1 to avoid read-after-write hazards");
        end
        if (CONTEXT_W < CONTEXT_IDX_W) begin
            $error("CONTEXT_W is too small for CONTEXTS");
        end
        if (TAPS_PER_CONTEXT < 1 || TAPS_PER_CONTEXT > (1 << TAP_COUNTER_W)) begin
            $error("TAPS_PER_CONTEXT does not fit TAP_COUNTER_W");
        end
    end

    wire [INSTANCE_COUNT-1:0] s_ready_w;
    wire [INSTANCE_COUNT-1:0] m_valid_w;
    wire [INSTANCE_COUNT*CONTEXT_W-1:0] m_context_w;
    wire [INSTANCE_COUNT-1:0] m_tap_last_w;
    wire [INSTANCE_COUNT*ACC_VEC_W-1:0] acc_o_w;

    reg clear_i_q;
    reg clear_active_q;
    reg clear_done_q;
    reg [CONTEXT_IDX_W-1:0] clear_context_q;
    reg [31:0] status_q;
    reg [31:0] status_mix;

    wire clear_start_w = clear_i && !clear_i_q;
    wire clear_block_issue_w = clear_start_w || clear_active_q;
    wire issue_valid_w = enable_i && !clear_block_issue_w;

    assign clear_busy_o = clear_active_q;
    assign clear_done_o = clear_done_q;
    assign active_o = clear_active_q | enable_i | (|m_valid_w);
    assign status_o = status_q;

    always @(posedge clk) begin
        if (rst) begin
            clear_i_q <= 1'b0;
            clear_active_q <= 1'b0;
            clear_done_q <= 1'b0;
            clear_context_q <= {CONTEXT_IDX_W{1'b0}};
        end else begin
            clear_i_q <= clear_i;
            clear_done_q <= 1'b0;

            if (clear_start_w) begin
                clear_active_q <= 1'b1;
                clear_context_q <= {CONTEXT_IDX_W{1'b0}};
            end else if (clear_active_q) begin
                if (clear_context_q == (CONTEXTS - 1)) begin
                    clear_active_q <= 1'b0;
                    clear_done_q <= 1'b1;
                    clear_context_q <= {CONTEXT_IDX_W{1'b0}};
                end else begin
                    clear_context_q <= clear_context_q + 1'b1;
                end
            end
        end
    end

    genvar inst;
    generate
        for (inst = 0; inst < INSTANCE_COUNT; inst = inst + 1) begin : g_sched
            reg [CONTEXT_IDX_W-1:0] issue_context_q;
            reg [TAP_COUNTER_W-1:0] tap_count_q [0:CONTEXTS-1];
            (* keep = "true" *) reg [ACC_VEC_W-1:0] acc_context_q [0:CONTEXTS-1];
            reg signed [9:0] act_bank_q [0:CONTEXTS-1];
            reg [WEIGHT_VEC_W-1:0] weight_bank_q [0:CONTEXTS-1];

            wire [CONTEXT_W-1:0] write_context_full_w =
                m_context_w[inst*CONTEXT_W +: CONTEXT_W];
            wire write_context_in_range_w = (write_context_full_w < CONTEXTS);
            wire [CONTEXT_IDX_W-1:0] write_context_w =
                write_context_full_w[CONTEXT_IDX_W-1:0];
            wire [CONTEXT_W-1:0] issue_context_w =
                {{(CONTEXT_W-CONTEXT_IDX_W){1'b0}}, issue_context_q};
            wire issue_tap_last_w =
                (tap_count_q[issue_context_q] == (TAPS_PER_CONTEXT - 1));

            reg acc_wr_en;
            reg [CONTEXT_IDX_W-1:0] acc_wr_context;
            reg [ACC_VEC_W-1:0] acc_wr_data;

            always @(*) begin
                acc_wr_en = 1'b0;
                acc_wr_context = {CONTEXT_IDX_W{1'b0}};
                acc_wr_data = {ACC_VEC_W{1'b0}};

                if (clear_active_q) begin
                    acc_wr_en = 1'b1;
                    acc_wr_context = clear_context_q;
                    acc_wr_data = {ACC_VEC_W{1'b0}};
                end else if (m_valid_w[inst] && write_context_in_range_w) begin
                    acc_wr_en = 1'b1;
                    acc_wr_context = write_context_w;
                    acc_wr_data = acc_o_w[inst*ACC_VEC_W +: ACC_VEC_W];
                end
            end

            (* dont_touch = "yes" *)
            span_w8a10_packed_tap_mac_stream #(
                .LANES(LANES),
                .ACC_W(ACC_W),
                .CONTEXT_W(CONTEXT_W),
                .PIPELINE(PIPELINE)
            ) u_tap_mac (
                .clk(clk),
                .rst(rst),
                .s_valid(issue_valid_w),
                .s_ready(s_ready_w[inst]),
                .s_context_i(issue_context_w),
                .s_tap_last_i(issue_tap_last_w),
                .act_i(act_bank_q[issue_context_q]),
                .weights_i(weight_bank_q[issue_context_q]),
                .acc_i(acc_context_q[issue_context_q]),
                .m_valid(m_valid_w[inst]),
                .m_ready(1'b1),
                .m_context_o(m_context_w[inst*CONTEXT_W +: CONTEXT_W]),
                .m_tap_last_o(m_tap_last_w[inst]),
                .acc_o(acc_o_w[inst*ACC_VEC_W +: ACC_VEC_W])
            );

            integer ctx_idx;
            always @(posedge clk) begin
                if (rst) begin
                    issue_context_q <= {CONTEXT_IDX_W{1'b0}};
                    for (ctx_idx = 0; ctx_idx < CONTEXTS; ctx_idx = ctx_idx + 1) begin
                        tap_count_q[ctx_idx] <= {TAP_COUNTER_W{1'b0}};
                        act_bank_q[ctx_idx] <= 10'sd1;
                        weight_bank_q[ctx_idx] <= {WEIGHT_VEC_W{1'b1}};
                    end
                end else begin
                    if (clear_active_q) begin
                        issue_context_q <= {CONTEXT_IDX_W{1'b0}};
                        tap_count_q[clear_context_q] <= {TAP_COUNTER_W{1'b0}};
                        act_bank_q[clear_context_q] <= 10'sd1;
                        weight_bank_q[clear_context_q] <= {WEIGHT_VEC_W{1'b1}};
                    end else if (issue_valid_w && s_ready_w[inst]) begin
                        if (tap_count_q[issue_context_q] == (TAPS_PER_CONTEXT - 1)) begin
                            tap_count_q[issue_context_q] <= {TAP_COUNTER_W{1'b0}};
                        end else begin
                            tap_count_q[issue_context_q] <= tap_count_q[issue_context_q] + 1'b1;
                        end

                        act_bank_q[issue_context_q] <= act_bank_q[issue_context_q] + 10'sd1;
                        weight_bank_q[issue_context_q] <=
                            {weight_bank_q[issue_context_q][WEIGHT_VEC_W-9:0],
                             weight_bank_q[issue_context_q][WEIGHT_VEC_W-1:WEIGHT_VEC_W-8] ^ 8'h5a};

                        if (issue_context_q == (CONTEXTS - 1)) begin
                            issue_context_q <= {CONTEXT_IDX_W{1'b0}};
                        end else begin
                            issue_context_q <= issue_context_q + 1'b1;
                        end
                    end

                    if (acc_wr_en) begin
                        acc_context_q[acc_wr_context] <= acc_wr_data;
                    end
                end
            end
        end
    endgenerate

    integer mix_inst;
    always @(*) begin
        status_mix = 32'h00000000;
        for (mix_inst = 0; mix_inst < INSTANCE_COUNT; mix_inst = mix_inst + 1) begin
            if (m_valid_w[mix_inst]) begin
                status_mix = status_mix ^
                    acc_o_w[mix_inst*ACC_VEC_W +: 32] ^
                    {23'd0, m_tap_last_w[mix_inst],
                     m_context_w[mix_inst*CONTEXT_W +: 8]};
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            status_q <= 32'h1a10_1001;
        end else if (clear_start_w) begin
            status_q <= 32'h1a10_1001;
        end else if (|m_valid_w) begin
            status_q <= {status_q[30:0], status_q[31]} ^ status_mix;
        end
    end
endmodule
