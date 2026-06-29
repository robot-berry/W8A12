`timescale 1ns/1ps

// Convert TinySPAN final output q values to RGB888 exactly for the frozen plan:
//   uint8 = round(clamp(q * output_scale, 0, 1) * 255)
// output_scale * 255 = 2.147650932893157, Q16 multiplier = 140748.
module span_tinyspan_w8a8_qrgb_to_rgb888 #(
    parameter integer ACT_W = 8,
    parameter integer Q16_MULT = 140748
) (
    input  wire signed [3*ACT_W-1:0] q_rgb_i,
    output wire [23:0]               rgb_o
);
    function automatic [7:0] q_to_u8;
        input signed [ACT_W-1:0] q;
        reg [31:0] product;
        reg [31:0] rounded;
        begin
            if (q <= 0) begin
                q_to_u8 = 8'd0;
            end else begin
                product = q * Q16_MULT;
                rounded = (product + 32'd32768) >> 16;
                if (rounded > 32'd255)
                    q_to_u8 = 8'd255;
                else
                    q_to_u8 = rounded[7:0];
            end
        end
    endfunction

    wire [7:0] r = q_to_u8(q_rgb_i[0*ACT_W +: ACT_W]);
    wire [7:0] g = q_to_u8(q_rgb_i[1*ACT_W +: ACT_W]);
    wire [7:0] b = q_to_u8(q_rgb_i[2*ACT_W +: ACT_W]);

    assign rgb_o = {r, g, b};
endmodule

