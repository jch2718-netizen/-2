`timescale 1ns / 1ps
module DAC_display(clk, rst, btn, add_sel, dac_csn, dac_ldacn, dac_wrn, dac_a_b, dac_d, led_out,
                   seg_data, seg_sel, LCD_E, LCD_RS, LCD_RW, LCD_DATA);

input clk, rst;
input [5:0] btn;
input add_sel;
output dac_csn, dac_ldacn, dac_wrn, dac_a_b;
output [7:0] dac_d;
output [7:0] led_out;
output reg [7:0] seg_data;
output reg [7:0] seg_sel;
output LCD_E;
output reg LCD_RS, LCD_RW;
output reg [7:0] LCD_DATA;

DAC D1(.clk(clk), .rst(rst), .btn(btn), .add_sel(add_sel),
       .dac_csn(dac_csn), .dac_ldacn(dac_ldacn), .dac_wrn(dac_wrn), .dac_a_b(dac_a_b),
       .dac_d(dac_d), .led_out(led_out));

function [11:0] bin2bcd;
    input [7:0] bin;
    reg [19:0] s;
    integer i;
    begin
        s = {12'd0, bin};
        for (i = 0; i < 8; i = i + 1) begin
            if (s[11:8]  > 4) s[11:8]  = s[11:8]  + 3;
            if (s[15:12] > 4) s[15:12] = s[15:12] + 3;
            if (s[19:16] > 4) s[19:16] = s[19:16] + 3;
            s = s << 1;
        end
        bin2bcd = s[19:8];
    end
endfunction

function [7:0] seg_decode;
    input [3:0] d;
    case (d)
        4'd0: seg_decode = 8'b11111100;
        4'd1: seg_decode = 8'b01100000;
        4'd2: seg_decode = 8'b11011010;
        4'd3: seg_decode = 8'b11110010;
        4'd4: seg_decode = 8'b01100110;
        4'd5: seg_decode = 8'b10110110;
        4'd6: seg_decode = 8'b10111110;
        4'd7: seg_decode = 8'b11100000;
        4'd8: seg_decode = 8'b11111110;
        4'd9: seg_decode = 8'b11110110;
        default: seg_decode = 8'b00000000;
    endcase
endfunction

wire [11:0] bcd;
assign bcd = bin2bcd(dac_d);

always @(posedge clk or negedge rst) begin
    if (!rst) seg_sel <= 8'b11111110;
    else      seg_sel <= {seg_sel[6:0], seg_sel[7]};
end

always @(*) begin
    case (seg_sel)
        8'b11011111: seg_data = seg_decode(bcd[11:8]);
        8'b10111111: seg_data = seg_decode(bcd[7:4]);
        8'b01111111: seg_data = seg_decode(bcd[3:0]);
        default:     seg_data = 8'b00000000;
    endcase
end

reg [2:0] lcd_state;
integer lcd_cnt;
parameter L_DELAY = 3'd0,
          L_FUNC  = 3'd1,
          L_DISP  = 3'd2,
          L_ENTRY = 3'd3,
          L_LINE1 = 3'd4,
          L_LINE2 = 3'd5,
          L_HOLD  = 3'd6;

always @(posedge clk or negedge rst) begin
    if (!rst)
        lcd_state <= L_DELAY;
    else begin
        case (lcd_state)
            L_DELAY : if (lcd_cnt == 70) lcd_state <= L_FUNC;
            L_FUNC  : if (lcd_cnt == 30) lcd_state <= L_DISP;
            L_DISP  : if (lcd_cnt == 30) lcd_state <= L_ENTRY;
            L_ENTRY : if (lcd_cnt == 30) lcd_state <= L_LINE1;
            L_LINE1 : if (lcd_cnt == 20) lcd_state <= L_LINE2;
            L_LINE2 : if (lcd_cnt == 20) lcd_state <= L_HOLD;
            L_HOLD  : if (lcd_cnt == 5)  lcd_state <= L_LINE1;
            default : lcd_state <= L_DELAY;
        endcase
    end
end

always @(posedge clk or negedge rst) begin
    if (!rst)
        lcd_cnt <= 0;
    else begin
        case (lcd_state)
            L_DELAY : if (lcd_cnt >= 70) lcd_cnt <= 0; else lcd_cnt <= lcd_cnt + 1;
            L_FUNC  : if (lcd_cnt >= 30) lcd_cnt <= 0; else lcd_cnt <= lcd_cnt + 1;
            L_DISP  : if (lcd_cnt >= 30) lcd_cnt <= 0; else lcd_cnt <= lcd_cnt + 1;
            L_ENTRY : if (lcd_cnt >= 30) lcd_cnt <= 0; else lcd_cnt <= lcd_cnt + 1;
            L_LINE1 : if (lcd_cnt >= 20) lcd_cnt <= 0; else lcd_cnt <= lcd_cnt + 1;
            L_LINE2 : if (lcd_cnt >= 20) lcd_cnt <= 0; else lcd_cnt <= lcd_cnt + 1;
            L_HOLD  : if (lcd_cnt >= 5)  lcd_cnt <= 0; else lcd_cnt <= lcd_cnt + 1;
            default : lcd_cnt <= 0;
        endcase
    end
end

always @(posedge clk or negedge rst) begin
    if (!rst)
        {LCD_RS, LCD_RW, LCD_DATA} <= 10'b1_1_0000_0000;
    else begin
        case (lcd_state)
            L_FUNC  : {LCD_RS, LCD_RW, LCD_DATA} <= 10'b0_0_0011_1000;
            L_DISP  : {LCD_RS, LCD_RW, LCD_DATA} <= 10'b0_0_0000_1100;
            L_ENTRY : {LCD_RS, LCD_RW, LCD_DATA} <= 10'b0_0_0000_0110;
            L_LINE1 : begin
                case (lcd_cnt)
                    0  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b00, 8'h80};
                    1  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h44};
                    2  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h41};
                    3  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h43};
                    4  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h20};
                    5  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h49};
                    6  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h4E};
                    7  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h20};
                    8  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h3A};
                    9  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h20};
                    10 : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 4'h3, bcd[11:8]};
                    11 : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 4'h3, bcd[7:4]};
                    12 : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 4'h3, bcd[3:0]};
                    default : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h20};
                endcase
            end
            L_LINE2 : begin
                case (lcd_cnt)
                    0  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b00, 8'hC0};
                    1  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h42};
                    2  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h49};
                    3  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h4E};
                    4  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h20};
                    5  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h3A};
                    6  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h20};
                    7  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 7'b0011000, dac_d[7]};
                    8  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 7'b0011000, dac_d[6]};
                    9  : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 7'b0011000, dac_d[5]};
                    10 : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 7'b0011000, dac_d[4]};
                    11 : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 7'b0011000, dac_d[3]};
                    12 : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 7'b0011000, dac_d[2]};
                    13 : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 7'b0011000, dac_d[1]};
                    14 : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 7'b0011000, dac_d[0]};
                    default : {LCD_RS, LCD_RW, LCD_DATA} <= {2'b10, 8'h20};
                endcase
            end
            default : {LCD_RS, LCD_RW, LCD_DATA} <= 10'b1_1_0000_0000;
        endcase
    end
end

assign LCD_E = clk;

endmodule
