module BRAM_array (
    input logic clka,clkb,ena,enb,
    output logic [0:319] bram_left_D0_bot, bram_left_D1_bot, bram_left_D2_bot, bram_left_D3_bot, bram_left_D0_top, bram_left_D1_top, bram_left_D2_top, bram_left_D3_top,
    output logic [0:319] bram_right_D0_bot, bram_right_D1_bot, bram_right_D2_bot, bram_right_D3_bot, bram_right_D0_top, bram_right_D1_top, bram_right_D2_top, bram_right_D3_top,
    input logic [7:0] addra,
    input logic [7:0] addrb
    );

typedef struct {
    logic [10:0] column;
    logic        row_offset;
    logic [3:0]  bit_number;
} Serialization_Entry;

typedef Serialization_Entry Serialization_Table [0:19];

    // ST_base_left_D0 for channels 0-19 and 40-59
    localparam Serialization_Table ST_base_left_D0 = '{
        // D0 
        '{ 11'd0,  1'd0,  4'd6 },  
        '{ 11'd0,  1'd0,  4'd2 },  
        '{ 11'd0,  1'd1,  4'd6 },  
        '{ 11'd0,  1'd1,  4'd2 },  
        
        '{ 11'd1,  1'd0,  4'd6 },  
        '{ 11'd1,  1'd0,  4'd2 },  
        '{ 11'd1,  1'd1,  4'd6 },  
        '{ 11'd1,  1'd1,  4'd2 },  
        
        '{ 11'd2,  1'd0,  4'd6 },  
        '{ 11'd2,  1'd0,  4'd2 },  
        '{ 11'd2,  1'd1,  4'd6 },  
        '{ 11'd2,  1'd1,  4'd2 },  
        
        '{ 11'd3,  1'd0,  4'd6 },  
        '{ 11'd3,  1'd0,  4'd2 },  
        '{ 11'd3,  1'd1,  4'd6 },  
        '{ 11'd3,  1'd1,  4'd2 },  
        
        '{ 11'd1,  1'd0,  4'd0 },  
        '{ 11'd3,  1'd0,  4'd0 },  
        '{ 11'd1,  1'd1,  4'd0 },  
        '{ 11'd3,  1'd1,  4'd0 } 
    };


    // ST_base_left_D1 for channels 0-19 and 40-59
    localparam Serialization_Table ST_base_left_D1 = '{
        // D1 
        '{ 11'd0,  1'd0,  4'd7 },  
        '{ 11'd0,  1'd0,  4'd3 },  // 3
        '{ 11'd0,  1'd1,  4'd7 },  // 5
        '{ 11'd0,  1'd1,  4'd3 },  // 7

        '{ 11'd1,  1'd0,  4'd7 },  // 9
        '{ 11'd1,  1'd0,  4'd3 },  // 11
        '{ 11'd1,  1'd1,  4'd7 },  // 13
        '{ 11'd1,  1'd1,  4'd3 },  // 15

        '{ 11'd2,  1'd0,  4'd7 },  // 17
        '{ 11'd2,  1'd0,  4'd3 },  // 19
        '{ 11'd2,  1'd1,  4'd7 },  // 21
        '{ 11'd2,  1'd1,  4'd3 },  // 23

        '{ 11'd3,  1'd0,  4'd7 },  // 25
        '{ 11'd3,  1'd0,  4'd3 },  // 27
        '{ 11'd3,  1'd1,  4'd7 },  // 29
        '{ 11'd3,  1'd1,  4'd3 },  // 31

        '{ 11'd1,  1'd0,  4'd1 },  // 33
        '{ 11'd3,  1'd0,  4'd1 },  // 35
        '{ 11'd1,  1'd1,  4'd1 },  // 37
        '{ 11'd3,  1'd1,  4'd1 }   // 39
    };

    // ST_base_left_D2 for channels 0-19 and 40-59
    localparam Serialization_Table ST_base_left_D2 = '{
        // D2
        '{ 11'd0,  1'd0,  4'd8 }, 
        '{ 11'd0,  1'd0,  4'd4 },  
        '{ 11'd0,  1'd1,  4'd8 }, 
        '{ 11'd0,  1'd1,  4'd4 },  
        
        '{ 11'd1,  1'd0,  4'd8 },  
        '{ 11'd1,  1'd0,  4'd4 },  
        '{ 11'd1,  1'd1,  4'd8 }, 
        '{ 11'd1,  1'd1,  4'd4 },  
        
        '{ 11'd2,  1'd0,  4'd8 },  
        '{ 11'd2,  1'd0,  4'd4 },  
        '{ 11'd2,  1'd1,  4'd8 },  
        '{ 11'd2,  1'd1,  4'd4 }, 
        
        '{ 11'd3,  1'd0,  4'd8 },  
        '{ 11'd3,  1'd0,  4'd4 },  
        '{ 11'd3,  1'd1,  4'd8 },  
        '{ 11'd3,  1'd1,  4'd4 },  
        
        '{ 11'd0,  1'd0,  4'd0 },  
        '{ 11'd2,  1'd0,  4'd0 },  
        '{ 11'd0,  1'd1,  4'd0 }, 
        '{ 11'd2,  1'd1,  4'd0 }
    };


    // ST_base_left_D3 for channels 0-19 and 40-59
    localparam Serialization_Table ST_base_left_D3 = '{
        // D3 
        '{ 11'd0,  1'd0,  4'd9 },  // 0
        '{ 11'd0,  1'd0,  4'd5 },  // 2
        '{ 11'd0,  1'd1,  4'd9 },  // 4
        '{ 11'd0,  1'd1,  4'd5 },  // 6

        '{ 11'd1,  1'd0,  4'd9 },  // 8
        '{ 11'd1,  1'd0,  4'd5 },  // 10
        '{ 11'd1,  1'd1,  4'd9 },  // 12
        '{ 11'd1,  1'd1,  4'd5 },  // 14

        '{ 11'd2,  1'd0,  4'd9 },  // 16
        '{ 11'd2,  1'd0,  4'd5 },  // 18
        '{ 11'd2,  1'd1,  4'd9 },  // 20
        '{ 11'd2,  1'd1,  4'd5 },  // 22

        '{ 11'd3,  1'd0,  4'd9 },  // 24
        '{ 11'd3,  1'd0,  4'd5 },  // 26
        '{ 11'd3,  1'd1,  4'd9 },  // 28
        '{ 11'd3,  1'd1,  4'd5 },  // 30

        '{ 11'd0,  1'd0,  4'd1 },  // 32
        '{ 11'd2,  1'd0,  4'd1 },  // 34
        '{ 11'd0,  1'd1,  4'd1 },  // 36
        '{ 11'd2,  1'd1,  4'd1 }   // 38
    };

    // ST_base_right_D0 for channels 20-39 and 60-79
    localparam Serialization_Table ST_base_right_D0 = '{
        // D0 
        '{ 11'd1291, 1'd1,  4'd0 },  
        '{ 11'd1289, 1'd1,  4'd0 },  
        '{ 11'd1291, 1'd0,  4'd0 },  
        '{ 11'd1289, 1'd0,  4'd0 },  
        
        '{ 11'd1291, 1'd1,  4'd2 },  
        '{ 11'd1291, 1'd1,  4'd6 },
        '{ 11'd1291, 1'd0,  4'd2 }, 
        '{ 11'd1291, 1'd0,  4'd6 },  
        
        '{ 11'd1290, 1'd1,  4'd2 }, 
        '{ 11'd1290, 1'd1,  4'd6 }, 
        '{ 11'd1290, 1'd0,  4'd2 }, 
        '{ 11'd1290, 1'd0,  4'd6 },  
        
        '{ 11'd1289, 1'd1,  4'd2 },  
        '{ 11'd1289, 1'd1,  4'd6 },  
        '{ 11'd1289, 1'd0,  4'd2 },  
        '{ 11'd1289, 1'd0,  4'd6 },  
        
        '{ 11'd1288, 1'd1,  4'd2 }, 
        '{ 11'd1288, 1'd1,  4'd6 },  
        '{ 11'd1288, 1'd0,  4'd2 },  
        '{ 11'd1288, 1'd0,  4'd6 }
    };



    // ST_base_right_D1 for channels 20-39 and 60-79
    localparam Serialization_Table ST_base_right_D1 = '{
        // D1 
        '{ 11'd1291, 1'd1,  4'd1 },  // 0
        '{ 11'd1289, 1'd1,  4'd1 },  // 2
        '{ 11'd1291, 1'd0,  4'd1 },  // 4
        '{ 11'd1289, 1'd0,  4'd1 },  // 6

        '{ 11'd1291, 1'd1,  4'd3 },  // 8
        '{ 11'd1291, 1'd1,  4'd7 },  // 10
        '{ 11'd1291, 1'd0,  4'd3 },  // 12
        '{ 11'd1291, 1'd0,  4'd7 },  // 14

        '{ 11'd1290, 1'd1,  4'd3 },  // 16
        '{ 11'd1290, 1'd1,  4'd7 },  // 18
        '{ 11'd1290, 1'd0,  4'd3 },  // 20
        '{ 11'd1290, 1'd0,  4'd7 },  // 22

        '{ 11'd1289, 1'd1,  4'd3 },  // 24
        '{ 11'd1289, 1'd1,  4'd7 },  // 26
        '{ 11'd1289, 1'd0,  4'd3 },  // 28
        '{ 11'd1289, 1'd0,  4'd7 },  // 30

        '{ 11'd1288, 1'd1,  4'd3 },  // 32
        '{ 11'd1288, 1'd1,  4'd7 },  // 34
        '{ 11'd1288, 1'd0,  4'd3 },  // 36
        '{ 11'd1288, 1'd0,  4'd7 }   // 38
    };




    // ST_base_right_D2 for channels 20-39 and 60-79
    localparam Serialization_Table ST_base_right_D2 = '{
        // D2
        '{ 11'd1290, 1'd1,  4'd0 }, 
        '{ 11'd1288, 1'd1,  4'd0 },  
        '{ 11'd1290, 1'd0,  4'd0 },  
        '{ 11'd1288, 1'd0,  4'd0 },  
        
        '{ 11'd1291, 1'd1,  4'd4 },  
        '{ 11'd1291, 1'd1,  4'd8 },  
        '{ 11'd1291, 1'd0,  4'd4 },  
        '{ 11'd1291, 1'd0,  4'd8 },  
        
        '{ 11'd1290, 1'd1,  4'd4 }, 
        '{ 11'd1290, 1'd1,  4'd8 },  
        '{ 11'd1290, 1'd0,  4'd4 },  
        '{ 11'd1290, 1'd0,  4'd8 },  
        
        '{ 11'd1289, 1'd1,  4'd4 },  
        '{ 11'd1289, 1'd1,  4'd8 },  
        '{ 11'd1289, 1'd0,  4'd4 }, 
        '{ 11'd1289, 1'd0,  4'd8 },  
        
        '{ 11'd1288, 1'd1,  4'd4 }, 
        '{ 11'd1288, 1'd1,  4'd8 },  
        '{ 11'd1288, 1'd0,  4'd4 },  
        '{ 11'd1288, 1'd0,  4'd8 }
    };

    // ST_base_right_D3 for channels 20-39 and 60-79
    localparam Serialization_Table ST_base_right_D3 = '{
        //  D3 
        '{ 11'd1290, 1'd1,  4'd1 },  // 0
        '{ 11'd1288, 1'd1,  4'd1 },  // 2
        '{ 11'd1290, 1'd0,  4'd1 },  // 4
        '{ 11'd1288, 1'd0,  4'd1 },  // 6

        '{ 11'd1291, 1'd1,  4'd5 },  // 8
        '{ 11'd1291, 1'd1,  4'd9 },  // 10
        '{ 11'd1291, 1'd0,  4'd5 },  // 12
        '{ 11'd1291, 1'd0,  4'd9 },  // 14

        '{ 11'd1290, 1'd1,  4'd5 },  // 16
        '{ 11'd1290, 1'd1,  4'd9 },  // 18
        '{ 11'd1290, 1'd0,  4'd5 },  // 20
        '{ 11'd1290, 1'd0,  4'd9 },  // 22

        '{ 11'd1289, 1'd1,  4'd5 },  // 24
        '{ 11'd1289, 1'd1,  4'd9 },  // 26
        '{ 11'd1289, 1'd0,  4'd5 },  // 28
        '{ 11'd1289, 1'd0,  4'd9 },  // 30

        '{ 11'd1288, 1'd1,  4'd5 },  // 32
        '{ 11'd1288, 1'd1,  4'd9 },  // 34
        '{ 11'd1288, 1'd0,  4'd5 },  // 36
        '{ 11'd1288, 1'd0,  4'd9 }   // 38
    };
    
// 8 отдельных BRAM

(* ram_style = "block" *) reg [0:319] bram_left_D0  [0:161];
(* ram_style = "block" *) reg [0:319] bram_left_D1  [0:161];
(* ram_style = "block" *) reg [0:319] bram_left_D2  [0:161];
(* ram_style = "block" *) reg [0:319] bram_left_D3  [0:161];

(* ram_style = "block" *) reg [0:319] bram_right_D0 [0:161];
(* ram_style = "block" *) reg [0:319] bram_right_D1 [0:161];
(* ram_style = "block" *) reg [0:319] bram_right_D2 [0:161];
(* ram_style = "block" *) reg [0:319] bram_right_D3 [0:161];






typedef logic [0:319] my_array_t [0:161];

function automatic my_array_t init_left_D0();
    my_array_t tmp;
    for (int clk = 0; clk < 162; clk++) begin
        int left_offset = (clk == 0) ? 0 : (clk == 1) ? 4 : (644 - (clk - 2) * 4);
        for (int i = 0; i < 20; i++) begin
            tmp[clk][i*16 +: 16] = {
                11'(ST_base_left_D0[i].column + left_offset),
                1'(ST_base_left_D0[i].row_offset),
                4'(ST_base_left_D0[i].bit_number)
            };
        end
    end
    return tmp;
endfunction

function automatic my_array_t init_left_D1();
    my_array_t tmp;
    for (int clk = 0; clk < 162; clk++) begin
        int left_offset = (clk == 0) ? 0 : (clk == 1) ? 4 : (644 - (clk - 2) * 4);
        for (int i = 0; i < 20; i++) begin
            tmp[clk][i*16 +: 16] = {
                11'(ST_base_left_D1[i].column + left_offset),
                1'(ST_base_left_D1[i].row_offset),
                4'(ST_base_left_D1[i].bit_number)
            };
        end
    end
    return tmp;
endfunction

function automatic my_array_t init_left_D2();
    my_array_t tmp;
    for (int clk = 0; clk < 162; clk++) begin
        int left_offset = (clk == 0) ? 0 : (clk == 1) ? 4 : (644 - (clk - 2) * 4);
        for (int i = 0; i < 20; i++) begin
            tmp[clk][i*16 +: 16] = {
                11'(ST_base_left_D2[i].column + left_offset),
                1'(ST_base_left_D2[i].row_offset),
                4'(ST_base_left_D2[i].bit_number)
            };
        end
    end
    return tmp;
endfunction


function automatic my_array_t init_left_D3();
    my_array_t tmp;
    for (int clk = 0; clk < 162; clk++) begin
        int left_offset = (clk == 0) ? 0 : (clk == 1) ? 4 : (644 - (clk - 2) * 4);
        for (int i = 0; i < 20; i++) begin
            tmp[clk][i*16 +: 16] = {
                11'(ST_base_left_D3[i].column + left_offset),
                1'(ST_base_left_D3[i].row_offset),
                4'(ST_base_left_D3[i].bit_number)
            };
        end
    end
    return tmp;
endfunction


function automatic my_array_t init_right_D0();
    my_array_t tmp;
    for (int clk = 0; clk < 162; clk++) begin
        int right_offset = (clk == 0) ? 0 : (clk == 1) ? 4 : (-640 + (clk - 2) * 4);
        for (int i = 0; i < 20; i++) begin
            tmp[clk][i*16 +: 16] = {
                11'(ST_base_right_D0[i].column + right_offset),
                1'(ST_base_right_D0[i].row_offset),
                4'(ST_base_right_D0[i].bit_number)
            };
        end
    end
    return tmp;
endfunction


function automatic my_array_t init_right_D1();
    my_array_t tmp;
    for (int clk = 0; clk < 162; clk++) begin
        int right_offset = (clk == 0) ? 0 : (clk == 1) ? 4 : (-640 + (clk - 2) * 4);
        for (int i = 0; i < 20; i++) begin
            tmp[clk][i*16 +: 16] = {
                11'(ST_base_right_D1[i].column + right_offset),
                1'(ST_base_right_D1[i].row_offset),
                4'(ST_base_right_D1[i].bit_number)
            };
        end
    end
    return tmp;
endfunction


function automatic my_array_t init_right_D2();
    my_array_t tmp;
    for (int clk = 0; clk < 162; clk++) begin
        int right_offset = (clk == 0) ? 0 : (clk == 1) ? 4 : (-640 + (clk - 2) * 4);
        for (int i = 0; i < 20; i++) begin
            tmp[clk][i*16 +: 16] = {
                11'(ST_base_right_D2[i].column + right_offset),
                1'(ST_base_right_D2[i].row_offset),
                4'(ST_base_right_D2[i].bit_number)
            };
        end
    end
    return tmp;
endfunction


function automatic my_array_t init_right_D3();
    my_array_t tmp;
    for (int clk = 0; clk < 162; clk++) begin
        int right_offset = (clk == 0) ? 0 : (clk == 1) ? 4 : (-640 + (clk - 2) * 4);
        for (int i = 0; i < 20; i++) begin
            tmp[clk][i*16 +: 16] = {
                11'(ST_base_right_D3[i].column + right_offset),
                1'(ST_base_right_D3[i].row_offset),
                4'(ST_base_right_D3[i].bit_number)
            };
        end
    end
    return tmp;
endfunction

// integer clk, i;
/* initial begin
    for (int clk = 0; clk < 162; clk++) begin : fill_ram_162_depth
         logic [10:0] left_offset = 
            (clk == 0) ? 11'd0 :
            (clk == 1) ? 11'd4 :
            11'(644 - (clk - 2) * 4);
            
         logic [10:0] right_offset = 
            (clk == 0) ? 11'd0  :
            (clk == 1) ? 11'd4 :
            11'(-640 + (clk - 2) * 4);
            
        for (int i = 0; i < 20; i++) begin : fill_ram_row_320_width
            // ST_left_D0
             bram_left_D0_reg[clk][i*16 +: 16] = {
                11'(ST_base_left_D0[i].column + left_offset),
                1'(ST_base_left_D0[i].row_offset),
                4'(ST_base_left_D0[i].bit_number)
            };
            
            // ST_left_D1
              bram_left_D1_reg[clk][i*16 +: 16] = { 
                11'(ST_base_left_D1[i].column + left_offset),
                1'(ST_base_left_D1[i].row_offset),
                4'(ST_base_left_D1[i].bit_number)
            };
            // ST_left_D2
              bram_left_D2_reg[clk][i*16 +: 16] = { 
                11'(ST_base_left_D2[i].column + left_offset),
                1'(ST_base_left_D2[i].row_offset),
                4'(ST_base_left_D2[i].bit_number)
            };
            // ST_left_D3
             bram_left_D3_reg[clk][i*16 +: 16] = { 
                11'(ST_base_left_D3[i].column + left_offset),
                1'(ST_base_left_D3[i].row_offset),
                4'(ST_base_left_D3[i].bit_number)
            };
            // ST_right_D0
              bram_right_D0_reg[clk][i*16 +: 16] = { 
                11'(ST_base_right_D0[i].column + right_offset),
                1'(ST_base_right_D0[i].row_offset),
                4'(ST_base_right_D0[i].bit_number)
            };
            // ST_right_D1
              bram_right_D1_reg[clk][i*16 +: 16] = { 
                11'(ST_base_right_D1[i].column + right_offset),
                1'(ST_base_right_D1[i].row_offset),
                4'(ST_base_right_D1[i].bit_number)
            };
      
            // ST_right_D2
              bram_right_D2_reg[clk][i*16 +: 16] = { 
                11'(ST_base_right_D2[i].column + right_offset),
                1'(ST_base_right_D2[i].row_offset),
                4'(ST_base_right_D2[i].bit_number)
            };
            // ST_right_D3
            bram_right_D3_reg[clk][i*16 +: 16] = { 
                11'(ST_base_right_D3[i].column + right_offset),
                1'(ST_base_right_D3[i].row_offset),
                4'(ST_base_right_D3[i].bit_number)
            };
        end
    end
end
 */
localparam [0:319] bram_left_D0_reg [0:161] = init_left_D0();

localparam [0:319] bram_left_D1_reg [0:161] = init_left_D1();

localparam [0:319] bram_left_D2_reg [0:161] = init_left_D2();

localparam [0:319] bram_left_D3_reg [0:161] = init_left_D3();


localparam [0:319] bram_right_D0_reg [0:161] = init_right_D0();

localparam [0:319] bram_right_D1_reg [0:161] = init_right_D1();

localparam [0:319] bram_right_D2_reg [0:161] = init_right_D2();

localparam [0:319] bram_right_D3_reg [0:161] = init_right_D3();

initial begin
for (int q = 0; q < 162; q++) begin


        bram_left_D0[q] = bram_left_D0_reg[q];

        bram_left_D1[q] = bram_left_D1_reg[q];

        bram_left_D2[q] = bram_left_D2_reg[q];

        bram_left_D3[q] =bram_left_D3_reg[q];


        bram_right_D0[q]= bram_right_D0_reg[q];

        bram_right_D1[q]= bram_right_D1_reg[q];

        bram_right_D2[q]=bram_right_D2_reg[q];

        bram_right_D3[q]= bram_right_D3_reg[q];

end

end

always @(posedge clkb) begin
    if (enb) begin  
        bram_left_D0_bot <= bram_left_D0[addrb];
        bram_left_D1_bot <= bram_left_D1[addrb];
        bram_left_D2_bot <= bram_left_D2[addrb];
        bram_left_D3_bot <= bram_left_D3[addrb];

        bram_right_D0_bot <= bram_right_D0[addrb];
        bram_right_D1_bot <= bram_right_D1[addrb];
        bram_right_D2_bot <= bram_right_D2[addrb];
        bram_right_D3_bot <= bram_right_D3[addrb];
    end
end
always @(posedge clka) begin
    if (ena) begin
        bram_left_D0_top <= bram_left_D0[addra];
        bram_left_D1_top <= bram_left_D1[addra];
        bram_left_D2_top <= bram_left_D2[addra];
        bram_left_D3_top <= bram_left_D3[addra];

        bram_right_D0_top <= bram_right_D0[addra];
        bram_right_D1_top <= bram_right_D1[addra];
        bram_right_D2_top <= bram_right_D2[addra];
        bram_right_D3_top <= bram_right_D3[addra];


    end
end

endmodule











