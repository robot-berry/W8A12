`timescale 1ns/1ps

// Dynamic raster cropper for a fixed-size stream.
//
// The TinySPAN tile core always emits a full TILE_W*SCALE by TILE_H*SCALE
// raster. Edge tiles in a full LR frame can have smaller valid_w/valid_h. This
// module consumes the entire fixed-size stream, forwards only the dynamic valid
// rectangle at the top-left, and drops padded pixels so the upstream core can
// drain cleanly before the next tile starts.
module sr_stream_dynamic_cropper #(
    parameter integer DATA_W = 24,
    parameter integer IN_W = 128,
    parameter integer IN_H = 128,
    parameter integer COORD_W = 16
) (
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  start,
    input  wire [COORD_W-1:0]    valid_w_i,
    input  wire [COORD_W-1:0]    valid_h_i,

    input  wire                  s_valid,
    output wire                  s_ready,
    input  wire [DATA_W-1:0]     s_data,
    input  wire                  s_user,
    input  wire                  s_last,

    output wire                  m_valid,
    input  wire                  m_ready,
    output wire [DATA_W-1:0]     m_data,
    output wire                  m_user,
    output wire                  m_last,

    output reg                   busy,
    output reg                   done,
    output reg                   error
);
    localparam integer X_W = (IN_W <= 2) ? 1 : $clog2(IN_W);
    localparam integer Y_W = (IN_H <= 2) ? 1 : $clog2(IN_H);
    localparam [X_W-1:0] IN_W_LAST = IN_W - 1;
    localparam [Y_W-1:0] IN_H_LAST = IN_H - 1;
    localparam [COORD_W-1:0] IN_W_C = IN_W;
    localparam [COORD_W-1:0] IN_H_C = IN_H;

    reg active;
    reg [X_W-1:0] x_q;
    reg [Y_W-1:0] y_q;
    reg [COORD_W-1:0] valid_w_q;
    reg [COORD_W-1:0] valid_h_q;

    wire [COORD_W-1:0] x_ext = {{(COORD_W-X_W){1'b0}}, x_q};
    wire [COORD_W-1:0] y_ext = {{(COORD_W-Y_W){1'b0}}, y_q};
    wire keep_pixel = active && (x_ext < valid_w_q) && (y_ext < valid_h_q);
    wire last_x = (x_q == IN_W_LAST);
    wire last_y = (y_q == IN_H_LAST);
    wire final_input_pixel = last_x && last_y;
    wire output_row_last = keep_pixel && (x_ext == (valid_w_q - {{(COORD_W-1){1'b0}}, 1'b1}));
    wire input_fire = s_valid && s_ready;
    wire command_bad = (valid_w_i == {COORD_W{1'b0}}) ||
                       (valid_h_i == {COORD_W{1'b0}}) ||
                       (valid_w_i > IN_W_C) ||
                       (valid_h_i > IN_H_C);

    assign m_valid = active && s_valid && keep_pixel;
    assign s_ready = active ? (keep_pixel ? m_ready : 1'b1) : 1'b0;
    assign m_data = s_data;
    assign m_user = keep_pixel && (x_q == {X_W{1'b0}}) && (y_q == {Y_W{1'b0}});
    assign m_last = output_row_last;

    always @(posedge clk) begin
        if (rst) begin
            active <= 1'b0;
            x_q <= {X_W{1'b0}};
            y_q <= {Y_W{1'b0}};
            valid_w_q <= {COORD_W{1'b0}};
            valid_h_q <= {COORD_W{1'b0}};
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start) begin
                x_q <= {X_W{1'b0}};
                y_q <= {Y_W{1'b0}};
                valid_w_q <= valid_w_i;
                valid_h_q <= valid_h_i;
                error <= command_bad;
                active <= !command_bad;
                busy <= !command_bad;
                done <= command_bad;
            end else if (input_fire) begin
                if (final_input_pixel) begin
                    active <= 1'b0;
                    busy <= 1'b0;
                    done <= 1'b1;
                    x_q <= {X_W{1'b0}};
                    y_q <= {Y_W{1'b0}};
                end else if (last_x) begin
                    x_q <= {X_W{1'b0}};
                    y_q <= y_q + {{(Y_W-1){1'b0}}, 1'b1};
                end else begin
                    x_q <= x_q + {{(X_W-1){1'b0}}, 1'b1};
                end
            end
        end
    end

    wire unused_sideband = s_user ^ s_last;
endmodule
