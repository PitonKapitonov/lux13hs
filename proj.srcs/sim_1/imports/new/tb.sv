`timescale 1ns / 1ps

module testbench();
    
logic clk_in200_p = 1;
logic clk_in200_n; assign clk_in200_n = !clk_in200_p;
logic mii_tx_clk = 0;
logic mii_rx_clk = 0;
always #2.5 clk_in200_p = ~clk_in200_p;  
always #20 mii_tx_clk = ~mii_tx_clk;
always #20 mii_rx_clk = ~mii_rx_clk;
  
logic [79:0] CH_p;
logic [79:0] CH_n; 
logic [9:0] frame [1295:0][863:0];

localparam  focal_width  = 20;                                                        
localparam  focal_height = 20;     

initial begin
    for (int c = 0; c < 1296; c = c + 1) begin  
        for (int r = 0; r < 864; r = r + 1) begin
           frame[c][r] = $urandom;
        end
    end
    #587us; 
    $display("---------------------------------------");
    $display("FINAL CHECK: Total errors found: %0d", top.LUX13HS_ADC_readout.error_count);
    if (top.LUX13HS_ADC_readout.error_count == 0)
        $display("TEST PASSED");
    else
        $display("TEST FAILED");
    $display("---------------------------------------");
    $finish;   
end


function automatic void get_centroid (
    input logic [10:0] start_x, 
    input logic [9:0]  start_y,
    output real Xc_expected,
    output real Yc_expected
);
    logic [$clog2(focal_height*focal_width*1023*2047)-1:0] sum_Ix = 0;
    logic [$clog2(focal_height*focal_width*1023*2047)-1:0] sum_Iy = 0;
    logic [$clog2(focal_height*focal_width*1023)-1:0] sum_I = 0;


    for (int x = start_x; x < start_x + 20; x++) begin
        for (int y = start_y; y < start_y + 20; y++) begin
            sum_Ix += frame[x][y] * x;
            sum_Iy += frame[x][y] * y;
            sum_I  += frame[x][y];
        end
    end

    Xc_expected = real'(sum_Ix) / sum_I;
    Yc_expected = real'(sum_Iy) / sum_I;
 
endfunction

genvar i;
generate
    for (i = 0; i < 80; i = i + 1) begin
        assign CH_n[i] = ~CH_p[i];
end  
endgenerate


logic [8:0] row_address; 
assign row_address = top.LUX13HS_control.row_address;

logic clk_out_532_sim;
assign clk_out_532_sim = top.clk_wiz_sim.clk_out_532_sim;

logic Pclk_p, Pclk_n;
top top (
    .clk_in200_p(clk_in200_p),
    .clk_in200_n(clk_in200_n),
    .clk_lux(clk_lux),     // main clock from FPGA to LUX13HS
    .Pclk_p(Pclk_p),  // sample clock from LUX13HS to FPGA
    .Pclk_n(Pclk_n),
    .CH_p(CH_p),
    .CH_n(CH_n),
    .mii_tx_clk(mii_tx_clk),
    .mii_rx_clk(mii_rx_clk),
    .st_readb_n(st_readb_n),
    .st_readt_n(st_readt_n)
);
   

assign #1.875 Pclk_p = clk_lux;     //1.875 for middle of HIGH clk_lux as shown in LUX13HS datasheet on Fig.10
assign Pclk_n = !Pclk_p;

logic data_clk;
assign #1.875 data_clk = top.clk_wiz_sim.clk_out_532_sim;



/* data_clk is a bit clock that is aligned with Pclk (sample clk) */
//==============================================================================================================//
//                                                                                                              //
//                                               DATA GENERATION                                                //
//                                                                                                              //
//==============================================================================================================//
logic [8:0] row_address_top = 'd511, row_address_bot = 'd511;
/*
There is a delay between pulses !st_readb_n or !st_readt_n and data out. It's not exactly known and about 3-4 clocks from LUX13HS datasheet.
I want to use the condition of cnt_bot_Pclk == 0 or cnt_top_Pclk == 0 to count this delay.                            
I will try to start with 3 clocks delay.                                                                              
*/
logic [9:0] cnt_bot_Pclk = 0;
logic [9:0] cnt_top_Pclk = 0;
logic [1:0] enable_cnt_delay_bot = 'd3, enable_cnt_delay_top = 'd3;
logic [3:0] cnt_delay_bot = 0;
logic [3:0] cnt_delay_top = 0;
logic read_bot_locked = 0;
logic read_top_locked = 0;

logic enable_read_bot, enable_read_top;
logic enable_read_bot_del, enable_read_top_del, enable_read_top_del2, enable_read_top_del3;
logic enable_read_bot_strb, enable_read_bot_strb_del, enable_read_top_strb;
assign enable_read_bot_strb = !enable_read_bot && enable_read_bot_del;
assign enable_read_top_strb = !enable_read_top_del2 && enable_read_top_del3;

logic read_ram_b_en = 0;
logic read_finished;
logic [1:0] cnt_D_bot = 2'd3;
logic [1:0] cnt_D_top = 2'd3;

logic [7:0] cnt_top_Pclk_real;
logic [7:0] cnt_bot_Pclk_real;
logic [7:0] cnt_top_Pclk_real_shifted;
logic [7:0] cnt_bot_Pclk_real_shifted;
assign cnt_top_Pclk_real = cnt_top_Pclk[9:2];
assign cnt_bot_Pclk_real = cnt_bot_Pclk[9:2];

always @ (posedge data_clk) begin
//process st_readb_n
    if (enable_cnt_delay_bot == 0)  begin cnt_bot_Pclk <= cnt_bot_Pclk + 1; cnt_D_bot <= cnt_D_bot + 1; end
    //if (cnt_bot_Pclk == 'd165) cnt_bot_Pclk <= 1;
    if (!st_readb_n) begin 
        read_bot_locked <= 0;
        enable_cnt_delay_bot <= 1;
        if (row_address == 'd511) row_address_bot <= 'd430; else row_address_bot <= row_address-2; 
        cnt_bot_Pclk <= 0; 
        cnt_D_bot <= 2'd3;
        
    end  
    if (enable_cnt_delay_bot == 1) begin 
        if (cnt_delay_bot == 'd12) begin  enable_cnt_delay_bot <= 0; cnt_delay_bot <= 0; end 
        else  cnt_delay_bot <= cnt_delay_bot + 1;
    end 
//process st_readt_n
    if (enable_cnt_delay_top == 0) begin cnt_top_Pclk <= cnt_top_Pclk + 1; cnt_D_top <= cnt_D_top + 1; end 
    if (!st_readt_n) begin 
        read_top_locked <= 0;
        enable_cnt_delay_top <= 1;
        if (row_address == 'd511) row_address_top <= 'd431; else row_address_top <= row_address-2; 
        cnt_top_Pclk <= 0; 
        cnt_D_top <= 2'd3;
    end  
    if (enable_cnt_delay_top == 1) begin 
        if (cnt_delay_top == 'd12) begin enable_cnt_delay_top <= 0;  cnt_delay_top <= 0; end
        else  cnt_delay_top <= cnt_delay_top + 1;
    end
    
    enable_read_bot_del <= enable_read_bot;
    enable_read_top_del <= enable_read_top;
    enable_read_top_del2 <= enable_read_top_del;
    enable_read_top_del3 <= enable_read_top_del2;
    enable_read_bot_strb_del <= enable_read_bot_strb;
    if (row_address == 'd511 && row_address_top == 'd431 && enable_read_bot_strb_del) read_bot_locked <= 1;
    if (read_bot_locked && enable_read_top_strb) read_top_locked <= 1;
    
/*    s_axis_tlast_del <= s_axis_tlast;
    if (s_axis_tlast_del) read_ram_b_en <= 1;
    if (read_finished) read_ram_b_en <= 0;*/

end

assign enable_read_bot = (!read_bot_locked && row_address_bot <= 'd430 && cnt_bot_Pclk > 0 && cnt_bot_Pclk < 649)? 1 :0;
assign enable_read_top = (!read_top_locked && row_address_top <= 'd431 && cnt_top_Pclk > 0 && cnt_top_Pclk < 649)? 1 :0;


//==============================================================================================================//
//                                                                                                              //
//                                               SERIALIZATION                                                  //
//                                                                                                              //
//==============================================================================================================//

logic Pclk_p_real, Pclk_n_real, data_clk_real;
assign data_clk_real = ~data_clk;
//Serialization
integer j;
always @ (posedge data_clk) begin  
Pclk_p_real <= Pclk_p;
Pclk_n_real <= Pclk_n;
//Bottom reading
    if (enable_read_bot) begin                                                 //to add row_offset!
        for (j = 0; j < 40; j++) begin  
            if (row_address_bot != 'd511) begin           
                //clk1                                         
                if (cnt_bot_Pclk == 1) CH_p[j] <= frame[ST0[2*j + 0].column][ST0[2*j + 0].row_offset + 2*row_address_bot][ST0[2*j + 0].bit_number];
                if (cnt_bot_Pclk == 2) CH_p[j] <= frame[ST0[2*j + 1].column][ST0[2*j + 1].row_offset + 2*row_address_bot][ST0[2*j + 1].bit_number]; 
                if (cnt_bot_Pclk == 3) CH_p[j] <= frame[ST1[2*j + 0].column][ST1[2*j + 0].row_offset + 2*row_address_bot][ST1[2*j + 0].bit_number];
                if (cnt_bot_Pclk == 4) CH_p[j] <= frame[ST1[2*j + 1].column][ST1[2*j + 1].row_offset + 2*row_address_bot][ST1[2*j + 1].bit_number];  
                //clk2                                      
                if (cnt_bot_Pclk == 5) CH_p[j] <= frame[ST0[2*j + 0].column +4][ST0[2*j + 0].row_offset + 2*row_address_bot][ST0[2*j + 0].bit_number];
                if (cnt_bot_Pclk == 6) CH_p[j] <= frame[ST0[2*j + 1].column +4][ST0[2*j + 1].row_offset + 2*row_address_bot][ST0[2*j + 1].bit_number]; 
                if (cnt_bot_Pclk == 7) CH_p[j] <= frame[ST1[2*j + 0].column +4][ST1[2*j + 0].row_offset + 2*row_address_bot][ST1[2*j + 0].bit_number]; 
                if (cnt_bot_Pclk == 8) CH_p[j] <= frame[ST1[2*j + 1].column +4][ST1[2*j + 1].row_offset + 2*row_address_bot][ST1[2*j + 1].bit_number];   
                //clk3-clk162
                if ((cnt_bot_Pclk > 8)  && (cnt_bot_Pclk < 649)) begin                          
                    if (j < 20) begin    
                        if (cnt_D_bot == 0) CH_p[j] <= frame[ST0[2*j + 0].column + (644 - ((cnt_bot_Pclk-9)>>2)*4)][ST0[2*j + 0].row_offset + 2*row_address_bot][ST0[2*j + 0].bit_number];                                               
                        if (cnt_D_bot == 1) CH_p[j] <= frame[ST0[2*j + 1].column + (644 - ((cnt_bot_Pclk-9)>>2)*4)][ST0[2*j + 1].row_offset + 2*row_address_bot][ST0[2*j + 1].bit_number];      
                        if (cnt_D_bot == 2) CH_p[j] <= frame[ST1[2*j + 0].column + (644 - ((cnt_bot_Pclk-9)>>2)*4)][ST1[2*j + 0].row_offset + 2*row_address_bot][ST1[2*j + 0].bit_number];        
                        if (cnt_D_bot == 3) CH_p[j] <= frame[ST1[2*j + 1].column + (644 - ((cnt_bot_Pclk-9)>>2)*4)][ST1[2*j + 1].row_offset + 2*row_address_bot][ST1[2*j + 1].bit_number];            
                    end  
                    if (j > 19) begin                 
                        if (cnt_D_bot == 0) CH_p[j] <= frame[ST0[2*j + 0].column + (-640 + ((cnt_bot_Pclk-9)>>2)*4)][ST0[2*j + 0].row_offset + 2*row_address_bot][ST0[2*j + 0].bit_number];                                 
                        if (cnt_D_bot == 1) CH_p[j] <= frame[ST0[2*j + 1].column + (-640 + ((cnt_bot_Pclk-9)>>2)*4)][ST0[2*j + 1].row_offset + 2*row_address_bot][ST0[2*j + 1].bit_number];    
                        if (cnt_D_bot == 2) CH_p[j] <= frame[ST1[2*j + 0].column + (-640 + ((cnt_bot_Pclk-9)>>2)*4)][ST1[2*j + 0].row_offset + 2*row_address_bot][ST1[2*j + 0].bit_number]; 
                        if (cnt_D_bot == 3) CH_p[j] <= frame[ST1[2*j + 1].column + (-640 + ((cnt_bot_Pclk-9)>>2)*4)][ST1[2*j + 1].row_offset + 2*row_address_bot][ST1[2*j + 1].bit_number];      
                    end              
                end                             
            end 
        end
    end    
end   

always @ (posedge data_clk) begin    
    //Top reading    
    if (enable_read_top) begin                                                 
        for (j = 40; j < 80; j++) begin  
            if (row_address_top != 'd511) begin           
                //clk1                                         
                if (cnt_top_Pclk == 1) CH_p[j] <= frame[ST0[2*j - 80 + 0].column][ST0[2*j - 80 + 0].row_offset + 2*row_address_top][ST0[2*j - 80 + 0].bit_number];
                if (cnt_top_Pclk == 2) CH_p[j] <= frame[ST0[2*j - 80 + 1].column][ST0[2*j - 80 + 1].row_offset + 2*row_address_top][ST0[2*j - 80 + 1].bit_number];
                if (cnt_top_Pclk == 3) CH_p[j] <= frame[ST1[2*j - 80 + 0].column][ST1[2*j - 80 + 0].row_offset + 2*row_address_top][ST1[2*j - 80 + 0].bit_number];
                if (cnt_top_Pclk == 4) CH_p[j] <= frame[ST1[2*j - 80 + 1].column][ST1[2*j - 80 + 1].row_offset + 2*row_address_top][ST1[2*j - 80 + 1].bit_number];    
                //clk2                                      
                if (cnt_top_Pclk == 5) CH_p[j] <= frame[ST0[2*j - 80 + 0].column +4][ST0[2*j - 80 + 0].row_offset + 2*row_address_top][ST0[2*j - 80 + 0].bit_number];
                if (cnt_top_Pclk == 6) CH_p[j] <= frame[ST0[2*j - 80 + 1].column +4][ST0[2*j - 80 + 1].row_offset + 2*row_address_top][ST0[2*j - 80 + 1].bit_number];
                if (cnt_top_Pclk == 7) CH_p[j] <= frame[ST1[2*j - 80 + 0].column +4][ST1[2*j - 80 + 0].row_offset + 2*row_address_top][ST1[2*j - 80 + 0].bit_number];
                if (cnt_top_Pclk == 8) CH_p[j] <= frame[ST1[2*j - 80 + 1].column +4][ST1[2*j - 80 + 1].row_offset + 2*row_address_top][ST1[2*j - 80 + 1].bit_number]; 
                //clk3-clk162
                if ((cnt_top_Pclk > 8)  && (cnt_top_Pclk < 649)) begin                          
                    if (j < 60) begin    
                        if (cnt_D_top == 0) CH_p[j] <= frame[ST0[2*j - 80 + 0].column + (644 - ((cnt_top_Pclk-9)>>2)*4)][ST0[2*j - 80 + 0].row_offset + 2*row_address_top][ST0[2*j - 80 + 0].bit_number];                                              
                        if (cnt_D_top == 1) CH_p[j] <= frame[ST0[2*j - 80 + 1].column + (644 - ((cnt_top_Pclk-9)>>2)*4)][ST0[2*j - 80 + 1].row_offset + 2*row_address_top][ST0[2*j - 80 + 1].bit_number];     
                        if (cnt_D_top == 2) CH_p[j] <= frame[ST1[2*j - 80 + 0].column + (644 - ((cnt_top_Pclk-9)>>2)*4)][ST1[2*j - 80 + 0].row_offset + 2*row_address_top][ST1[2*j - 80 + 0].bit_number];      
                        if (cnt_D_top == 3) CH_p[j] <= frame[ST1[2*j - 80 + 1].column + (644 - ((cnt_top_Pclk-9)>>2)*4)][ST1[2*j - 80 + 1].row_offset + 2*row_address_top][ST1[2*j - 80 + 1].bit_number];           
                    end  
                    if (j > 59) begin                 
                        if (cnt_D_top == 0) CH_p[j] <= frame[ST0[2*j - 80 + 0].column + (-640 + ((cnt_top_Pclk-9)>>2)*4)][ST0[2*j - 80 + 0].row_offset + 2*row_address_top][ST0[2*j - 80 + 0].bit_number];                               
                        if (cnt_D_top == 1) CH_p[j] <= frame[ST0[2*j - 80 + 1].column + (-640 + ((cnt_top_Pclk-9)>>2)*4)][ST0[2*j - 80 + 1].row_offset + 2*row_address_top][ST0[2*j - 80 + 1].bit_number];   
                        if (cnt_D_top == 2) CH_p[j] <= frame[ST1[2*j - 80 + 0].column + (-640 + ((cnt_top_Pclk-9)>>2)*4)][ST1[2*j - 80 + 0].row_offset + 2*row_address_top][ST1[2*j - 80 + 0].bit_number];
                        if (cnt_D_top == 3) CH_p[j] <= frame[ST1[2*j - 80 + 1].column + (-640 + ((cnt_top_Pclk-9)>>2)*4)][ST1[2*j - 80 + 1].row_offset + 2*row_address_top][ST1[2*j - 80 + 1].bit_number];    
                    end              
                end                             
            end 
        end
    end    
end  





//Serialization table structure
typedef struct {
  int column;
  int row_offset;
  int bit_number;
} Serialization_table;

Serialization_table ST0 [0:79] = '{     //Serialization table from LUX13HS datasheet for  D0, D1 
//Left bottom
   //2j,DO    //2j + 1,D1
  '{0, 0, 6}, '{0, 0, 7},   //CH0..3
  '{0, 0, 2}, '{0, 0, 3},
  '{0, 1, 6}, '{0, 1, 7},
  '{0, 1, 2}, '{0, 1, 3},
  
  '{1, 0, 6}, '{1, 0, 7},   //CH4..7
  '{1, 0, 2}, '{1, 0, 3},
  '{1, 1, 6}, '{1, 1, 7},
  '{1, 1, 2}, '{1, 1, 3},
  
  '{2, 0, 6}, '{2, 0, 7},   //CH8..11
  '{2, 0, 2}, '{2, 0, 3},
  '{2, 1, 6}, '{2, 1, 7},
  '{2, 1, 2}, '{2, 1, 3},
  
  '{3, 0, 6}, '{3, 0, 7},   //CH12..15
  '{3, 0, 2}, '{3, 0, 3},
  '{3, 1, 6}, '{3, 1, 7},
  '{3, 1, 2}, '{3, 1, 3},
  
  '{1, 0, 0}, '{1, 0, 1},   //CH16..19
  '{3, 0, 0}, '{3, 0, 1},
  '{1, 1, 0}, '{1, 1, 1},
  '{3, 1, 0}, '{3, 1, 1},
  
//Right bottom
  '{1291, 1, 0}, '{1291, 1, 1},   //CH20..23
  '{1289, 1, 0}, '{1289, 1, 1},
  '{1291, 0, 0}, '{1291, 0, 1},
  '{1289, 0, 0}, '{1289, 0, 1},
  
  '{1291, 1, 2}, '{1291, 1, 3},   //CH24..27
  '{1291, 1, 6}, '{1291, 1, 7},
  '{1291, 0, 2}, '{1291, 0, 3},
  '{1291, 0, 6}, '{1291, 0, 7},
  
  '{1290, 1, 2}, '{1290, 1, 3},   //CH28..31
  '{1290, 1, 6}, '{1290, 1, 7},
  '{1290, 0, 2}, '{1290, 0, 3},
  '{1290, 0, 6}, '{1290, 0, 7},
  
  '{1289, 1, 2}, '{1289, 1, 3},   //CH32..35
  '{1289, 1, 6}, '{1289, 1, 7},
  '{1289, 0, 2}, '{1289, 0, 3},
  '{1289, 0, 6}, '{1289, 0, 7},
  
  '{1288, 1, 2}, '{1288, 1, 3},   //CH36..39
  '{1288, 1, 6}, '{1288, 1, 7},
  '{1288, 0, 2}, '{1288, 0, 3},
  '{1288, 0, 6}, '{1288, 0, 7}
  
};

Serialization_table ST1 [0:79] = '{     //Serialization table from LUX13HS datasheet for  D2, D3 
//Left top
      //2j     //2j + 1
  '{0, 0, 8}, '{0, 0, 9},   //CH0..3
  '{0, 0, 4}, '{0, 0, 5},
  '{0, 1, 8}, '{0, 1, 9},
  '{0, 1, 4}, '{0, 1, 5},
  
  '{1, 0, 8}, '{1, 0, 9},   //CH4..7
  '{1, 0, 4}, '{1, 0, 5},
  '{1, 1, 8}, '{1, 1, 9},
  '{1, 1, 4}, '{1, 1, 5},
  
  '{2, 0, 8}, '{2, 0, 9},   //CH8..11
  '{2, 0, 4}, '{2, 0, 5},
  '{2, 1, 8}, '{2, 1, 9},
  '{2, 1, 4}, '{2, 1, 5},
  
  '{3, 0, 8}, '{3, 0, 9},   //CH12..15
  '{3, 0, 4}, '{3, 0, 5},
  '{3, 1, 8}, '{3, 1, 9},
  '{3, 1, 4}, '{3, 1, 5},
  
  '{0, 0, 0}, '{0, 0, 1},   //CH16..19
  '{2, 0, 0}, '{2, 0, 1},
  '{0, 1, 0}, '{0, 1, 1},
  '{2, 1, 0}, '{2, 1, 1},
  
//Right top
  '{1290, 1, 0}, '{1290, 1, 1},   //CH20..23
  '{1288, 1, 0}, '{1288, 1, 1},
  '{1290, 0, 0}, '{1290, 0, 1},
  '{1288, 0, 0}, '{1288, 0, 1},
  
  '{1291, 1, 4}, '{1291, 1, 5},   //CH24..27
  '{1291, 1, 8}, '{1291, 1, 9},
  '{1291, 0, 4}, '{1291, 0, 5},
  '{1291, 0, 8}, '{1291, 0, 9},
  
  '{1290, 1, 4}, '{1290, 1, 5},   //CH28..31
  '{1290, 1, 8}, '{1290, 1, 9},
  '{1290, 0, 4}, '{1290, 0, 5},
  '{1290, 0, 8}, '{1290, 0, 9},
  
  '{1289, 1, 4}, '{1289, 1, 5},   //CH32..35
  '{1289, 1, 8}, '{1289, 1, 9},
  '{1289, 0, 4}, '{1289, 0, 5},
  '{1289, 0, 8}, '{1289, 0, 9},
  
  '{1288, 1, 4}, '{1288, 1, 5},   //CH36..39
  '{1288, 1, 8}, '{1288, 1, 9},
  '{1288, 0, 4}, '{1288, 0, 5},
  '{1288, 0, 8}, '{1288, 0, 9}
  
};


endmodule
