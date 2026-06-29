`timescale 1ns/1ps

// Raster stream cropper.
//
// Consumes one full input raster and emits only a rectangular crop. This is the
// output-side counterpart to halo-aware tile fetch: a W8A12 engine may compute a
// larger halo patch, while the board writer should store only the valid
// interior tile.
module sr_stream_cropper #(
    parameter integer DATA_W = 24,
    parameter integer IN_W = 8,
    parameter integer IN_H = 8,
    parameter integer CROP_X = 2,
    parameter integer CROP_Y = 2,
    parameter integer CROP_W = 4,
    parameter integer CROP_H = 4
) (
    input  wire                 clk,
    input  wire                 rst,

    input  wire                 s_valid,
    output wire                 s_ready,
    input  wire [DATA_W-1:0]    s_data,
    input  wire                 s_user,
    input  wire                 s_last,

    output reg                  m_valid,
    input  wire                 m_ready,
    output reg  [DATA_W-1:0]    m_data,
    output reg                  m_user,
    output reg                  m_last
);
    localparam integer IN_PIXELS = IN_W * IN_H;
    localparam integer X_W = (IN_W <= 2) ? 1 : $clog2(IN_W);
    localparam integer Y_W = (IN_H <= 2) ? 1 : $clog2(IN_H);
    localparam integer OUT_X_W = (CROP_W <= 2) ? 1 : $clog2(CROP_W);

    reg [X_W-1:0] in_x;
    reg [Y_W-1:0] in_y;
    reg [OUT_X_W-1:0] crop_out_x;

    wire out_can_advance = !m_valid || m_ready;
    wire s_fire = s_valid && s_ready;
    wire in_crop = (in_x >= CROP_X) && (in_x < CROP_X + CROP_W) &&
                   (in_y >= CROP_Y) && (in_y < CROP_Y + CROP_H);
    wire end_input_row = (in_x == IN_W - 1);
    wire end_input_frame = end_input_row && (in_y == IN_H - 1);
    wire end_crop_row = (crop_out_x == CROP_W - 1);

    assign s_ready = out_can_advance;

    always @(posedge clk) begin
        if (rst) begin
            in_x <= {X_W{1'b0}};
            in_y <= {Y_W{1'b0}};
            crop_out_x <= {OUT_X_W{1'b0}};
            m_valid <= 1'b0;
            m_data <= {DATA_W{1'b0}};
            m_user <= 1'b0;
            m_last <= 1'b0;
        end else begin
            if (m_valid && m_ready) begin
                m_valid <= 1'b0;
                m_user <= 1'b0;
                m_last <= 1'b0;
            end

            if (s_fire) begin
                if (in_crop) begin
                    m_valid <= 1'b1;
                    m_data <= s_data;
                    m_user <= (in_x == CROP_X) && (in_y == CROP_Y);
                    m_last <= end_crop_row;
                    if (end_crop_row)
                        crop_out_x <= {OUT_X_W{1'b0}};
                    else
                        crop_out_x <= crop_out_x + {{(OUT_X_W-1){1'b0}}, 1'b1};
                end

                if (end_input_frame) begin
                    in_x <= {X_W{1'b0}};
                    in_y <= {Y_W{1'b0}};
                    crop_out_x <= {OUT_X_W{1'b0}};
                end else if (end_input_row) begin
                    in_x <= {X_W{1'b0}};
                    in_y <= in_y + {{(Y_W-1){1'b0}}, 1'b1};
                end else begin
                    in_x <= in_x + {{(X_W-1){1'b0}}, 1'b1};
                end
            end
        end
    end

    wire unused_sideband = s_user ^ s_last;
    wire unused_pixels = (IN_PIXELS == 0);
endmodule
