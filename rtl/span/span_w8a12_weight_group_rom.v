`timescale 1ns/1ps

// Registered group-ROM reader for streamed W8A12 weights.
//
// The memory is pre-packed as one OUT_LANES x TAP_LANES group per word. A
// request is accepted whenever req_valid is high; req_ready and weight_group_o
// are returned one cycle later and held long enough for the current streamed
// conv scheduler to capture them.
module span_w8a12_weight_group_rom #(
    parameter integer OUT_CH = 48,
    parameter integer TAP_COUNT = 27,
    parameter integer OUT_LANES = 8,
    parameter integer TAP_LANES = 16,
    parameter integer WEIGHT_W = 8,
    parameter MEM_FILE = ""
) (
    input  wire                                  clk,
    input  wire                                  rst,
    input  wire                                  req_valid,
    output reg                                   req_ready,
    input  wire [31:0]                           req_out_group,
    input  wire [31:0]                           req_tap_group,
    output reg signed [OUT_LANES*TAP_LANES*WEIGHT_W-1:0] weight_group_o
);
    localparam integer OUT_GROUP_COUNT = (OUT_CH + OUT_LANES - 1) / OUT_LANES;
    localparam integer TAP_GROUP_COUNT = (TAP_COUNT + TAP_LANES - 1) / TAP_LANES;
    localparam integer GROUP_COUNT = OUT_GROUP_COUNT * TAP_GROUP_COUNT;
    localparam integer GROUP_W = OUT_LANES * TAP_LANES * WEIGHT_W;

    (* rom_style = "block" *) reg signed [GROUP_W-1:0] group_mem [0:GROUP_COUNT-1];

    wire [31:0] group_addr = req_out_group * TAP_GROUP_COUNT + req_tap_group;
    reg [31:0] group_addr_q;
    reg pending_q;
    reg wait_deassert_q;

    integer init_idx;
    initial begin
        for (init_idx = 0; init_idx < GROUP_COUNT; init_idx = init_idx + 1)
            group_mem[init_idx] = {GROUP_W{1'b0}};
        if (MEM_FILE != "")
            $readmemh(MEM_FILE, group_mem);
    end

    always @(posedge clk) begin
        if (rst) begin
            req_ready <= 1'b0;
            weight_group_o <= {GROUP_W{1'b0}};
            group_addr_q <= 32'd0;
            pending_q <= 1'b0;
            wait_deassert_q <= 1'b0;
        end else begin
            req_ready <= pending_q;
            if (pending_q) begin
                if (group_addr_q < GROUP_COUNT)
                    weight_group_o <= group_mem[group_addr_q];
                else
                    weight_group_o <= {GROUP_W{1'b0}};
                pending_q <= 1'b0;
                wait_deassert_q <= 1'b1;
            end else if (wait_deassert_q) begin
                if (!req_valid)
                    wait_deassert_q <= 1'b0;
            end else if (req_valid) begin
                group_addr_q <= group_addr;
                pending_q <= 1'b1;
            end
        end
    end
endmodule
