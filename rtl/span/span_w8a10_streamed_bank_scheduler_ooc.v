`timescale 1ns/1ps

// ROM-free banked scheduler OOC probe for the streamed W8A10 path.
//
// This block sits one level above span_w8a10_packed_tap_mac_stream. It models
// the per-group accumulator context bank plus the current activation/weight
// tap banks needed to keep multiple MAC contexts in flight. It intentionally
// does not include full layer ROMs, full-frame address generation, AXIS/DMA,
// or requantization; those remain later integration gates.
(* keep_hierarchy = "yes" *)
module span_w8a10_streamed_bank_scheduler_ooc #(
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
    input  wire         enable_i,
    output wire         active_o,
    output wire [31:0]  status_o
);
    localparam integer BANK_COUNT = INSTANCE_COUNT * CONTEXTS;
    localparam integer BANK_ADDR_W = (BANK_COUNT <= 2) ? 1 : $clog2(BANK_COUNT);
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

    reg [CONTEXT_IDX_W-1:0] issue_context_q [0:INSTANCE_COUNT-1];
    reg [TAP_COUNTER_W-1:0] tap_count_q [0:BANK_COUNT-1];

    (* keep = "true" *) reg [ACC_VEC_W-1:0] acc_context_q [0:BANK_COUNT-1];
    (* keep = "true" *) reg signed [9:0] act_bank_q [0:BANK_COUNT-1];
    (* keep = "true" *) reg [WEIGHT_VEC_W-1:0] weight_bank_q [0:BANK_COUNT-1];

    wire [INSTANCE_COUNT-1:0] s_ready_w;
    wire [INSTANCE_COUNT-1:0] m_valid_w;
    wire [INSTANCE_COUNT*CONTEXT_W-1:0] m_context_w;
    wire [INSTANCE_COUNT-1:0] m_tap_last_w;
    wire [INSTANCE_COUNT*ACC_VEC_W-1:0] acc_o_w;

    reg [31:0] status_q;
    reg [31:0] status_mix;

    assign active_o = enable_i | (|m_valid_w);
    assign status_o = status_q;

    genvar inst;
    generate
        for (inst = 0; inst < INSTANCE_COUNT; inst = inst + 1) begin : g_sched
            wire [BANK_ADDR_W-1:0] issue_addr_w =
                (inst * CONTEXTS) + issue_context_q[inst];
            wire [CONTEXT_W-1:0] issue_context_w =
                {{(CONTEXT_W-CONTEXT_IDX_W){1'b0}}, issue_context_q[inst]};
            wire issue_tap_last_w =
                (tap_count_q[issue_addr_w] == (TAPS_PER_CONTEXT - 1));

            (* dont_touch = "yes" *)
            span_w8a10_packed_tap_mac_stream #(
                .LANES(LANES),
                .ACC_W(ACC_W),
                .CONTEXT_W(CONTEXT_W),
                .PIPELINE(PIPELINE)
            ) u_tap_mac (
                .clk(clk),
                .rst(rst),
                .s_valid(enable_i),
                .s_ready(s_ready_w[inst]),
                .s_context_i(issue_context_w),
                .s_tap_last_i(issue_tap_last_w),
                .act_i(act_bank_q[issue_addr_w]),
                .weights_i(weight_bank_q[issue_addr_w]),
                .acc_i(acc_context_q[issue_addr_w]),
                .m_valid(m_valid_w[inst]),
                .m_ready(1'b1),
                .m_context_o(m_context_w[inst*CONTEXT_W +: CONTEXT_W]),
                .m_tap_last_o(m_tap_last_w[inst]),
                .acc_o(acc_o_w[inst*ACC_VEC_W +: ACC_VEC_W])
            );
        end
    endgenerate

    integer init_idx;
    integer issue_inst;
    integer issue_addr;
    integer write_inst;
    integer write_ctx;
    integer write_addr;

    always @(*) begin
        status_mix = 32'h00000000;
        for (write_inst = 0; write_inst < INSTANCE_COUNT; write_inst = write_inst + 1) begin
            if (m_valid_w[write_inst]) begin
                status_mix = status_mix ^
                    acc_o_w[write_inst*ACC_VEC_W +: 32] ^
                    {23'd0, m_tap_last_w[write_inst],
                     m_context_w[write_inst*CONTEXT_W +: 8]};
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            status_q <= 32'h1a10_0001;
            for (init_idx = 0; init_idx < INSTANCE_COUNT; init_idx = init_idx + 1) begin
                issue_context_q[init_idx] <= {CONTEXT_IDX_W{1'b0}};
            end
            for (init_idx = 0; init_idx < BANK_COUNT; init_idx = init_idx + 1) begin
                tap_count_q[init_idx] <= {TAP_COUNTER_W{1'b0}};
                act_bank_q[init_idx] <= $signed(init_idx[9:0]);
                weight_bank_q[init_idx] <= {WEIGHT_VEC_W{1'b0}} ^ init_idx;
            end
        end else begin
            if (enable_i) begin
                for (issue_inst = 0; issue_inst < INSTANCE_COUNT; issue_inst = issue_inst + 1) begin
                    issue_addr = issue_inst * CONTEXTS + issue_context_q[issue_inst];
                    if (s_ready_w[issue_inst]) begin
                        if (tap_count_q[issue_addr] == (TAPS_PER_CONTEXT - 1)) begin
                            tap_count_q[issue_addr] <= {TAP_COUNTER_W{1'b0}};
                        end else begin
                            tap_count_q[issue_addr] <= tap_count_q[issue_addr] + 1'b1;
                        end

                        act_bank_q[issue_addr] <= act_bank_q[issue_addr] + 10'sd1;
                        weight_bank_q[issue_addr] <=
                            {weight_bank_q[issue_addr][WEIGHT_VEC_W-9:0],
                             weight_bank_q[issue_addr][WEIGHT_VEC_W-1:WEIGHT_VEC_W-8] ^ 8'h5a};

                        if (issue_context_q[issue_inst] == (CONTEXTS - 1)) begin
                            issue_context_q[issue_inst] <= {CONTEXT_IDX_W{1'b0}};
                        end else begin
                            issue_context_q[issue_inst] <= issue_context_q[issue_inst] + 1'b1;
                        end
                    end
                end
            end

            for (write_inst = 0; write_inst < INSTANCE_COUNT; write_inst = write_inst + 1) begin
                if (m_valid_w[write_inst]) begin
                    write_ctx = m_context_w[write_inst*CONTEXT_W +: CONTEXT_W];
                    if (write_ctx < CONTEXTS) begin
                        write_addr = write_inst * CONTEXTS + write_ctx;
                        acc_context_q[write_addr] <= acc_o_w[write_inst*ACC_VEC_W +: ACC_VEC_W];
                    end
                end
            end

            if (|m_valid_w) begin
                status_q <= {status_q[30:0], status_q[31]} ^ status_mix;
            end
        end
    end
endmodule
