`timescale 1ns / 1ps

module LUX13HS_ADC_readout#(
    parameter  max_number_rows    = 24,
    parameter  max_number_columns = 24
)(
    input logic [79:0]    CH_p,         //80 data channels from LUX13HS
    input logic [79:0]    CH_n,
    input logic           Pclk_p,       // 133MHz data clock from LUX13HS
    input logic           Pclk_n,
    output logic          Pclk, 

    
    input logic [8:0]     row_address,    
    input logic           st_readb_n,
    input logic           st_readt_n,
    input logic           st_rowb_n,
    input logic           st_rowt_n,
    input logic           clk200,
    input logic           clk300,
    input logic           rst,
    input logic           clk,
   

    output logic          sending_data_active,
    
    output logic [7:0]    s_axis_tdata_udp,
    output logic          s_axis_tvalid_udp,
    output logic          s_axis_tlast_udp,
    input  logic          s_axis_tready_udp,
    
    input logic           clk_read_fifo,

    output logic          row_done,

    input logic           correction_mode,
    input logic           row_frame_mode
    );

localparam  focal_width  = 20;                                                        //focal_width of focal spot
localparam  focal_height = 20;     
logic [79:0] CH_bufds;
logic [79:0] CH_idelay;

/* 
There are three singnals which I pass from module LUX13HS_control (domain 'Pclk') to domain 'Pclk_x4_shifted' in this module.
These signals are 'st_readb_n', 'st_readt_n' and 'row_address'. The signals 'st_readb_n' and 'st_readt_n' are use for control of starting 
readout: when they have changed I check the 'row_address' and calculate my internal addresses 'row_address_bot' and 'row_address_top'. 
I do synchronization for 'st_readb_n' and 'st_readt_n' only because 'row_address' changes very slowly and long time before changing 
'st_readb_n' and 'st_readt_n'. So, I suppose that 'row_address' have quite relaxed to this moment.

The same situation is with 'read_bot_locked' singnal which is used between full frame sequential readings to stop internal counting.
The moment when it is setting is 'enable_read_bot_strb_del' and 'row_address' must be relaxed to this time.
So I expect that I can use 'set_clock_groups -asynchronous' constraint between 'Pclk' and 'Pclk_x4_shifted' domains.

NOTICE: It's seems more safety and simple to move LUX13HS_control from 'Pclk' domain to 'Pclk_x4_shifted' domain to workaround this problem.
 */
/********************************************************************/
/*                                                                  */
/*                  CLOCKING WIZARD 2xPclk                          */
/*                                                                  */
/********************************************************************/    
clk_wiz_2xPclk clk_wiz_2xPclk (
    .clk_out3(Pclk_x4_shifted), //533MHz
    .clk_out4(Pclk),            //133MHz
    .locked(locked),       
    .clk_in1_p(Pclk_p),    // input clk_in1_p
    .clk_in1_n(Pclk_n)    // input clk_in1_n    // input clk_in1_p

);     

/********************************************************************/
/*                                                                  */
/*                         IDELAYCTRL                               */
/*                                                                  */
/********************************************************************/    
logic rst_idealy;
    always @ (posedge clk300) rst_idealy <= rst;

    IDELAYCTRL #(
        .SIM_DEVICE("ULTRASCALE")  // Must be set to "ULTRASCALE" 
    )
    IDELAYCTRL_inst (
        .RDY(), // 1-bit output: Ready output
        .REFCLK(clk300), // 1-bit input: Reference clock input
        .RST(rst_idealy) // 1-bit input: Active high reset input
    );

/********************************************************************/
/*                                                                  */
/*                    LUX13HS_ADC CHANNELS                          */
/*                                                                  */
/********************************************************************/    
genvar i;
generate
    for (i = 0; i < 80; i=i+1) begin: ibufds_ch
    
        IBUFDS IBUFDS_CH (
            .O(CH_bufds[i]),                 // Buffer output
            .I(CH_p[i]),                     // Diff_p buffer input (connect directly to top-level port)
            .IB(CH_n[i])                     // Diff_n buffer input (connect directly to top-level port)
        );

        IDELAYE3 #(
            .CASCADE("NONE"),               // Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
            .DELAY_FORMAT("TIME"),          // Units of the DELAY_VALUE (COUNT, TIME)
            .DELAY_SRC("IDATAIN"),          // Delay input (DATAIN, IDATAIN)
            .DELAY_TYPE("FIXED"),           // Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
            .DELAY_VALUE(0),                // Input delay value setting
            .IS_CLK_INVERTED(1'b0),         // Optional inversion for CLK
            .IS_RST_INVERTED(1'b0),         // Optional inversion for RST
            .REFCLK_FREQUENCY(300.0),       // IDELAYCTRL clock input frequency in MHz (200.0-2667.0)
            .SIM_DEVICE("ULTRASCALE"), // Set the device version (ULTRASCALE, ULTRASCALE_PLUS,
                                        // ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
            .UPDATE_MODE("ASYNC")           // Determines when updates to the delay will take effect (ASYNC, MANUAL,   
        )

        IDELAYE3_CH (
            .CASC_OUT(),       // 1-bit output: Cascade delay output to ODELAY input cascade
            .CNTVALUEOUT(), // 9-bit output: Counter value output
            .DATAOUT(CH_idelay[i]),         // 1-bit output: Delayed data output
            .CASC_IN(1'b0),         // 1-bit input: Cascade delay input from slave ODELAY CASCADE_OUT
            .CASC_RETURN(1'b0), // 1-bit input: Cascade delay returning from slave ODELAY DATAOUT
            .CE(1'b0),                   // 1-bit input: Active-High enable increment/decrement input
            .CLK(1'b0),                 // 1-bit input: Clock input
            .CNTVALUEIN(9'b0),   // 9-bit input: Counter value input
            .DATAIN(1'b0),           // 1-bit input: Data input from the logic
            .EN_VTC(1'b1),           // 1-bit input: Keep delay constant over VT
            .IDATAIN(CH_bufds[i]),         // 1-bit input: Data input from the IOBUF
            .INC(1'b0),                 // 1-bit input: Increment / Decrement tap delay input
            .LOAD(1'b0),               // 1-bit input: Load DELAY_VALUE input
            .RST(1'b0)                  // 1-bit input: Asynchronous Reset to the DELAY_VALUE
        );

       
  
    end
endgenerate

/********************************************************************/
/*                                                                  */
/*                    DATA DESERIALIZATION                          */
/*                                                                  */
/********************************************************************/   
//Serialization table structure
typedef struct packed { 
  logic[1:0] column;
  logic row_offset;
  logic[3:0] bit_number;
} Serialization_table;
/*
For the purpose of serialization data coming from matrix the Serialization table is used.
For the fisrt 2 clocks of one row reading that takes 162 clock the Serialization table has specific view.
Other serliazation rules for clocks (3-162) can be obtained from these two specific rules for clocks 1 and 2  by adding or substraction a constant offset of number of columns that is 4 columns:

//reading left side of row:
Clk1        Clk2        Clk3        Clk4            Clk199      Clk162
C0- C3      C4- C7      C644- 647   C640- 643  ...  C12- C15    C8- C11

//reading right side of row:
Clk1        Clk2        Clk3        Clk4            Clk199      Clk162
C1288-3  C1292-1295  C648-651    C652- 655   ... C1280-1283  C1284-1287

In addition  there is one another Serializaion table that used for data D2,D3.
*/
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
  '{3, 1, 0}, '{3, 1, 1},   //CH20..23
  '{1, 1, 0}, '{1, 1, 1},
  '{3, 0, 0}, '{3, 0, 1},
  '{1, 0, 0}, '{1, 0, 1},
  
  '{3, 1, 2}, '{3, 1, 3},   //CH24..27
  '{3, 1, 6}, '{3, 1, 7},
  '{3, 0, 2}, '{3, 0, 3},
  '{3, 0, 6}, '{3, 0, 7},
  
  '{2, 1, 2}, '{2, 1, 3},   //CH28..31
  '{2, 1, 6}, '{2, 1, 7},
  '{2, 0, 2}, '{2, 0, 3},
  '{2, 0, 6}, '{2, 0, 7},
  
  '{1, 1, 2}, '{1, 1, 3},   //CH32..35
  '{1, 1, 6}, '{1, 1, 7},
  '{1, 0, 2}, '{1, 0, 3},
  '{1, 0, 6}, '{1, 0, 7},
  
  '{0, 1, 2}, '{0, 1, 3},   //CH36..39
  '{0, 1, 6}, '{0, 1, 7},
  '{0, 0, 2}, '{0, 0, 3},
  '{0, 0, 6}, '{0, 0, 7}
  
};

Serialization_table ST1 [0:79] = '{     //Serialization table from LUX13HS datasheet for  D2, D3 
//Left top
    //2j,D2    //2j + 1,D3
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
  '{2, 1, 0}, '{2, 1, 1},   //CH20..23
  '{0, 1, 0}, '{0, 1, 1},
  '{2, 0, 0}, '{2, 0, 1},
  '{0, 0, 0}, '{0, 0, 1},
  
  '{3, 1, 4}, '{3, 1, 5},   //CH24..27
  '{3, 1, 8}, '{3, 1, 9},
  '{3, 0, 4}, '{3, 0, 5},
  '{3, 0, 8}, '{3, 0, 9},
  
  '{2, 1, 4}, '{2, 1, 5},   //CH28..31
  '{2, 1, 8}, '{2, 1, 9},
  '{2, 0, 4}, '{2, 0, 5},
  '{2, 0, 8}, '{2, 0, 9},
  
  '{1, 1, 4}, '{1, 1, 5},   //CH32..35
  '{1, 1, 8}, '{1, 1, 9},
  '{1, 0, 4}, '{1, 0, 5},
  '{1, 0, 8}, '{1, 0, 9},
  
  '{0, 1, 4}, '{0, 1, 5},   //CH36..39
  '{0, 1, 8}, '{0, 1, 9},
  '{0, 0, 4}, '{0, 0, 5},
  '{0, 0, 8}, '{0, 0, 9}
  
};


(* MAX_FANOUT = 50 *) logic [8:0] row_address_top = 'd511, row_address_bot = 'd511;
//bot
reg [9:0] sample_left_bot[0:3][1:0] = '{default:10'd0};
reg [9:0] sample_right_bot[0:3][1:0] = '{default:10'd0};
reg [9:0] sample_left_bot_buf1[0:max_number_columns]  [0:3][1:0] = '{default:10'd0};
reg [9:0] sample_right_bot_buf1[0:max_number_columns] [0:3][1:0] = '{default:10'd0};

//top
reg [9:0] sample_left_top[0:3][1:0] = '{default:10'd0};   //[number_column]_[number_row]_[ADC_10bits]; number of column incremented by cnt_bot_Pclk or cnt_top_Pclk, depending of reading way
reg [9:0] sample_right_top [0:3][1:0] = '{default:10'd0};
reg [9:0] sample_left_top_q  [3:0][1:0] = '{default:10'd0};   
reg [9:0] sample_right_top_q [3:0][1:0] = '{default:10'd0};
reg [9:0] sample_left_top_qq  [3:0][1:0] = '{default:10'd0};   
reg [9:0] sample_right_top_qq [3:0][1:0] = '{default:10'd0};
reg [9:0] sample_left_top_buf1[0:max_number_columns] [0:3][1:0] = '{default:10'd0};   
reg [9:0] sample_right_top_buf1[0:max_number_columns][0:3][1:0] = '{default:10'd0};

/*
There is a delay between pulses !st_readb_n or !st_readt_n and data out. It's not exactly known and about 3-4 clocks as described in LUX13HS datasheet.
I want to use the condition of cnt_bot_Pclk == 0 or cnt_top_Pclk == 0 to count this delay.                            
I will try to start with 3 clocks delay.                                                                              
*/
logic [9:0] cnt_bot_Pclk = 0;
logic [9:0] cnt_top_Pclk = 0;
logic [7:0] cnt_top_Pclk_real;
logic [7:0] cnt_bot_Pclk_real;
logic [7:0] cnt_top_Pclk_real_shifted;
logic [7:0] cnt_bot_Pclk_real_shifted;
assign cnt_top_Pclk_real = cnt_top_Pclk[9:2];
assign cnt_bot_Pclk_real = cnt_bot_Pclk[9:2];
logic [1:0] enable_cnt_delay_bot = 'd3, enable_cnt_delay_top = 'd3;
logic [3:0] cnt_delay_bot = 0;
logic [3:0] cnt_delay_top = 0;
logic read_bot_locked = 0;
logic read_top_locked = 0;

(* MAX_FANOUT = 50 *)  logic enable_read_bot, enable_read_top;
logic enable_read_bot_del, enable_read_top_del, enable_read_top_del2, enable_read_top_del3;
logic enable_read_bot_strb, enable_read_bot_strb_del, enable_read_top_strb;
assign enable_read_bot_strb = !enable_read_bot && enable_read_bot_del;
assign enable_read_top_strb = !enable_read_top_del2 && enable_read_top_del3;

logic read_ram_b_en = 0;
logic read_finished;
logic [1:0] st_readb_n_sync, st_readt_n_sync;
//reading control
always @ (posedge Pclk_x4_shifted) begin
    cnt_bot_Pclk_real_shifted <= cnt_bot_Pclk_real;
    cnt_top_Pclk_real_shifted <= cnt_top_Pclk_real;
    st_readb_n_sync <= {st_readb_n_sync[0],st_readb_n};
    st_readt_n_sync <= {st_readt_n_sync[0],st_readt_n};
//process st_readb_n
    if (enable_cnt_delay_bot == 0 && !read_ram_b_en) begin 
        cnt_bot_Pclk <= cnt_bot_Pclk + 1; 
    end
    if (!st_readb_n_sync[1]) begin 
        read_bot_locked <= 0;
        enable_cnt_delay_bot <= 1;
        if (row_address == 'd511) row_address_bot <= 'd430; else row_address_bot <= row_address-2; 
        cnt_bot_Pclk <= 0; 
    end  
    if (enable_cnt_delay_bot == 1) begin 
        if (cnt_delay_bot == 'd12) begin  enable_cnt_delay_bot <= 0; cnt_delay_bot <= 0; end 
        else  cnt_delay_bot <= cnt_delay_bot + 1;
    end 
//process st_readt_n
    if (enable_cnt_delay_top == 0 && !read_ram_b_en) begin cnt_top_Pclk <= cnt_top_Pclk + 1;  end 
    if (!st_readt_n_sync[1]) begin 
        read_top_locked <= 0;
        enable_cnt_delay_top <= 1;
        if (row_address == 'd511) row_address_top <= 'd431; else row_address_top <= row_address-2; 
        cnt_top_Pclk <= 0; 
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
    s_axis_tlast_del <= s_axis_tlast;
end

logic cnt_bot_enable = 0, cnt_top_enable = 0, cnt_bot_enable2 = 0, cnt_top_enable2 = 0;
logic cnt_bot_enable2_q , cnt_top_enable2_q, cnt_bot_enable_q, cnt_top_enable_q;

/* I dont want to read the dark columns on the edges of matrix, so I pass the clock numbers 1 and 2 of full 162 clocks.
For this purpose I need to adjust delay of pipeine for enable_read_bot/top to start reading from 3d clock*/
always_ff @ (posedge Pclk_x4_shifted) begin
    cnt_bot_enable2 <= (cnt_bot_Pclk > 4 && cnt_bot_Pclk < 645); //
    cnt_top_enable2 <= (cnt_top_Pclk > 4 && cnt_top_Pclk < 645);
    cnt_bot_enable  <= (!read_bot_locked && row_address_bot <= 'd430);
    cnt_top_enable  <= (!read_top_locked && row_address_top <= 'd431);

    cnt_bot_enable2_q <= cnt_bot_enable2;
    cnt_top_enable2_q <= cnt_top_enable2;
    cnt_bot_enable_q  <= cnt_bot_enable;
    cnt_top_enable_q  <= cnt_top_enable;

    enable_read_bot <= cnt_bot_enable2_q && cnt_bot_enable_q;
    enable_read_top <= cnt_top_enable2_q && cnt_top_enable_q;
end

// assign enable_read_bot = (!read_bot_locked && row_address_bot <= 'd430 && cnt_bot_Pclk > 8 && cnt_bot_Pclk < 649)? 1 :0;
// assign enable_read_top = (!read_top_locked && row_address_top <= 'd431 && cnt_top_Pclk > 8 && cnt_top_Pclk < 649)? 1 :0;
logic D_togl_bot[0:39] = '{default:1'd0};
logic D_togl_top[0:39] = '{default:1'd0};
logic [1:0] D_cnt_bot[0:max_number_columns] = '{default:2'd3};
logic [1:0] D_cnt_top[0:max_number_columns] = '{default:3'd3};
logic [1:0] D_cnt_top_q = '{default:2'd3};
logic [1:0] D_cnt_top_qq = '{default:2'd3};
(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "no" *) logic Pclk_sync1, Pclk_sync2, Pclk_sync3, Pclk_sync4;


//Deserialization pipeline
logic [10:0] column_reg_bot[0:39];
logic        row_offset_reg_bot[0:39];
logic [3:0]  bit_number_reg_bot[0:39];
logic [10:0] column_dynamic_offset_bot;
logic [10:0] column_reg_top[0:39];
logic        row_offset_reg_top[0:39];
logic [3:0]  bit_number_reg_top[0:39];
logic [10:0] column_dynamic_offset_top;
logic [39:0] CH_data_bot_q, CH_data_top_q, CH_data_bot_qq, CH_data_top_qq;
(* MAX_FANOUT = 50 *)  logic enable_read_bot_q, enable_read_top_q, enable_read_bot_q1, enable_read_bot_q2,enable_read_bot_q3, enable_read_bot_q4, enable_read_bot_q5, 
                            enable_read_top_q1, enable_read_top_q2, enable_read_top_q3, enable_read_top_q4,enable_read_top_q5, enable_read_top_q7;
                            
(* DONT_TOUCH = "TRUE" *)logic enable_read_bot_q6 [0:max_number_columns] , enable_read_top_q6[0:max_number_columns];
logic Pclk_sync4_q [0:39];
logic [4:0] sample_ready_bot = 5'b00001;
logic [4:0] sample_ready_top = 5'b00001;

logic [9:0] Sample_cnt_left_bot[0:max_number_columns]     = '{default:'d652};
logic [10:0] Sample_cnt_right_bot[0:max_number_columns]   = '{default:'d640};
logic [9:0] Sample_cnt_left_top[0:max_number_columns]     = '{default:'d652};
logic [10:0] Sample_cnt_right_top[0:max_number_columns]  = '{default:'d640};

always_ff @ (posedge Pclk_x4_shifted) begin
    
    Pclk_sync1 <= Pclk;
    Pclk_sync2 <= Pclk_sync1;
    Pclk_sync3 <= Pclk_sync2;
    Pclk_sync4 <= Pclk_sync3;
    
    enable_read_bot_q <= enable_read_bot;
    enable_read_top_q <= enable_read_top;
    enable_read_bot_q1 <= enable_read_bot_q;
    enable_read_bot_q2 <= enable_read_bot_q1;
    enable_read_bot_q3 <= enable_read_bot_q2;
    enable_read_bot_q4 <= enable_read_bot_q3;
    enable_read_bot_q5 <= enable_read_bot_q4;
    for (int c = 0; c < max_number_columns + 1; c++) enable_read_bot_q6[c] <= enable_read_bot_q5;

    enable_read_top_q1 <= enable_read_top_q;
    enable_read_top_q2 <= enable_read_top_q1;
    enable_read_top_q3 <= enable_read_top_q2;
    enable_read_top_q4 <= enable_read_top_q3;
    enable_read_top_q5 <= enable_read_top_q4;
    for (int c = 0; c < max_number_columns + 1; c++)  enable_read_top_q6[c] <= enable_read_top_q5;
   // enable_read_top_q7 <= enable_read_top_q6;

    //Bottom_stage0
    //if (enable_read_bot & row_address_bot != 'd511) begin                                                 
        for (int j = 0; j < 40; j++) begin  
            CH_data_bot_q[j] <= CH_idelay[j];
            Pclk_sync4_q[j] <= Pclk_sync4;
        end
    //end
    //Bottom_stage1
    if ((enable_read_bot_q | enable_read_bot_q2) /* & row_address_bot != 'd511 */) begin                                                 
        for (int j = 0; j < 40; j++) begin  
           // for (int k = 0; k < max_number_columns + 1; k++) begin
            //left
                if (j < 20) begin
                    if (Pclk_sync4_q[j]) begin  //D1,D0   
                        //D1
                        if (D_togl_bot[j]) sample_left_bot[ST0[2*j + 1].column][ST0[2*j + 1].row_offset][ST0[2*j + 1].bit_number] <= CH_data_bot_q[j];
                        //D0
                        else sample_left_bot[ST0[2*j + 0].column][ST0[2*j + 0].row_offset][ST0[2*j + 0].bit_number] <= CH_data_bot_q[j];
                    end
                    //D3,D2  
                    else begin
                        //D3
                        if (D_togl_bot[j]) sample_left_bot[ST1[2*j + 1].column][ST1[2*j + 1].row_offset][ST1[2*j + 1].bit_number] <= CH_data_bot_q[j];               
                        //D2
                        else sample_left_bot[ST1[2*j + 0].column][ST1[2*j + 0].row_offset][ST1[2*j + 0].bit_number] <= CH_data_bot_q[j];       
                    end
                end
                //right
                else begin
                    if (Pclk_sync4_q[j]) begin  //D1,D0   
                        //D1
                        if (D_togl_bot[j]) sample_right_bot[ST0[2*j + 1].column][ST0[2*j + 1].row_offset][ST0[2*j + 1].bit_number] <= CH_data_bot_q[j];
                        //D0
                        else sample_right_bot[ST0[2*j + 0].column][ST0[2*j + 0].row_offset][ST0[2*j + 0].bit_number] <= CH_data_bot_q[j];
                    end
                    //D3,D2  
                    else begin
                        //D3
                        if (D_togl_bot[j]) sample_right_bot[ST1[2*j + 1].column][ST1[2*j + 1].row_offset][ST1[2*j + 1].bit_number] <= CH_data_bot_q[j];               
                        //D2
                        else sample_right_bot[ST1[2*j + 0].column][ST1[2*j + 0].row_offset][ST1[2*j + 0].bit_number] <= CH_data_bot_q[j];       
                    end
                end
            //end
            D_togl_bot[j] <= D_togl_bot[j] + 1;
        end 
        for (int k = 0; k < max_number_columns + 1; k++) begin
            D_cnt_bot[k] <= D_cnt_bot[k] + 1;
            X_left_bot[k] <= X_left_bot[k] + 1;
            X_right_bot[k] <= X_right_bot[k] + 1;
            sample_left_bot_buf1[k] <= '{ sample_left_bot_buf1[k][1], sample_left_bot_buf1[k][2], sample_left_bot_buf1[k][3], '{10'd0, 10'd0}};
            sample_right_bot_buf1[k] <= '{ sample_right_bot_buf1[k][1], sample_right_bot_buf1[k][2], sample_right_bot_buf1[k][3], '{10'd0, 10'd0}};
            if (D_cnt_bot[k] == 3) begin 
                //left
                sample_left_bot_buf1[k] <= sample_left_bot;     
                X_left_bot[k] <= X_left_bot[k] - 7;
                //right
                sample_right_bot_buf1[k]  <= sample_right_bot;
                //Sample_cnt_right_bot[k] <= Sample_cnt_right_bot[k] + 4;
            end
        end
    end
    else if (!enable_read_bot_q2) begin 
        for (int k = 0; k < max_number_columns + 1; k++) begin
            D_cnt_bot[k] <= 3; 
            X_left_bot[k]  <= 'd655;
            X_right_bot[k] <= 'd643;
        end
    end


    //Top_stage0
    //if (enable_read_top & row_address_top != 'd511) begin                                                 
        for (int j = 0; j < 40; j++) begin  
            CH_data_top_q[j] <= CH_idelay[j+40];
        end
    //end
    //Top_stage1
    if ((enable_read_top_q |enable_read_top_q4)/* & row_address_top != 'd511 */) begin                                                 
        for (int j = 0; j < 40; j++) begin  
            //for (int k = 0; k < max_number_columns; k++) begin
            //left
                if (j < 20) begin
                    if (Pclk_sync4_q[j]) begin  //D1,D0   
                        //D1
                        if (D_togl_top[j]) sample_left_top[ST0[2*j + 1].column][ST0[2*j + 1].row_offset][ST0[2*j + 1].bit_number] <= CH_data_top_q[j];
                        //D0
                        else sample_left_top[ST0[2*j + 0].column][ST0[2*j + 0].row_offset][ST0[2*j + 0].bit_number] <= CH_data_top_q[j];
                    end
                    //D3,D2  
                    else begin
                        //D3
                        if (D_togl_top[j]) sample_left_top[ST1[2*j + 1].column][ST1[2*j + 1].row_offset][ST1[2*j + 1].bit_number] <= CH_data_top_q[j];               
                        //D2
                        else sample_left_top[ST1[2*j + 01].column][ST1[2*j + 0].row_offset][ST1[2*j + 0].bit_number] <= CH_data_top_q[j];       
                    end
                end
                //right
                else begin
                    if (Pclk_sync4_q[j]) begin  //D1,D0   
                        //D1
                        if (D_togl_top[j]) sample_right_top[ST0[2*j + 1].column][ST0[2*j + 1].row_offset][ST0[2*j + 1].bit_number] <= CH_data_top_q[j];
                        //D0
                        else sample_right_top[ST0[2*j + 0].column][ST0[2*j + 0].row_offset][ST0[2*j + 0].bit_number] <= CH_data_top_q[j];
                    end
                    //D3,D2  
                    else begin
                        //D3
                        if (D_togl_top[j]) sample_right_top[ST1[2*j + 1].column][ST1[2*j + 1].row_offset][ST1[2*j + 1].bit_number] <= CH_data_top_q[j];               
                        //D2
                        else sample_right_top[ST1[2*j + 01].column][ST1[2*j + 0].row_offset][ST1[2*j + 0].bit_number] <= CH_data_top_q[j];       
                    end
                end
         //   end
            D_togl_top[j] <= D_togl_top[j] + 1;
        end
        for (int k = 0; k < max_number_columns + 1; k++) begin
            D_cnt_top[k] <= D_cnt_top[k] + 1;
            X_left_top[k] <= X_left_top[k] + 1;
            X_right_top[k] <= X_right_top[k] + 1;
            sample_left_top_buf1[k] <= '{ sample_left_top_buf1[k][1], sample_left_top_buf1[k][2], sample_left_top_buf1[k][3], '{10'd0, 10'd0}};
            sample_right_top_buf1[k] <= '{ sample_right_top_buf1[k][1], sample_right_top_buf1[k][2], sample_right_top_buf1[k][3], '{10'd0, 10'd0}};
            if (D_cnt_top[k] == 3) begin
                //left
                sample_left_top_buf1[k] <= sample_left_top;    
                X_left_top[k] <= X_left_top[k] - 7;
                //right
                sample_right_top_buf1[k]  <= sample_right_top;
                //Sample_cnt_right_top[k] <= Sample_cnt_right_top[k] + 4;
            end
        end

    end
    else if (!enable_read_top_q4) begin 
        for (int k = 0; k < max_number_columns + 1; k++) begin
            D_cnt_top[k] <= 3; 
            X_left_top[k] <= 'd655;
            X_right_top[k] <= 'd643;
        end
    end
end

/* 
'sample_left_bot', 'sample_right_bot', 'sample_left_top', 'sample_right_top' are double samples with pixels values D0,D1,D2,D3 from LUX13HS datasheet.
This samples are temporary because each cycle of data clock (533MHz) new values of some bits inside this samples are catching.
From another hand the buffers '*_buf1' are stoaring their values of pixels inside one period of sample clock (133MHz). I use this fact for safty calculations of values
I, Ix, Iy by using this constant values of '*_buf1'. 

More precisely after getting the first constant value of '*_buf1' I shift it each cycle of data clock and so I have each cycle a correct value of pixel D0,D1,D2 or D3. 
The X_left_bot, X_right_bot, X_left_top, X_right_top regs are corresponding values of X-coor for each shifted pixel. So I have synchronized pairs of pixels and X-coors values.
The situation with Y-coors is slightly different because Y-coor are changed more slowly than X-coor (in fact Y-coors are changed when reading of new row is statring and remain
constant until next row rolling). But it needs to be carefull here too do not synchronization between pixels and correspondent Y-coors values are corrupted especially at the 
starting and ending of row reading.
*/

logic [$clog2(focal_height*focal_width*1023*2047)-1:0] sum_Ix [0:max_number_columns];  // 30 bits 
logic [$clog2(focal_height*focal_width*1023*2047)-1:0] sum_Iy [0:max_number_columns];  // 30 bits
logic [$clog2(focal_height*focal_width*1023)-1:0]      sum_I  [0:max_number_columns];  // 19 bits

logic[24:0] active_row_bot_0_arr = 0; 
logic[24:0] active_row_bot_1_arr = 0; 
logic[24:0] active_row_top_0_arr = 0; 
logic[24:0] active_row_top_1_arr = 0; 

logic active_row_bot_0 = 0; 
logic active_row_bot_1 = 0; 
logic active_row_top_0 = 0; 
logic active_row_top_1 = 0; 
logic active_row_bot_0_pre = 0; 
logic active_row_bot_1_pre = 0; 
logic active_row_top_0_pre = 0; 
logic active_row_top_1_pre = 0; 
logic active_row_pre = 0;
logic active_row = 0; 
logic active_row_del = 0; 


logic [4:0] temp_r = 0;
logic [4:0] temp_r_rep [0:max_number_columns] = '{default : 0};
logic [4:0] temp_r_rep_1 [0:max_number_columns] = '{default : 0};



//Detecting whether the current matrix string contains pixels of the current row of spots and activate this row of spots.
logic [9:0] Y_coor_top_edge = 0; 
logic [9:0] Y_coor_bot_edge = 0; 
logic Y_coor_top_edge_bot_0_check = 0;
logic Y_coor_bot_edge_bot_0_check = 0;
logic Y_coor_top_edge_bot_1_check = 0;
logic Y_coor_bot_edge_bot_1_check = 0;
logic Y_coor_top_edge_top_0_check = 0;
logic Y_coor_bot_edge_top_0_check = 0;
logic Y_coor_top_edge_top_1_check = 0;
logic Y_coor_bot_edge_top_1_check = 0;
logic [4:0] temp_r_active_row_check = 0;

always_ff @(posedge Pclk_x4_shifted) begin
/* 
Here I check if reading at this moment row of matrix belongs to some line of spots. If so I mark this row of matrix as active otherwise no.
When my currnet active row is finished I increment the index of spots line to use the next one for checking the activity of rows.
I assume that bot of line has a 'Y-coor' = 'Y-coor of top' + focal_height. 
*/

/* 
'row_address_bot' and 'row_address_top' range from 0 to 431 (even - bot, odd - top). But the matrix has 864 rows. This is because reading is executed by two
rows at the same time, so called double row.  So if I want to now real index of row I need to double the values of 'row_address_bot' and 'row_address_top'. 
And more over, if I want to address of second row of double row I need to plus 1. This is achived by shifting left and set LSB t0 0 or 1.
 */
        Y_coor_top_edge <= Y_coor[temp_r_active_row_check];
        Y_coor_bot_edge <= Y_coor[temp_r_active_row_check] + focal_height;

        Y_coor_top_edge_bot_0_check <= ({row_address_bot, 1'b0} >= Y_coor_top_edge);
        Y_coor_bot_edge_bot_0_check <= ({row_address_bot, 1'b0}  < Y_coor_bot_edge);

        Y_coor_top_edge_bot_1_check <= ({row_address_bot, 1'b1} >= Y_coor_top_edge);
        Y_coor_bot_edge_bot_1_check <= ({row_address_bot, 1'b1}  < Y_coor_bot_edge);

        Y_coor_top_edge_top_0_check<= ({row_address_top, 1'b0} >= Y_coor_top_edge);
        Y_coor_bot_edge_top_0_check <= ({row_address_top, 1'b0}  < Y_coor_bot_edge);

        Y_coor_top_edge_top_1_check <= ({row_address_top, 1'b1} >= Y_coor_top_edge);
        Y_coor_bot_edge_top_1_check <= ({row_address_top, 1'b1}  < Y_coor_bot_edge);

        active_row_bot_0_pre <= (Y_coor_top_edge_bot_0_check && Y_coor_bot_edge_bot_0_check);
        active_row_bot_1_pre <= (Y_coor_top_edge_bot_1_check && Y_coor_bot_edge_bot_1_check);
        active_row_top_0_pre <= (Y_coor_top_edge_top_0_check && Y_coor_bot_edge_top_0_check);
        active_row_top_1_pre <= (Y_coor_top_edge_top_1_check && Y_coor_bot_edge_top_1_check);

        active_row_bot_0 <= active_row_bot_0_pre;
        active_row_bot_1 <= active_row_bot_1_pre;
        active_row_top_0 <= active_row_top_0_pre;
        active_row_top_1 <= active_row_top_1_pre;


        if (active_row_bot_0 | active_row_bot_1 | active_row_top_0 | active_row_top_1) active_row_pre <= 1;
        else active_row_pre <= 0;
        active_row <= active_row_pre;
        active_row_del <= active_row;
        if (!active_row & active_row_del) begin
            if (temp_r_active_row_check < max_number_rows) temp_r_active_row_check <= temp_r_active_row_check + 1;
            else temp_r_active_row_check <= 0;
        end
end


//X-coor
logic [10:0] X_left_bot[0:max_number_columns]= '{default : 0}, X_right_bot[0:max_number_columns]= '{default : 0}, X_left_top[0:max_number_columns]= '{default : 0}, X_right_top[0:max_number_columns]= '{default : 0};
(* DONT_TOUCH = "TRUE" *) logic [10:0] X_left_bot_rep[0:max_number_columns]= '{default : 0}, X_right_bot_rep[0:max_number_columns]= '{default : 0}, 
                                       X_left_top_rep[0:max_number_columns]= '{default : 0}, X_right_top_rep[0:max_number_columns]= '{default : 0};

(* DONT_TOUCH = "TRUE" *) logic [10:0] X_left_bot_rep_q[0:max_number_columns]= '{default : 0}, X_right_bot_rep_q[0:max_number_columns]= '{default : 0}, 
                                       X_left_top_rep_q[0:max_number_columns]= '{default : 0}, X_right_top_rep_q[0:max_number_columns]= '{default : 0};
                          logic [10:0] X_left_bot_rep_qq[0:max_number_columns]= '{default : 0}, X_right_bot_rep_qq[0:max_number_columns]= '{default : 0}, 
                                       X_left_top_rep_qq[0:max_number_columns]= '{default : 0}, X_right_top_rep_qq[0:max_number_columns]= '{default : 0};
                          logic [10:0] X_left_bot_rep_qqq[0:max_number_columns]= '{default : 0}, X_right_bot_rep_qqq[0:max_number_columns]= '{default : 0}, 
                                                                                                 X_right_bot_rep_qqq_2_1[0:max_number_columns]= '{default : 0}, 

                                       X_left_top_rep_qqq[0:max_number_columns]= '{default : 0},        X_right_top_rep_qqq[0:max_number_columns]= '{default : 0},
                                       X_left_top_rep_qqq_3_1[0:max_number_columns]= '{default : 0},    X_right_top_rep_qqq_4_1[0:max_number_columns]= '{default : 0},
                                       X_left_top_rep_qqq_3_2[0:max_number_columns]= '{default : 0},    X_right_top_rep_qqq_4_2[0:max_number_columns]= '{default : 0},
                                                                                                        X_right_top_rep_qqq_4_3[0:max_number_columns]= '{default : 0};
//Sample
(* DONT_TOUCH = "TRUE" *) logic [9:0] sample_left_bot_buf1_0_rep[0:max_number_columns] = '{default : 0},  sample_left_bot_buf1_1_rep[0:max_number_columns] = '{default : 0}, 
                                      sample_right_bot_buf1_0_rep[0:max_number_columns] = '{default : 0}, sample_right_bot_buf1_1_rep[0:max_number_columns] = '{default : 0},
                                      sample_left_top_buf1_0_rep[0:max_number_columns] = '{default : 0},  sample_left_top_buf1_1_rep[0:max_number_columns] = '{default : 0}, 
                                      sample_right_top_buf1_0_rep[0:max_number_columns] = '{default : 0}, sample_right_top_buf1_1_rep[0:max_number_columns] = '{default : 0};

(* DONT_TOUCH = "TRUE" *) logic [9:0] sample_left_bot_buf1_0_rep_q[0:max_number_columns] = '{default : 0},  sample_left_bot_buf1_1_rep_q[0:max_number_columns] = '{default : 0}, 
                                      sample_right_bot_buf1_0_rep_q[0:max_number_columns] = '{default : 0}, sample_right_bot_buf1_1_rep_q[0:max_number_columns] = '{default : 0},
                                      sample_left_top_buf1_0_rep_q[0:max_number_columns] = '{default : 0},  sample_left_top_buf1_1_rep_q[0:max_number_columns] = '{default : 0}, 
                                      sample_right_top_buf1_0_rep_q[0:max_number_columns] = '{default : 0}, sample_right_top_buf1_1_rep_q[0:max_number_columns] = '{default : 0};

(* DONT_TOUCH = "TRUE" *) logic [9:0] sample_left_bot_buf1_0_rep_qq[0:max_number_columns] = '{default : 0},  sample_left_bot_buf1_1_rep_qq[0:max_number_columns] = '{default : 0}, 
                                      sample_right_bot_buf1_0_rep_qq[0:max_number_columns] = '{default : 0}, sample_right_bot_buf1_1_rep_qq[0:max_number_columns] = '{default : 0},
                                      sample_left_top_buf1_0_rep_qq[0:max_number_columns] = '{default : 0},  sample_left_top_buf1_1_rep_qq[0:max_number_columns] = '{default : 0}, 
                                      sample_right_top_buf1_0_rep_qq[0:max_number_columns] = '{default : 0}, sample_right_top_buf1_1_rep_qq[0:max_number_columns] = '{default : 0};

(* DONT_TOUCH = "TRUE" *) logic [9:0] sample_left_bot_buf1_0_rep_qq_msk_X[0:max_number_columns] = '{default : 0},           sample_left_bot_buf1_1_rep_qq_msk_X[0:max_number_columns] = '{default : 0},            
                                        sample_right_bot_buf1_0_rep_qq_msk_X[0:max_number_columns] = '{default : 0},        sample_right_bot_buf1_1_rep_qq_msk_X[0:max_number_columns] = '{default : 0},          
                                        sample_right_bot_buf1_0_rep_qq_msk_X_q[0:max_number_columns] = '{default : 0},      sample_right_bot_buf1_1_rep_qq_msk_X_q[0:max_number_columns] = '{default : 0},  
                                        sample_left_top_buf1_0_rep_qq_msk_X[0:max_number_columns] = '{default : 0},         sample_left_top_buf1_1_rep_qq_msk_X[0:max_number_columns] = '{default : 0},            
                                        sample_left_top_buf1_0_rep_qq_msk_X_q[0:max_number_columns] = '{default : 0},       sample_left_top_buf1_1_rep_qq_msk_X_q[0:max_number_columns] = '{default : 0},     
                                        sample_left_top_buf1_0_rep_qq_msk_X_qq[0:max_number_columns] = '{default : 0},      sample_left_top_buf1_1_rep_qq_msk_X_qq[0:max_number_columns] = '{default : 0},  
                                        sample_right_top_buf1_0_rep_qq_msk_X[0:max_number_columns] = '{default : 0},        sample_right_top_buf1_1_rep_qq_msk_X[0:max_number_columns] = '{default : 0},         
                                        sample_right_top_buf1_0_rep_qq_msk_X_q[0:max_number_columns] = '{default : 0},      sample_right_top_buf1_1_rep_qq_msk_X_q[0:max_number_columns] = '{default : 0},
                                        sample_right_top_buf1_0_rep_qq_msk_X_qq[0:max_number_columns] = '{default : 0},     sample_right_top_buf1_1_rep_qq_msk_X_qq[0:max_number_columns] = '{default : 0},
                                        sample_right_top_buf1_0_rep_qq_msk_X_qqq[0:max_number_columns] = '{default : 0},    sample_right_top_buf1_1_rep_qq_msk_X_qqq[0:max_number_columns] = '{default : 0},


                                        sample_left_bot_buf1_1_rep_qq_msk_Y[0:max_number_columns] = '{default : 0},         sample_left_bot_buf1_0_rep_qq_msk_Y[0:max_number_columns] = '{default : 0},           
                                        sample_right_bot_buf1_1_rep_qq_msk_Y[0:max_number_columns] = '{default : 0},        sample_right_bot_buf1_0_rep_qq_msk_Y[0:max_number_columns] = '{default : 0},          
                                        sample_right_bot_buf1_1_rep_qq_msk_Y_q[0:max_number_columns] = '{default : 0},      sample_right_bot_buf1_0_rep_qq_msk_Y_q[0:max_number_columns] = '{default : 0},    
                                        sample_left_top_buf1_1_rep_qq_msk_Y[0:max_number_columns] = '{default : 0},         sample_left_top_buf1_0_rep_qq_msk_Y[0:max_number_columns] = '{default : 0},    
                                        sample_left_top_buf1_1_rep_qq_msk_Y_q[0:max_number_columns] = '{default : 0},       sample_left_top_buf1_0_rep_qq_msk_Y_q[0:max_number_columns] = '{default : 0},   
                                        sample_left_top_buf1_1_rep_qq_msk_Y_qq[0:max_number_columns] = '{default : 0},      sample_left_top_buf1_0_rep_qq_msk_Y_qq[0:max_number_columns] = '{default : 0},          
                                        sample_right_top_buf1_1_rep_qq_msk_Y[0:max_number_columns] = '{default : 0},        sample_right_top_buf1_0_rep_qq_msk_Y[0:max_number_columns] = '{default : 0},         
                                        sample_right_top_buf1_1_rep_qq_msk_Y_q[0:max_number_columns] = '{default : 0},      sample_right_top_buf1_0_rep_qq_msk_Y_q[0:max_number_columns] = '{default : 0},       
                                        sample_right_top_buf1_1_rep_qq_msk_Y_qq[0:max_number_columns] = '{default : 0},     sample_right_top_buf1_0_rep_qq_msk_Y_qq[0:max_number_columns] = '{default : 0},       
                                        sample_right_top_buf1_1_rep_qq_msk_Y_qqq[0:max_number_columns] = '{default : 0},    sample_right_top_buf1_0_rep_qq_msk_Y_qqq[0:max_number_columns] = '{default : 0};                         

//Mask
(* DONT_TOUCH = "TRUE" *) logic mask_left_bot_0[0:max_number_columns] = '{default : 0},  mask_left_bot_1[0:max_number_columns] = '{default : 0}, 
                                mask_right_bot_0[0:max_number_columns] = '{default : 0}, mask_right_bot_1[0:max_number_columns] = '{default : 0},
                                mask_left_top_0[0:max_number_columns] = '{default : 0},  mask_left_top_1[0:max_number_columns] = '{default : 0}, 
                                mask_right_top_0[0:max_number_columns] = '{default : 0}, mask_right_top_1[0:max_number_columns] = '{default : 0};

/* (* DONT_TOUCH = "TRUE" *) logic q_mask_left_bot_0[0:max_number_columns] = '{default : 0},  q_mask_left_bot_1[0:max_number_columns] = '{default : 0}, 
                                q_mask_right_bot_0[0:max_number_columns] = '{default : 0}, q_mask_right_bot_1[0:max_number_columns] = '{default : 0},
                                q_mask_left_top_0[0:max_number_columns] = '{default : 0},  q_mask_left_top_1[0:max_number_columns] = '{default : 0}, 
                                q_mask_right_top_0[0:max_number_columns] = '{default : 0}, q_mask_right_top_1[0:max_number_columns] = '{default : 0};           */                     
//I
logic [9:0] sum_I_part_left_bot_0[0:max_number_columns] = '{default : 0},  sum_I_part_left_bot_1[0:max_number_columns] = '{default : 0}, 
            sum_I_part_right_bot_0[0:max_number_columns] = '{default : 0}, sum_I_part_right_bot_1[0:max_number_columns] = '{default : 0},
            sum_I_part_right_bot_0_q[0:max_number_columns] = '{default : 0}, sum_I_part_right_bot_1_q[0:max_number_columns] = '{default : 0},
            sum_I_part_left_top_0[0:max_number_columns] = '{default : 0},  sum_I_part_left_top_1[0:max_number_columns] = '{default : 0},
            sum_I_part_left_top_0_q[0:max_number_columns] = '{default : 0},  sum_I_part_left_top_1_q[0:max_number_columns] = '{default : 0}, 
            sum_I_part_left_top_0_qq[0:max_number_columns] = '{default : 0},  sum_I_part_left_top_1_qq[0:max_number_columns] = '{default : 0},  
            sum_I_part_right_top_0[0:max_number_columns] = '{default : 0}, sum_I_part_right_top_1[0:max_number_columns] = '{default : 0},
            sum_I_part_right_top_0_q[0:max_number_columns] = '{default : 0}, sum_I_part_right_top_1_q[0:max_number_columns] = '{default : 0},
            sum_I_part_right_top_0_qq[0:max_number_columns] = '{default : 0}, sum_I_part_right_top_1_qq[0:max_number_columns] = '{default : 0},
            sum_I_part_right_top_0_qqq[0:max_number_columns] = '{default : 0}, sum_I_part_right_top_1_qqq[0:max_number_columns] = '{default : 0};

 
logic [9:0] row_address_top_reg[0:max_number_columns] = '{default : 'd0}, row_address_bot_reg[0:max_number_columns] = '{default : 'd0};
logic [9:0] row_address_top_reg_rep[0:max_number_columns] = '{default : 'd0}, row_address_bot_reg_rep[0:max_number_columns] = '{default : 'd0}, row_address_bot_reg_rep_q[0:max_number_columns] = '{default : 'd0},  row_address_bot_reg_rep_qq[0:max_number_columns] = '{default : 'd0};
logic [9:0] row_address_top_reg1[0:max_number_columns] = '{default : 'd0}, row_address_bot_reg1[0:max_number_columns] = '{default : 'd0};
logic [9:0] row_address_top_reg1_rep[0:max_number_columns] = '{default : 'd0}, row_address_bot_reg1_rep[0:max_number_columns] = '{default : 'd0}, row_address_bot_reg1_rep_q[0:max_number_columns] = '{default : 'd0}, row_address_bot_reg1_rep_qq[0:max_number_columns] = '{default : 'd0};
logic [9:0] row_address_top_reg_rep1[0:max_number_columns] = '{default : 'd0}, row_address_top_reg_rep1_q[0:max_number_columns] = '{default : 'd0}, row_address_bot_reg_rep1[0:max_number_columns] = '{default : 'd0}, row_address_bot_reg_rep1_q[0:max_number_columns] = '{default : 'd0};
logic [9:0] row_address_top_reg1_rep1[0:max_number_columns] = '{default : 'd0}, row_address_top_reg1_rep1_q[0:max_number_columns] = '{default : 'd0},row_address_bot_reg1_rep1[0:max_number_columns] = '{default : 'd0}, row_address_bot_reg1_rep1_q[0:max_number_columns] = '{default : 'd0};



logic [10:0] X_coor_left_edge [0:max_number_columns] = '{default : 'd0}; 
logic [10:0] X_coor_right_edge [0:max_number_columns]= '{default : 'd0}; 

logic X_left_bot_left_side_check [0:max_number_columns] = '{default : 'd0}; 
logic X_left_bot_right_side_check[0:max_number_columns]= '{default : 'd0}; 
logic X_right_bot_left_side_check[0:max_number_columns]= '{default : 'd0};
logic X_right_bot_right_side_check[0:max_number_columns]= '{default : 'd0} ; 
logic X_left_top_left_side_check[0:max_number_columns]  = '{default : 'd0}; 
logic X_left_top_right_side_check[0:max_number_columns] = '{default : 'd0}; 
logic X_right_top_left_side_check[0:max_number_columns] = '{default : 'd0}; 
logic X_right_top_right_side_check[0:max_number_columns]= '{default : 'd0}; 
logic active_row_bot_0_rep [0:max_number_columns] = '{default : 0};
logic active_row_bot_1_rep [0:max_number_columns] = '{default : 0};
logic active_row_top_0_rep [0:max_number_columns] = '{default : 0};
logic active_row_top_1_rep [0:max_number_columns] = '{default : 0};
always_ff @ (posedge Pclk_x4_shifted) begin
    for (int b = 0; b < max_number_columns + 1; b++) begin
        temp_r_rep[b] <= temp_r;
        temp_r_rep_1[b] <= temp_r_rep[b];

        active_row_bot_0_rep[b] <= active_row_bot_0;
        active_row_bot_1_rep[b] <= active_row_bot_1;
        active_row_top_0_rep[b] <= active_row_top_0;
        active_row_top_1_rep[b] <= active_row_top_1;
    end


/*
At this moment the current value of element 'sample_left_bot_buf1[c][0]' is synchronized with the current value of 'X_left_bot' and other pairs are same. 
It means that value of 'sample_left_bot_buf1[c][0]' comes from pixel with X-coor = X_left_bot.
Because I shift left the array 'sample_left_bot_buf1' each time the current value of 'sample_left_bot_buf1[c][0]' corresponds to the current value of 'X_left_bot'.
This realtivity is correct for all  bot/top/left/right pairs.
 */
    for (int c = 0; c < max_number_columns + 1; c++) begin  
        if (c < cnt_X_arr[temp_r]) begin
            X_left_bot_rep[c]  <= X_left_bot[c];
            X_right_bot_rep[c] <= X_right_bot[c];
            X_left_top_rep[c]  <= X_left_top[c];
            X_right_top_rep[c] <= X_right_top[c];

            X_left_bot_rep_q[c]  <= X_left_bot_rep[c];
            X_right_bot_rep_q[c] <= X_right_bot_rep[c];
            X_left_top_rep_q[c]  <= X_left_top_rep[c];
            X_right_top_rep_q[c] <= X_right_top_rep[c];

             X_left_bot_rep_qq[c]  <= X_left_bot_rep_q[c];          
            X_right_bot_rep_qq[c] <= X_right_bot_rep_q[c];
             X_left_top_rep_qq[c]  <= X_left_top_rep_q[c];
            X_right_top_rep_qq[c] <= X_right_top_rep_q[c];

             X_left_bot_rep_qqq[c]  <= X_left_bot_rep_qq[c];
            X_right_bot_rep_qqq[c] <= X_right_bot_rep_qq[c];
             X_left_top_rep_qqq[c]  <= X_left_top_rep_qq[c];
            X_right_top_rep_qqq[c] <= X_right_top_rep_qq[c];
            
            sample_left_bot_buf1_0_rep[c]  <= sample_left_bot_buf1[c][0][0];
            sample_left_bot_buf1_1_rep[c]  <= sample_left_bot_buf1[c][0][1];
            sample_right_bot_buf1_0_rep[c] <= sample_right_bot_buf1[c][0][0];
            sample_right_bot_buf1_1_rep[c] <= sample_right_bot_buf1[c][0][1];

            sample_left_top_buf1_0_rep[c]  <= sample_left_top_buf1[c][0][0];
            sample_left_top_buf1_1_rep[c]  <= sample_left_top_buf1[c][0][1];
            sample_right_top_buf1_0_rep[c] <= sample_right_top_buf1[c][0][0];
            sample_right_top_buf1_1_rep[c] <= sample_right_top_buf1[c][0][1];

            sample_left_bot_buf1_0_rep_q[c]  <= sample_left_bot_buf1_0_rep[c];
            sample_left_bot_buf1_1_rep_q[c]  <= sample_left_bot_buf1_1_rep[c];
            sample_right_bot_buf1_0_rep_q[c] <= sample_right_bot_buf1_0_rep[c];
            sample_right_bot_buf1_1_rep_q[c] <= sample_right_bot_buf1_1_rep[c];

            sample_left_top_buf1_0_rep_q[c]  <= sample_left_top_buf1_0_rep[c];
            sample_left_top_buf1_1_rep_q[c]  <= sample_left_top_buf1_1_rep[c];
            sample_right_top_buf1_0_rep_q[c] <= sample_right_top_buf1_0_rep[c];
            sample_right_top_buf1_1_rep_q[c] <= sample_right_top_buf1_1_rep[c];

            sample_left_bot_buf1_0_rep_qq[c]  <= sample_left_bot_buf1_0_rep_q[c];
            sample_left_bot_buf1_1_rep_qq[c]  <= sample_left_bot_buf1_1_rep_q[c];
            sample_right_bot_buf1_0_rep_qq[c] <= sample_right_bot_buf1_0_rep_q[c];
            sample_right_bot_buf1_1_rep_qq[c] <= sample_right_bot_buf1_1_rep_q[c];

            sample_left_top_buf1_0_rep_qq[c]  <= sample_left_top_buf1_0_rep_q[c];
            sample_left_top_buf1_1_rep_qq[c]  <= sample_left_top_buf1_1_rep_q[c];
            sample_right_top_buf1_0_rep_qq[c] <= sample_right_top_buf1_0_rep_q[c];
            sample_right_top_buf1_1_rep_qq[c] <= sample_right_top_buf1_1_rep_q[c];

            mask_left_bot_0[c]   <= 0;
            mask_left_bot_1[c]   <= 0;
            mask_right_bot_0[c]  <= 0;
            mask_right_bot_1[c]  <= 0;
            mask_left_top_0[c]   <= 0;
            mask_left_top_1[c]   <= 0;
            mask_right_top_0[c]  <= 0;
            mask_right_top_1[c]  <= 0;

/*
At this moment 'X_left_bot_rep' is ahead 'sample_left_top_buf1_0_rep_qq' by 2 cycles and other pairs are same.
But it needs 2 cycles to calculate masks, so masks values and 'sample_left_top_buf1_0_rep_qq' will be aligned.
*/
        
            X_coor_left_edge[c]  <= X_coor[temp_r_rep_1[c]][c];
            X_coor_right_edge[c] <= X_coor[temp_r_rep_1[c]][c] + focal_width;

            X_left_bot_left_side_check[c]  <= ((X_left_bot_rep[c] >= X_coor_left_edge[c]) && enable_read_bot_q6[c]);
            X_left_bot_right_side_check[c] <= ((X_left_bot_rep[c] <  X_coor_right_edge[c]) && enable_read_bot_q6[c]);

            X_right_bot_left_side_check[c]  <= ((X_right_bot_rep[c] >= X_coor_left_edge[c]) && enable_read_bot_q6[c]);
            X_right_bot_right_side_check[c] <= ((X_right_bot_rep[c] <  X_coor_right_edge[c]) && enable_read_bot_q6[c]);

            X_left_top_left_side_check[c]  <= ((X_left_top_rep[c] >= X_coor_left_edge[c]) && enable_read_top_q6[c]);
            X_left_top_right_side_check[c] <= ((X_left_top_rep[c] <  X_coor_right_edge[c] && enable_read_top_q6[c]));

            X_right_top_left_side_check[c]  <= ((X_right_top_rep[c] >= X_coor_left_edge[c]) && enable_read_top_q6[c]);
            X_right_top_right_side_check[c] <= ((X_right_top_rep[c] <  X_coor_right_edge[c]) && enable_read_top_q6[c]);


            if (X_left_bot_left_side_check[c] && X_left_bot_right_side_check[c] /* && (X_left_top_rep[c] <= 'd647) */) begin
                mask_left_bot_0[c]  <= active_row_bot_0_rep[c];
                mask_left_bot_1[c]  <= active_row_bot_1_rep[c];
            end else begin
                mask_left_bot_0[c]  <= 0; 
                mask_left_bot_1[c]  <= 0;
            end

            if (X_right_bot_left_side_check[c] && X_right_bot_right_side_check[c] /* && (X_right_top_rep[c] >= 'd648) */) begin
                mask_right_bot_0[c]  <= active_row_bot_0_rep[c];
                mask_right_bot_1[c]  <= active_row_bot_1_rep[c];
            end else begin
                mask_right_bot_0[c]  <= 0; 
                mask_right_bot_1[c]  <= 0;
            end

            if (X_left_top_left_side_check[c] && X_left_top_right_side_check[c] /* && (X_left_top_rep[c] <= 'd647) */) begin
                mask_left_top_0[c]  <= active_row_top_0_rep[c];
                mask_left_top_1[c]  <= active_row_top_1_rep[c];
            end else begin
                mask_left_top_0[c]  <= 0; 
                mask_left_top_1[c]  <= 0;
            end

            if (X_right_top_left_side_check[c] && X_right_top_right_side_check[c] /* && (X_right_top_rep[c] >= 'd648) */) begin
                mask_right_top_0[c]  <= active_row_top_0_rep[c];
                mask_right_top_1[c]  <= active_row_top_1_rep[c];
            end else begin
                mask_right_top_0[c]  <= 0; 
                mask_right_top_1[c]  <= 0;
            end


/* 
            q_mask_left_bot_0[c]  <=  mask_left_bot_0[c];    
            q_mask_left_bot_1[c]  <=  mask_left_bot_1[c];    
            q_mask_right_bot_0[c] <=  mask_right_bot_0[c]; 
            q_mask_right_bot_1[c] <=  mask_right_bot_1[c];   
            q_mask_left_top_0[c]  <=  mask_left_top_0[c];  
            q_mask_left_top_1[c]  <=  mask_left_top_1[c];     
            q_mask_right_top_0[c] <=  mask_right_top_0[c]; 
            q_mask_right_top_1[c] <=  mask_right_top_1[c];   */   

            //Accumulating sums with using masks
            //I
            sum_I_part_left_bot_0[c]  <=  (mask_left_bot_0[c])? sample_left_bot_buf1_0_rep_qq[c] : 10'b0;
            sum_I_part_left_bot_1[c]  <=  (mask_left_bot_1[c])? sample_left_bot_buf1_1_rep_qq[c] : 10'b0;

            sum_I_part_right_bot_0[c]  <=  (mask_right_bot_0[c])? sample_right_bot_buf1_0_rep_qq[c] : 10'b0;
            sum_I_part_right_bot_1[c]  <=  (mask_right_bot_1[c])? sample_right_bot_buf1_1_rep_qq[c] : 10'b0;
            sum_I_part_right_bot_0_q[c]  <= sum_I_part_right_bot_0[c];
            sum_I_part_right_bot_1_q[c]  <= sum_I_part_right_bot_1[c];   

            sum_I_part_left_top_0[c]  <=  (mask_left_top_0[c])? sample_left_top_buf1_0_rep_qq[c] : 10'b0;
            sum_I_part_left_top_1[c]  <=  (mask_left_top_1[c])? sample_left_top_buf1_1_rep_qq[c] : 10'b0;
            sum_I_part_left_top_0_q[c]  <= sum_I_part_left_top_0[c];
            sum_I_part_left_top_1_q[c]  <= sum_I_part_left_top_1[c];
            sum_I_part_left_top_0_qq[c]  <= sum_I_part_left_top_0_q[c];
            sum_I_part_left_top_1_qq[c]  <= sum_I_part_left_top_1_q[c]; 

            sum_I_part_right_top_0[c]  <=  (mask_right_top_0[c])? sample_right_top_buf1_0_rep_qq[c] : 10'b0;
            sum_I_part_right_top_1[c]  <=  (mask_right_top_1[c])? sample_right_top_buf1_1_rep_qq[c] : 10'b0;
            sum_I_part_right_top_0_q[c] <= sum_I_part_right_top_0[c];
            sum_I_part_right_top_1_q[c] <= sum_I_part_right_top_1[c];
            sum_I_part_right_top_0_qq[c] <= sum_I_part_right_top_0_q[c];
            sum_I_part_right_top_1_qq[c] <= sum_I_part_right_top_1_q[c];
            sum_I_part_right_top_0_qqq[c] <= sum_I_part_right_top_0_qq[c];
            sum_I_part_right_top_1_qqq[c] <= sum_I_part_right_top_1_qq[c];

            //Ix
            sample_left_bot_buf1_0_rep_qq_msk_X[c]    <=  (mask_left_bot_0[c])? sample_left_bot_buf1_0_rep_qq[c] : 10'b0;
            sample_left_bot_buf1_1_rep_qq_msk_X[c]    <=  (mask_left_bot_1[c])? sample_left_bot_buf1_1_rep_qq[c] : 10'b0;

            sample_right_bot_buf1_0_rep_qq_msk_X[c]   <=  (mask_right_bot_0[c])? sample_right_bot_buf1_0_rep_qq[c] : 10'b0;
            sample_right_bot_buf1_1_rep_qq_msk_X[c]   <=  (mask_right_bot_1[c])? sample_right_bot_buf1_1_rep_qq[c] : 10'b0;
            sample_right_bot_buf1_0_rep_qq_msk_X_q[c] <= sample_right_bot_buf1_0_rep_qq_msk_X[c];
            sample_right_bot_buf1_1_rep_qq_msk_X_q[c] <= sample_right_bot_buf1_1_rep_qq_msk_X[c];
            X_right_bot_rep_qqq_2_1[c] <=  X_right_bot_rep_qqq[c];

            sample_left_top_buf1_0_rep_qq_msk_X[c]  <=  (mask_left_top_0[c])? sample_left_top_buf1_0_rep_qq[c] : 10'b0;
            sample_left_top_buf1_1_rep_qq_msk_X[c]  <=  (mask_left_top_1[c])? sample_left_top_buf1_1_rep_qq[c] : 10'b0;
            sample_left_top_buf1_0_rep_qq_msk_X_q[c] <=  sample_left_top_buf1_0_rep_qq_msk_X[c] ;   
            sample_left_top_buf1_1_rep_qq_msk_X_q[c] <=  sample_left_top_buf1_1_rep_qq_msk_X[c] ;   
            sample_left_top_buf1_0_rep_qq_msk_X_qq[c] <= sample_left_top_buf1_0_rep_qq_msk_X_q[c];   
            sample_left_top_buf1_1_rep_qq_msk_X_qq[c] <= sample_left_top_buf1_1_rep_qq_msk_X_q[c];    
            X_left_top_rep_qqq_3_1[c] <= X_left_top_rep_qqq[c];
            X_left_top_rep_qqq_3_2[c] <= X_left_top_rep_qqq_3_1[c];

            sample_right_top_buf1_0_rep_qq_msk_X[c]  <=  (mask_right_top_0[c])? sample_right_top_buf1_0_rep_qq[c] : 10'b0;
            sample_right_top_buf1_1_rep_qq_msk_X[c]  <=  (mask_right_top_1[c])? sample_right_top_buf1_1_rep_qq[c] : 10'b0;
            sample_right_top_buf1_0_rep_qq_msk_X_q[c] <= sample_right_top_buf1_0_rep_qq_msk_X[c];
            sample_right_top_buf1_1_rep_qq_msk_X_q[c] <= sample_right_top_buf1_1_rep_qq_msk_X[c];
            sample_right_top_buf1_0_rep_qq_msk_X_qq[c] <= sample_right_top_buf1_0_rep_qq_msk_X_q[c];
            sample_right_top_buf1_1_rep_qq_msk_X_qq[c] <= sample_right_top_buf1_1_rep_qq_msk_X_q[c];
            sample_right_top_buf1_0_rep_qq_msk_X_qqq[c] <= sample_right_top_buf1_0_rep_qq_msk_X_qq[c];
            sample_right_top_buf1_1_rep_qq_msk_X_qqq[c] <= sample_right_top_buf1_1_rep_qq_msk_X_qq[c];
            X_right_top_rep_qqq_4_1[c] <= X_right_top_rep_qqq[c];
            X_right_top_rep_qqq_4_2[c] <= X_right_top_rep_qqq_4_1[c];
            X_right_top_rep_qqq_4_3[c] <= X_right_top_rep_qqq_4_2[c];

            //Iy
            row_address_bot_reg[c]  <= ({row_address_bot, 1'b0});
            row_address_top_reg[c]  <= ({row_address_top, 1'b0});
            row_address_bot_reg1[c]  <= ({row_address_bot, 1'b0});
            row_address_top_reg1[c]  <= ({row_address_top, 1'b0});

            sample_left_bot_buf1_0_rep_qq_msk_Y[c]      <= (mask_left_bot_0[c])? sample_left_bot_buf1_0_rep_qq[c] : 10'b0;
            sample_left_bot_buf1_1_rep_qq_msk_Y[c]      <= (mask_left_bot_1[c])? sample_left_bot_buf1_1_rep_qq[c] : 10'b0;

            sample_right_bot_buf1_0_rep_qq_msk_Y[c]     <=  (mask_right_bot_0[c])? sample_right_bot_buf1_0_rep_qq[c] : 10'b0;
            sample_right_bot_buf1_1_rep_qq_msk_Y[c]     <=  (mask_right_bot_1[c])? sample_right_bot_buf1_1_rep_qq[c] : 10'b0;
            sample_right_bot_buf1_0_rep_qq_msk_Y_q[c]   <= sample_right_bot_buf1_0_rep_qq_msk_Y[c];
            sample_right_bot_buf1_1_rep_qq_msk_Y_q[c]   <= sample_right_bot_buf1_1_rep_qq_msk_Y[c];

            sample_left_top_buf1_0_rep_qq_msk_Y[c]      <=  (mask_left_top_0[c])? sample_left_top_buf1_0_rep_qq[c] : 10'b0;
            sample_left_top_buf1_1_rep_qq_msk_Y[c]      <=  (mask_left_top_1[c])? sample_left_top_buf1_1_rep_qq[c] : 10'b0;
            sample_left_top_buf1_0_rep_qq_msk_Y_q[c]    <=  sample_left_top_buf1_0_rep_qq_msk_Y[c];    
            sample_left_top_buf1_1_rep_qq_msk_Y_q[c]    <=  sample_left_top_buf1_1_rep_qq_msk_Y[c];  
            sample_left_top_buf1_0_rep_qq_msk_Y_qq[c]   <= sample_left_top_buf1_0_rep_qq_msk_Y_q[c];   
            sample_left_top_buf1_1_rep_qq_msk_Y_qq[c]   <= sample_left_top_buf1_1_rep_qq_msk_Y_q[c]; 

            sample_right_top_buf1_0_rep_qq_msk_Y[c]     <=  (mask_right_top_0[c])? sample_right_top_buf1_0_rep_qq[c] : 10'b0;
            sample_right_top_buf1_1_rep_qq_msk_Y[c]     <=  (mask_right_top_1[c])? sample_right_top_buf1_1_rep_qq[c] : 10'b0;
            sample_right_top_buf1_0_rep_qq_msk_Y_q[c]   <= sample_right_top_buf1_0_rep_qq_msk_Y[c];
            sample_right_top_buf1_1_rep_qq_msk_Y_q[c]   <= sample_right_top_buf1_1_rep_qq_msk_Y[c];
            sample_right_top_buf1_0_rep_qq_msk_Y_qq[c]  <= sample_right_top_buf1_0_rep_qq_msk_Y_q[c];
            sample_right_top_buf1_1_rep_qq_msk_Y_qq[c]  <= sample_right_top_buf1_1_rep_qq_msk_Y_q[c];
            sample_right_top_buf1_0_rep_qq_msk_Y_qqq[c] <= sample_right_top_buf1_0_rep_qq_msk_Y_qq[c];
            sample_right_top_buf1_1_rep_qq_msk_Y_qqq[c] <= sample_right_top_buf1_1_rep_qq_msk_Y_qq[c];

        end
    end
end

wire [47:0] i_casc_01 [max_number_columns:0];
wire [47:0] i_casc_12 [max_number_columns:0];
wire [47:0] i_casc_23 [max_number_columns:0];
wire [47:0] i_casc_34 [max_number_columns:0];

wire [47:0] ix_casc_01 [max_number_columns:0];
wire [47:0] ix_casc_12 [max_number_columns:0];
wire [47:0] ix_casc_23 [max_number_columns:0];
wire [47:0] ix_casc_34 [max_number_columns:0];

wire [47:0] iy_casc_01 [max_number_columns:0];
wire [47:0] iy_casc_12 [max_number_columns:0];
wire [47:0] iy_casc_23 [max_number_columns:0];
wire [47:0] iy_casc_34 [max_number_columns:0];
generate
    for (i = 0; i < max_number_columns + 1; i++) begin : column
        logic dsp_en;
        assign dsp_en = (i < cnt_X_arr[temp_r]);


//==============================================================================================================//
//                                                                                                              //
//                                       5-stage I DSP cascade                                                  //
//                                                                                                              //
//==============================================================================================================//
/* 
For I (Intensity) calculation it's need only add two values of piexels from double_row. But the problem is that than each 'I' DSP will has 
a latency 3 (because after AREG and DREG ther is 1 cycle latency, ADREG - 2 cycles and aftet PREG 3 cycles) while 'Ix' and 'Iy'
DSPs wull have 4 cycles latency. So i use extra multiplication by 1 in 'I' DSPs to align the internals pipelines.
*/
        //I left_bot
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"),            
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),         
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),
      
           .AREG(1), .DREG(1),        
           .ADREG(1),                 
           .BREG(1),                 
           .MREG(1),                  
           .PREG(1),                  
           .ACASCREG(1), .BCASCREG(1), .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), 
           .CREG(0), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_I_LEFT_BOT (
           .CLK(Pclk_x4_shifted),
           .A(30'(sum_I_part_left_bot_0[i])), 
           .D(27'(sum_I_part_left_bot_1[i])), 
           .B(18'd1),                  
        
  
           .INMODE(5'b00100),         // (A+D)*B
           .OPMODE(9'b000000101),     // Z=0, Y=M, X=M
           .ALUMODE(4'b0000),         // ADD
           
           .PCOUT(i_casc_01[i]),      
           .P(),
           
           // Clock Enables
           .CEP(dsp_en), .CEA2(dsp_en), .CEB2(dsp_en), .CED(dsp_en), 
           .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
           .C(48'b0), .PCIN(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEA1(1'b0), .CEB1(1'b0), .CEALUMODE(1'b0), 
           .CEC(1'b0), .CECARRYIN(1'b0), .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), 
           .RSTALUMODE(1'b0), .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), 
           .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );

        //I right_bot
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),

           .AREG(1), .DREG(1),        
           .ADREG(1),                
           .BREG(1),                  
           .MREG(1),                  
           .PREG(1),                 
           .ACASCREG(1), .BCASCREG(1), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_I_RIGHT_BOT (
           .CLK(Pclk_x4_shifted),

           .A(30'(sum_I_part_right_bot_0_q[i])), 
           .D(27'(sum_I_part_right_bot_1_q[i])), 
           .B(18'd1),                   
           
 
           .PCIN(i_casc_01[i]),               
           .PCOUT(i_casc_12[i]),              
           .P(),                            
           
           // P = (A+D) + PCIN
           // Z=PCIN (001), Y=M (01), X=M (01)
           .OPMODE(9'b000010101),             
           .ALUMODE(4'b0000),                 
           .INMODE(5'b00100),                 
           
           // Clock Enables
           .CEP(dsp_en), 
           .CEA1(1'b0), .CEA2(dsp_en), 
           .CEB1(0), .CEB2(dsp_en), 
           .CED(dsp_en), .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
         
           .C(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0), .CEC(1'b0), .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );


        //I left_top
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),         
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),

           .AREG(1), .DREG(1),        
           .ADREG(1),                 
           .BREG(1),                
           .MREG(1),                
           .PREG(1),                 
           .ACASCREG(1), .BCASCREG(1), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_I_LEFT_TOP (
           .CLK(Pclk_x4_shifted),

           .A(30'(sum_I_part_left_top_0_qq[i])), 
           .D(27'(sum_I_part_left_top_1_qq[i])), 
           .B(18'd1),                   
           

           .PCIN(i_casc_12[i]),               
           .PCOUT(i_casc_23[i]),              
           .P(),                              
           
           // P = (A+D) + PCIN
           // Z=PCIN (001), Y=M (01), X=M (01)
           .OPMODE(9'b000010101),             
           .ALUMODE(4'b0000),                 // ADD
           .INMODE(5'b00100),                 // A+D 
           

           .CEP(dsp_en), 
           .CEA1(1'b0), .CEA2(dsp_en), 
           .CEB1(0), .CEB2(dsp_en), 
           .CED(dsp_en), .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
 
           .C(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0), .CEC(1'b0), .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );

        //I right_top
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),
           
           .AREG(1), .DREG(1),        
           .ADREG(1),                 
           .BREG(1),                  
           .MREG(1),                  
           .PREG(1),                  
           .ACASCREG(1), .BCASCREG(1), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_I_RIGHT_TOP (
           .CLK(Pclk_x4_shifted),
           
           .A(30'(sum_I_part_right_top_0_qqq[i])), 
           .D(27'(sum_I_part_right_top_1_qqq[i])), 
           .B(18'd1),                   
           
           
           .PCIN(i_casc_23[i]),               
           .PCOUT(i_casc_34[i]),              
           .P(),                              
           
           // P = (A+D) + PCIN
           // Z=PCIN (001), Y=M (01), X=M (01)
           .OPMODE(9'b000010101),             
           .ALUMODE(4'b0000),                 // ADD
           .INMODE(5'b00100),                 // A+D 
           
           
           .CEP(dsp_en), 
           .CEA1(1'b0), .CEA2(dsp_en), 
           .CEB1(0), .CEB2(dsp_en), 
           .CED(dsp_en), .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
           
           .C(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0), .CEC(1'b0), .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );

        //I accum
        DSP48E2 #(
           .USE_MULT("NONE"),
           .AMULTSEL("A"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),
           
           .AREG(0), .DREG(0),        
           .ADREG(0),                
           .BREG(0),                  
           .MREG(0),                 
           .PREG(1),                  
           .ACASCREG(0), .BCASCREG(0), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_I_ACC (
           .CLK(Pclk_x4_shifted),
           
           .A(0), 
           .D(0), 
           .B(0),                   
           
           
           .PCIN(i_casc_34[i]),               
           .PCOUT(),              
           .P(sum_I[i]),                             
           
            // Z=PCIN(001), X=P(10)
           .OPMODE(9'b000010010),             
           .ALUMODE(4'b0000),                 // ADD
           .INMODE(5'b00100),                 // A+D 
           
           
           .CEP(dsp_en), 
           .CEA1(0), .CEA2(0), 
           .CEB1(0), .CEB2(0), 
           .CED(0), .CEAD(0), .CEM(0), .CECTRL(1'b1),
           
           
           .C(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0), .CEC(1'b0), .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(start_div_rep_strb_reg[i])
        );
//==============================================================================================================//
//                                                                                                              //
//                                         5-stage Ix DSP cascade                                               //
//                                                                                                              //
//==============================================================================================================//

        //Ix left_bot
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"),            
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),         
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),
           
           .AREG(1), .DREG(1),        
           .ADREG(1),                 
           .BREG(2),                  
           .MREG(1),                  
           .PREG(1),                  
           .ACASCREG(1), .BCASCREG(1), .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), 
           .CREG(0), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_IX_LEFT_BOT (
           .CLK(Pclk_x4_shifted),
           
           .A(30'(sample_left_bot_buf1_0_rep_qq_msk_X[i])), 
           .D(27'(sample_left_bot_buf1_1_rep_qq_msk_X[i])), 
           .B(18'(X_left_bot_rep_qqq[i])),                   
           
           
           .INMODE(5'b00100),         
           
           //P = (A+D) * B
           .OPMODE(9'b000000101),     // Z=0, Y=M, X=M
           .ALUMODE(4'b0000),         
           
           .PCOUT(ix_casc_01[i]),     
           .P(),
           
          
           .CEP(dsp_en), .CEA2(dsp_en), .CEB1(dsp_en), .CEB2(dsp_en), .CED(dsp_en), 
           .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
           
           .C(48'b0), .PCIN(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEA1(1'b0),  .CEALUMODE(1'b0), 
           .CEC(1'b0), .CECARRYIN(1'b0), .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), 
           .RSTALUMODE(1'b0), .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), 
           .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );

        //Ix right_bot
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),
           
           .AREG(1), .DREG(1),        
           .ADREG(1),                 
           .BREG(2),                  
           .MREG(1),                  
           .PREG(1),                  
           .ACASCREG(1), .BCASCREG(1), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_IX_RIGHT_BOT (
           .CLK(Pclk_x4_shifted),
     
           .A(30'(sample_right_bot_buf1_0_rep_qq_msk_X_q[i])), 
           .D(27'(sample_right_bot_buf1_1_rep_qq_msk_X_q[i])), 
           .B(18'(X_right_bot_rep_qqq_2_1[i])),                   
           
           
           .PCIN(ix_casc_01[i]),               
           .PCOUT(ix_casc_12[i]),             
           .P(),                              
           
           // P = (A+D) * B + PCIN
           // Z=PCIN (001), Y=M (01), X=M (01)
           .OPMODE(9'b000010101),             
           .ALUMODE(4'b0000),                 
           .INMODE(5'b00100),                 
           
           
           .CEP(dsp_en), 
           .CEA1(1'b0), .CEA2(dsp_en), 
           .CEB1(dsp_en), .CEB2(dsp_en),
           .CED(dsp_en), .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
           
           .C(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0), .CEC(1'b0), .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );


        //Ix left_top
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),
           
           .AREG(1), .DREG(1),       
           .ADREG(1),                 
           .BREG(2),                  
           .MREG(1),                  
           .PREG(1),                  
           .ACASCREG(1), .BCASCREG(1), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_IX_LEFT_TOP (
           .CLK(Pclk_x4_shifted),

           .A(30'(sample_left_top_buf1_0_rep_qq_msk_X_qq[i])), 
           .D(27'(sample_left_top_buf1_1_rep_qq_msk_X_qq[i])), 
           .B(18'(X_left_top_rep_qqq_3_2[i])),                   
           

           .PCIN(ix_casc_12[i]),               
           .PCOUT(ix_casc_23[i]),             
           .P(),                           
           
           // P = (A+D) * B + PCIN
           // Z=PCIN (001), Y=M (01), X=M (01)
           .OPMODE(9'b000010101),             
           .ALUMODE(4'b0000),                 
           .INMODE(5'b00100),                 
           
       
           .CEP(dsp_en), 
           .CEA1(1'b0), .CEA2(dsp_en), 
           .CEB1(dsp_en), .CEB2(dsp_en), 
           .CED(dsp_en), .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
           
           .C(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0), .CEC(1'b0), .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );


        //Ix right_top
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),

           .AREG(1), .DREG(1),       
           .ADREG(1),              
           .BREG(2),                
           .MREG(1),              
           .PREG(1),               
           .ACASCREG(1), .BCASCREG(1), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_IX_RIGHT_TOP (
           .CLK(Pclk_x4_shifted),

           .A(30'(sample_right_top_buf1_0_rep_qq_msk_X_qqq[i])), 
           .D(27'(sample_right_top_buf1_1_rep_qq_msk_X_qqq[i])), 
           .B(18'(X_right_top_rep_qqq_4_3[i])),                   
           

           .PCIN(ix_casc_23[i]),               
           .PCOUT(ix_casc_34[i]),            
           .P(),                         
           
           // P = (A+D) * B + PCIN + P
           // W = P (01), Z=PCIN (001), Y=M (01), X=M (01)
           .OPMODE(9'b000010101),             
           .ALUMODE(4'b0000),                 
           .INMODE(5'b00100),                 
           
      
           .CEP(dsp_en), 
           .CEA1(1'b0), .CEA2(dsp_en), 
           .CEB1(dsp_en), .CEB2(dsp_en),
           .CED(dsp_en), .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
           
           .C(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0), .CEC(1'b0), .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );

        //Ix accum
        DSP48E2 #(
           .USE_MULT("NONE"),
           .AMULTSEL("A"),         
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),

           .AREG(0), .DREG(0),      
           .ADREG(0),               
           .BREG(0),                
           .MREG(0),                  
           .PREG(1),              
           .ACASCREG(0), .BCASCREG(0), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_IX_ACC (
           .CLK(Pclk_x4_shifted),

           .A(0), 
           .D(0), 
           .B(0),                   
           

           .PCIN(ix_casc_34[i]),               
           .PCOUT(),             
           .P(sum_Ix[i]),                    
           
       
           .OPMODE(9'b000010010),             
           .ALUMODE(4'b0000),                 
           .INMODE(5'b00100),                 
           
         
           .CEP(dsp_en), 
           .CEA1(0), .CEA2(0), 
           .CEB1(0), .CEB2(0),
           .CED(0), .CEAD(0), .CEM(0), .CECTRL(1'b1),
           
  
           .C(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0), .CEC(1'b0), .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(start_div_rep_strb_reg[i])
        );

//==============================================================================================================//
//                                                                                                              //
//                                        5-stage Iy DSP cascade                                                //
//                                                                                                              //
//==============================================================================================================//

        //Iy left_bot
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),          
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"),           
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),         
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),
      
           .AREG(1), .DREG(1),        
           .ADREG(1),                 
           .BREG(1),                  
           .MREG(1),                  
           .PREG(1),                  
           .ACASCREG(1), .BCASCREG(1), .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), 
           .CREG(1), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_IY_LEFT_BOT (
           .CLK(Pclk_x4_shifted),
       
           .A(30'(sample_left_bot_buf1_0_rep_qq_msk_Y[i])), // Sample 0
           .D(27'(sample_left_bot_buf1_1_rep_qq_msk_Y[i])), // Sample 1
           .B(18'(row_address_bot_reg[i])),                 // Y-coor
           .C(48'(sample_left_bot_buf1_1_rep_qq_msk_Y[i])),
           
          
           .INMODE(5'b00100),         
           
           
           .OPMODE(9'b110000101),     // W=C, Y=M, X=M
           .ALUMODE(4'b0000),         
           
           .PCOUT(iy_casc_01[i]),      
           .P(),
           
          
           .CEP(dsp_en), .CEA2(dsp_en), .CEB2(dsp_en), .CED(dsp_en), .CEC(dsp_en), 
           .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
           
            .PCIN(48'b0), .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEA1(1'b0), .CEB1(1'b0), .CEALUMODE(1'b0), 
            .CECARRYIN(1'b0), .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), 
           .RSTALUMODE(1'b0), .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), 
           .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );

        //Iy right_bot
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),

           .AREG(1), .DREG(1),        
           .ADREG(1),                
           .BREG(1),                 
           .MREG(1),                 
           .PREG(1),                 
           .ACASCREG(1), .BCASCREG(1), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(1), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_IY_RIGHT_BOT (
           .CLK(Pclk_x4_shifted),
           
           .A(30'(sample_right_bot_buf1_0_rep_qq_msk_Y_q[i])), 
           .D(27'(sample_right_bot_buf1_1_rep_qq_msk_Y_q[i])), 
           .B(18'(row_address_bot_reg1[i])),      
           .C(48'(sample_right_bot_buf1_1_rep_qq_msk_Y_q[i])),              
           
           
           .PCIN(iy_casc_01[i]),               
           .PCOUT(iy_casc_12[i]),              
           .P(),                              
           
           // P = (A+D) * B + C + PCIN
           // W = C(11), Z=PCIN (001), Y=M (01), X=M (01)
           .OPMODE(9'b110010101),             
           .ALUMODE(4'b0000),                
           .INMODE(5'b00100),                 
           
           
           .CEP(dsp_en), .CEC(dsp_en),
           .CEA1(1'b0), .CEA2(dsp_en), 
           .CEB1(0), .CEB2(dsp_en), 
           .CED(dsp_en), .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
           
           .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0),  .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );


        //Iy left_top
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),
           
           .AREG(1), .DREG(1),        
           .ADREG(1),                 
           .BREG(1),                  
           .MREG(1),                  
           .PREG(1),                  
           .ACASCREG(1), .BCASCREG(1), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(1), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_IY_LEFT_TOP (
           .CLK(Pclk_x4_shifted),
           
           .A(30'(sample_left_top_buf1_0_rep_qq_msk_Y_qq[i])), 
           .D(27'(sample_left_top_buf1_1_rep_qq_msk_Y_qq[i])), 
           .B(18'(row_address_top_reg[i])),  
           .C(48'(sample_left_top_buf1_1_rep_qq_msk_Y_qq[i])),   
                       
           
           
           .PCIN(iy_casc_12[i]),               
           .PCOUT(iy_casc_23[i]),              
           .P(),                              
           
           // P = (A+D) * B + C + PCIN
           // W = C(11), Z=PCIN (001), Y=M (01), X=M (01)
           .OPMODE(9'b110010101),             
           .ALUMODE(4'b0000),                
           .INMODE(5'b00100),                
           
        
           .CEP(dsp_en), .CEC(dsp_en),
           .CEA1(1'b0), .CEA2(dsp_en), 
           .CEB1(0), .CEB2(dsp_en), 
           .CED(dsp_en), .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
           
           .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0),  .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );


        //Iy right_top 
        DSP48E2 #(
           .USE_MULT("MULTIPLY"),
           .AMULTSEL("AD"),           
           .A_INPUT("DIRECT"), 
           .BMULTSEL("B"), 
           .B_INPUT("DIRECT"),
           .PREADDINSEL("A"),
           .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),
          
           .AREG(1), .DREG(1),       
           .ADREG(1),                 
           .BREG(1),                 
           .MREG(1),                 
           .PREG(1),                  
           .ACASCREG(1), .BCASCREG(1), 
           .ALUMODEREG(0), .CARRYINREG(0), .CARRYINSELREG(0), .CREG(1), .INMODEREG(0), .OPMODEREG(0)
        )
        DSP_IY_RIGHT_TOP (
           .CLK(Pclk_x4_shifted),
           
           .A(30'(sample_right_top_buf1_0_rep_qq_msk_Y_qqq[i])), 
           .D(27'(sample_right_top_buf1_1_rep_qq_msk_Y_qqq[i])), 
           .B(18'(row_address_top_reg1[i])),       
           .C(48'(sample_right_top_buf1_1_rep_qq_msk_Y_qqq[i])),             
           
           
           .PCIN(iy_casc_23[i]),               
           .PCOUT(iy_casc_34[i]),              
           .P(),                              
           
           // P = (A+D) * B + C + PCIN
           // W = C(11), Z=PCIN (001), Y=M (01), X=M (01)
           .OPMODE(9'b110010101),             
           .ALUMODE(4'b0000),                 
           .INMODE(5'b00100),                
           

           .CEP(dsp_en), .CEC(dsp_en),
           .CEA1(1'b0), .CEA2(dsp_en),
           .CEB1(0), .CEB2(dsp_en), 
           .CED(dsp_en), .CEAD(dsp_en), .CEM(dsp_en), .CECTRL(1'b1),
           
       
           .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0), 
           .CARRYINSEL(3'b0), .CARRYIN(1'b0), .CEALUMODE(1'b0),  .CECARRYIN(1'b0), 
           .CEINMODE(1'b0), .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), 
           .RSTB(1'b0), .RSTC(1'b0), .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(1'b0)
        );


        //Iy accum
        DSP48E2 #(
           .USE_MULT("NONE"),                
           .AMULTSEL("A"), .A_INPUT("DIRECT"), .BMULTSEL("B"), .B_INPUT("DIRECT"),
           .PREADDINSEL("A"), .RND(48'h0), .USE_SIMD("ONE48"), .USE_WIDEXOR("FALSE"),
           .AUTORESET_PATDET("NO_RESET"), .AUTORESET_PRIORITY("RESET"),
           .MASK(48'h3fffffffffff), .PATTERN(48'h0), .SEL_MASK("MASK"), .SEL_PATTERN("PATTERN"),
           .USE_PATTERN_DETECT("NO_PATDET"),
           .ACASCREG(0), .ADREG(0), .ALUMODEREG(0), .AREG(0), .BCASCREG(0), .BREG(0),
           .CARRYINREG(0), .CARRYINSELREG(0), .CREG(0), .DREG(0), .INMODEREG(0),
           .MREG(0), .OPMODEREG(0), 
           .PREG(1) 
        )
        DSP_IY_ACC (
           .CLK(Pclk_x4_shifted),

           .PCIN(iy_casc_34[i]),            
           .P(sum_Iy[i]),                   

           .OPMODE(9'b000010010),           // Z=PCIN(001), X=P(10)
           .ALUMODE(4'b0000),               
           .CEP(dsp_en),                   
           .CECTRL(1'b1),                   

           .A(30'b0), .B(18'b0), .C(48'b0), .D(27'b0),
           .ACIN(30'b0), .BCIN(18'b0), .CARRYCASCIN(1'b0), .MULTSIGNIN(1'b0),
           .CARRYINSEL(3'b0), .INMODE(5'b0), .CARRYIN(1'b0),

           .CEA1(1'b0), .CEA2(1'b0), .CEAD(1'b0), .CEALUMODE(1'b0), .CEB1(1'b0), .CEB2(1'b0),
           .CEC(1'b0), .CECARRYIN(1'b0), .CED(1'b0), .CEINMODE(1'b0), .CEM(1'b0),
           .RSTA(1'b0), .RSTALLCARRYIN(1'b0), .RSTALUMODE(1'b0), .RSTB(1'b0), .RSTC(1'b0),
           .RSTCTRL(1'b0), .RSTD(1'b0), .RSTINMODE(1'b0), .RSTM(1'b0), .RSTP(start_div_rep_strb_reg[i]),

           .ACOUT(), .BCOUT(), .CARRYCASCOUT(), .MULTSIGNOUT(), .PCOUT(),
           .OVERFLOW(), .PATTERNBDETECT(), .PATTERNDETECT(), .UNDERFLOW(), .CARRYOUT(), .XOROUT()
        );
    end
endgenerate

logic [$clog2(focal_height*focal_width*1023*2047)-1:0] sum_Ix_div_buf = 0;  // 30 bits        
logic [$clog2(focal_height*focal_width*1023*2047)-1:0] sum_Iy_div_buf = 0;  // 30 bits  
logic [$clog2(focal_height*focal_width*1023)-1:0]      sum_I_div_buf = 0;   // 19 bits
logic [4:0] spot_id = 0; 
logic s_axis_divider_data_tvalid = 0;
logic s_axis_divisor_tvalid = 0;
logic [39:0] m_axis_dout_tdata_x, m_axis_dout_tdata_y;
logic [10:0] Xc;
logic [9:0]  Yc;
logic [7:0] Xc_frac, Yc_frac;
assign Xc =  m_axis_dout_tdata_x[18:8];
assign Yc =  m_axis_dout_tdata_y[17:8];
assign Xc_frac = m_axis_dout_tdata_x[7:0];
assign Yc_frac = m_axis_dout_tdata_y[7:0];

(* MAX_FANOUT = 50 *)  logic start_divider = 0;
(* MAX_FANOUT = 50 *)  logic start_divider_del  = 0;

typedef struct packed {
    logic [$clog2(focal_height*focal_width*1023*2047)-1:0] Ix;
    logic [$clog2(focal_height*focal_width*1023*2047)-1:0] Iy;
    logic [$clog2(focal_height*focal_width*1023)-1:0] I;
} t_dsp_out;

(* shreg_extract = "no" *) t_dsp_out q_group [0:max_number_columns];
(* dont_touch = "yes" *) logic [max_number_columns:0] start_div_rep;
(* dont_touch = "yes" *) logic [max_number_columns:0] start_div_rep_del;
(* dont_touch = "yes" *) logic [max_number_columns:0] start_div_rep_strb;
(* dont_touch = "yes" *) logic [max_number_columns:0] start_div_rep_strb_reg;
assign start_div_rep_strb = ~start_div_rep & start_div_rep_del;
(* dont_touch = "yes" *) logic [max_number_columns:0] s_axis_divisor_tready_x_rep;

always_ff @(posedge Pclk_x4_shifted) begin
    for (int i = 0; i < max_number_columns + 1; i++) begin
        start_div_rep[i] <= start_divider; 
        start_div_rep_del[i] <= start_div_rep[i];
        s_axis_divisor_tready_x_rep[i] <= s_axis_divisor_tready_x;
    end
    start_div_rep_strb_reg <= start_div_rep_strb;
end

always_ff @(posedge Pclk_x4_shifted) begin
    if (!active_row && active_row_del) start_divider <= 1; 
    start_divider_del <= start_divider;


    for (int g = 0; g < max_number_columns+1; g++) begin
        if (start_div_rep[g]) begin
            if (g < max_number_columns && s_axis_divisor_tready_x_rep[g]) q_group[g] <= q_group[g+1];
        end else begin
            q_group[g] <= '{Ix: sum_Ix[g], Iy: sum_Iy[g], I: sum_I[g]};
        end
    end

    if (start_divider & start_divider_del) begin
        if (s_axis_divisor_tready_x) begin
            {sum_Ix_div_buf, sum_Iy_div_buf, sum_I_div_buf} <= q_group[0];
            s_axis_divider_data_tvalid <= 1;

            if (spot_id < cnt_X_arr[temp_r] - 1) begin
                spot_id <= spot_id + 1;
            end else begin
                spot_id <= 0;
                start_divider <= 0; 
                temp_r <= (temp_r < max_number_rows) ? temp_r + 1 : 0;
            end
        end else begin
            s_axis_divider_data_tvalid <= 0;
        end
    end else begin
        s_axis_divider_data_tvalid <= 0;
    end
end


div_gen_0 Xc_divider (
  .aclk(Pclk_x4_shifted),                                      // input wire aclk
  .s_axis_divisor_tvalid(s_axis_divider_data_tvalid),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tready(s_axis_divisor_tready_x),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata({5'b0,sum_I_div_buf}),      // input wire [23 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(s_axis_divider_data_tvalid),  // input wire s_axis_divider_data_tvalid
  .s_axis_dividend_tready(s_axis_dividend_tready_x),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata({2'b0,sum_Ix_div_buf}),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid_x),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_axis_dout_tdata_x)            // output wire [55 : 0] m_axis_dout_tdata
);


div_gen_0 Yc_divider (
  .aclk(Pclk_x4_shifted),                                      // input wire aclk
  .s_axis_divisor_tvalid(s_axis_divider_data_tvalid),    // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tready(s_axis_divisor_tready_y),    // output wire s_axis_divisor_tready
  .s_axis_divisor_tdata({5'b0,sum_I_div_buf}),      // input wire [23 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(s_axis_divider_data_tvalid),  // input wire s_axis_divider_data_tvalid
  .s_axis_dividend_tready(s_axis_dividend_tready_y),  // output wire s_axis_dividend_tready
  .s_axis_dividend_tdata({2'b0,sum_Iy_div_buf}),    // input wire [31 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(m_axis_dout_tvalid_y),          // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_axis_dout_tdata_y)            // output wire [55 : 0] m_axis_dout_tdata
);

logic [39:0] set_coor;    //this 5-byte reg contains Xc and Yc and has a structure: {8'hAA, 11'b_Xc, 3'b0, 10'b_Yc, 8'hBB}

assign set_coor[39:37]   = 3'b111;
logic Xc_wr_done = 0, Yc_wr_done = 0, set_vaild;
logic [39:0] m_axis_tdata;
always_ff @ (posedge Pclk_x4_shifted) begin
    if (m_axis_dout_tvalid_x & m_axis_dout_tvalid_y) begin
        set_coor[36:26] <= Xc;
        set_coor[25:18] <= Xc_frac;
        set_coor[17:8] <= Yc;
        set_coor[7:0] <= Yc_frac;
        set_vaild <= 1;
    end else set_vaild <= 0;
end

set_coor_fifo set_coor_fifo (
  .s_axis_aresetn(locked),  // input wire s_axis_aresetn
  .s_axis_aclk(Pclk_x4_shifted),        // input wire s_axis_aclk
  .s_axis_tvalid(set_vaild),    // input wire s_axis_tvalid
  .s_axis_tready(),    // output wire s_axis_tready
  .s_axis_tdata(set_coor),      // input wire [39 : 0] s_axis_tdata
  .m_axis_aclk(clk),        // input wire m_axis_aclk
  .m_axis_tvalid(m_axis_tvalid),    // output wire m_axis_tvalid
  .m_axis_tready(s_axis_tready),    // input wire m_axis_tready
  .m_axis_tdata(m_axis_tdata)      // output wire [39 : 0] m_axis_tdata
);


axis_dwidth_converter_0 set_coor_conv (
  .aclk(clk),                    // input wire aclk
  .aresetn(!rst),              // input wire aresetn
  .s_axis_tvalid(m_axis_tvalid),  // input wire s_axis_tvalid
  .s_axis_tready(s_axis_tready),  // output wire s_axis_tready
  .s_axis_tdata(m_axis_tdata),    // input wire [39 : 0] s_axis_tdata
  .m_axis_tvalid(s_axis_tvalid_udp),  // output wire m_axis_tvalid
  .m_axis_tready(s_axis_tready_udp),  // input wire m_axis_tready
  .m_axis_tdata(s_axis_tdata_udp)    // output wire [7 : 0] m_axis_tdata
);
assign s_axis_tlast_udp  = 0;




 //AXI-Stream signals
 logic  s_axis_tlast, s_axis_tlast_del;
 assign s_axis_tlast = (row_address_top == 'd431) && (cnt_top_Pclk == 'd660);
/*  logic [399:0] m_axis_tvalid;
 logic [399:0] m_axis_tlast; 
 logic [79:0] m_axis_tready;
 logic [159:0] m_axis_tdata[79:0]; */



//==============================================================================================================//
//                                                                                                              //
//                                        Initial values for sim                                                //
//                                                                                                              //
//==============================================================================================================//
 
logic [9:0]  Y_coor [0:max_number_rows] ;                            //array with Y-coordinates of focal spots
logic [10:0] X_coor [0:max_number_rows][0:max_number_columns];      //array with X-coordinates for correspondig Y
logic[$clog2(max_number_rows)-1:0] cnt_Y_arr = max_number_rows + 1;   //index of Y-coordinate inside Y_coor (the maximum number of different Y-coors of all rows)
logic[$clog2(max_number_columns)-1:0] cnt_X_arr [0:max_number_rows] = '{default: max_number_columns + 1};   //number of spots inside each line

/* 
For simultaion purpose I set the coor-s of left top pixel in each 20x20 pixels focal spot (in real they will come from host).
Here I have 25 lines of spots and each line includes 25 focal spots, 625 20X20 pixels spots total. I don't use pixels on the
boundary of matrix (fisrt top and last down rows and most right and left columns). 
*/
`ifndef SYNTHESIS

int row = 0;
int col = 0;
int error_count = 0;
initial begin
    for (int row = 0; row < cnt_Y_arr; row++) begin
        Y_coor[row] = row * 'd30 + 80;  //last line is Y = 800
        for (int col = 0; col < max_number_columns + 1; col++) 
            X_coor[row][col] = col * 'd50 + 30; //last column is is X = 1260
    end 
end

always_ff @(posedge Pclk_x4_shifted) begin
    if (m_axis_dout_tvalid_x && m_axis_dout_tvalid_y) begin
        real Xc_expected, Yc_expected;
        real Xc_calc, Yc_calc;
        Xc_calc = real'(Xc) + (real'(Xc_frac) / 256.0);
        Yc_calc = real'(Yc) + (real'(Yc_frac) / 256.0);
        testbench.get_centroid(X_coor[row][col], Y_coor[row], Xc_expected, Yc_expected);
        $display("Square [%0d][%0d] at (Y=%0d, X=%0d) -> Expected center: X=%0.2f, Y=%0.2f -> Calculated center: X=%0.2f, Y=%0.2f", 
        row, col, Y_coor[row], X_coor[row][col], Xc_expected, Yc_expected, Xc_calc, Yc_calc);
        
        if (check(Xc_calc, Xc_expected) >= 0.5 || check(Yc_calc, Yc_expected) >= 0.5) begin
            $display("TIME: %0t -> Error found", $time);
            error_count++;
        end


        if (col < max_number_columns) begin
            col <= col + 1;
        end else begin
            col <= 0;
            if (row < max_number_rows) begin
                row <= row + 1;
            end else begin
                row <= 0; 
            end
        end
    end
end


function automatic real check(real a, real b);
    return (a > b) ? (a - b) : (b - a);
endfunction

`endif   
assign sending_data_active = 0; 
endmodule
