`timescale 1ns/1ps

// One-cycle synchronous W8A12 unary LUT backed by block ROM.
module span_w8a12_unary_lut_sync #(
    parameter integer ACT_W = 12,
    parameter LUT_FILE = ""
) (
    input  wire                         clk,
    input  wire                         en,
    input  wire signed [ACT_W-1:0]      x_i,
    output reg  signed [ACT_W-1:0]      y_o
);
    localparam integer LUT_DEPTH = 1 << ACT_W;

    (* rom_style = "block", ram_style = "block" *)
    reg signed [ACT_W-1:0] lut_mem [0:LUT_DEPTH-1];

    wire [ACT_W-1:0] sign_offset = {1'b1, {(ACT_W-1){1'b0}}};
    wire [ACT_W-1:0] lut_addr = x_i ^ sign_offset;

    initial begin
        if (LUT_FILE != "")
            $readmemh(LUT_FILE, lut_mem);
    end

    always @(posedge clk) begin
        if (en)
            y_o <= lut_mem[lut_addr];
    end
endmodule

// Vector wrapper with ready/valid flow control.  It returns both the LUT output
// and the original input vector, so attention can align sim-att with out3.
module span_w8a12_unary_lut_vector_stage #(
    parameter integer ACT_W = 12,
    parameter integer CH = 48,
    parameter LUT_FILE = ""
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         s_valid,
    output wire                         s_ready,
    input  wire signed [CH*ACT_W-1:0]   s_feat,
    input  wire                         s_user,
    input  wire                         s_last,

    output reg                          m_valid,
    input  wire                         m_ready,
    output reg  signed [CH*ACT_W-1:0]   m_lut_feat,
    output reg  signed [CH*ACT_W-1:0]   m_x_feat,
    output reg                          m_user,
    output reg                          m_last
);
    localparam integer CH_IDX_W = (CH <= 1) ? 1 : $clog2(CH + 1);
    localparam [CH_IDX_W-1:0] CH_COUNT = CH;

    reg busy;
    reg rd_pending;
    reg pending_user;
    reg pending_last;
    reg signed [CH*ACT_W-1:0] pending_x_feat;
    reg [CH_IDX_W-1:0] rd_ch;
    reg [CH_IDX_W-1:0] wr_ch;
    reg write_pending;

    wire output_free = !m_valid || m_ready;
    assign s_ready = !busy && !rd_pending && output_free;

    wire input_take = s_valid && s_ready;
    wire issue_read = busy && (rd_ch < CH_COUNT);
    wire [CH_IDX_W-1:0] lut_ch = issue_read ? rd_ch : {CH_IDX_W{1'b0}};
    wire signed [ACT_W-1:0] lut_x = pending_x_feat[lut_ch*ACT_W +: ACT_W];
    wire signed [ACT_W-1:0] lut_y;

    span_w8a12_unary_lut_sync #(
        .ACT_W(ACT_W),
        .LUT_FILE(LUT_FILE)
    ) u_lut (
        .clk(clk),
        .en(issue_read),
        .x_i(lut_x),
        .y_o(lut_y)
    );

    always @(posedge clk) begin
        if (rst) begin
            busy <= 1'b0;
            rd_pending <= 1'b0;
            pending_user <= 1'b0;
            pending_last <= 1'b0;
            pending_x_feat <= {CH*ACT_W{1'b0}};
            rd_ch <= {CH_IDX_W{1'b0}};
            wr_ch <= {CH_IDX_W{1'b0}};
            write_pending <= 1'b0;
            m_valid <= 1'b0;
            m_lut_feat <= {CH*ACT_W{1'b0}};
            m_x_feat <= {CH*ACT_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
        end else begin
            if (m_valid && m_ready)
                m_valid <= 1'b0;

            if (write_pending)
                m_lut_feat[wr_ch*ACT_W +: ACT_W] <= lut_y;

            if (busy) begin
                if (issue_read) begin
                    write_pending <= 1'b1;
                    wr_ch <= rd_ch;
                    rd_ch <= rd_ch + 1'b1;
                end else begin
                    write_pending <= 1'b0;
                end

                if (!issue_read && !write_pending) begin
                    busy <= 1'b0;
                    rd_pending <= 1'b1;
                end
            end

            if (rd_pending && output_free) begin
                m_valid <= 1'b1;
                m_x_feat <= pending_x_feat;
                m_user <= pending_user;
                m_last <= pending_last;
                rd_pending <= 1'b0;
            end

            if (input_take) begin
                pending_x_feat <= s_feat;
                pending_user <= s_user;
                pending_last <= s_last;
                rd_ch <= {CH_IDX_W{1'b0}};
                write_pending <= 1'b0;
                busy <= 1'b1;
                m_lut_feat <= {CH*ACT_W{1'b0}};
            end
        end
    end
endmodule
