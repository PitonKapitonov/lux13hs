`timescale 1ns / 1ps
module focal_spots_processing#(
    parameter max_number_rows    = 25,
    parameter max_number_columns = 25
)(
    input logic             clk,
    input logic             rst,
    input logic [9:0]       double_row_bot [1295:0][1:0],
    input logic [9:0]       double_row_top [1295:0][1:0],
    input logic [8:0]       row_address_top, 
    input logic [8:0]       row_address_bot,    
    input logic [7:0]       cnt_bot_Pclk,
    input logic [7:0]       cnt_top_Pclk,
    input logic             process_on,
    input logic             Pclk_x4_shifted,
    input logic             enable_read_bot,
    input logic             enable_read_top,
    
    output logic [10:0] Xc_result_reg [0:max_number_rows][0:max_number_columns],// = '{default:35'd0};
    output logic [10:0] Yc_result_reg [0:max_number_rows][0:max_number_columns]// = '{default:35'd0};
    
    );
    
localparam  focal_width  = 20;                                                        //focal_width of focal spot
localparam  focal_height = 20;                                                        //focal_height of focal spot
//localparam int max_number_rows = 864/focal_height + 1;                                      //maximum number of rows of spots
//localparam int max_number_columns = 1296/focal_width + 1;                                   //maximum number of columns of spots
logic [9:0]  array_of_Y [0:max_number_rows] ;//= '{default: 6}                             //array with Y-coordinates of focal spots
logic [10:0] array_of_X [0:max_number_rows][0:max_number_columns]; //  = '{default: 6}     //array with X-coordinates for correspondig Y
logic [4:0]  spot_size  [0:max_number_rows][0:max_number_columns][0:1] = '{default: 20};    //array with height and width of each spot: [0] - height, [1] - width
logic[$clog2(max_number_rows)-1:0] cnt_Y_arr = max_number_rows;                                             //index of Y-coordinate inside array_of_Y (the maximum number of different Y-coors of all rows)
logic[$clog2(max_number_columns)-1:0] cnt_X_arr [0:max_number_rows] = '{default: max_number_columns};         //index of X-coordinate for each Y-coordinate inside array_of_X (the maximim mumber of different X-ccors inside each row)


//initial begin
//  array_of_Y[0] = 'd50;
//  array_of_Y[1] = 'd150;
//  array_of_Y[2] = 'd250;
//  array_of_Y[3] = 'd350;
//  array_of_Y[4] = 'd450;
//  array_of_Y[5] = 'd550;
//  array_of_Y[6] = 'd650;
//  array_of_Y[7] = 'd750;
//  array_of_Y[8] = 'd800;
//  for (int row = 0; row < cnt_Y_arr; row = row + 1) begin
//      cnt_X_arr[row] = row + 2;                  //special number of spots in each row
//      array_of_X[row][0] = 'd100;
//      array_of_X[row][1] = 'd200;
//      array_of_X[row][2] = 'd300;
//      array_of_X[row][3] = 'd400;
//      array_of_X[row][4] = 'd500;
//      array_of_X[row][5] = 'd600;
//      array_of_X[row][6] = 'd700;
//      array_of_X[row][7] = 'd800;
//      array_of_X[row][8] = 'd900;
//      array_of_X[row][9] = 'd1000;
//      // for (int col = 0; col < cnt_X_arr[row]; col = col + 1) begin     
//      //     spot_size[row][col][0] = 20 + 2*(row + col);             //special height for each spot on row
//      //     spot_size[row][col][1] = 20 + 2*(row + col);            //special width for each spot on row
//      // end
//  end 
//end


/* 
I have 2 arrays: one for Y-coordinates and one for X-coordinates. The array_of_Y is 1-dimension, array_of_X is 2-dimension, because
it consists of set of X-coordinates for each Y-coordinate. I fullfill this arrays while parsing incoming command from host which include 
the number of spots and their coordinates. The counter cnt_Y_arr is increasing if current value of Y is not equal the previous value, that means
a new value of Y-coordinate were obtained. The counter of cnt_X_arr is increasing if current value of Y is equal to the previous value, that means 
we are obtaining the set of X-coordinates for current Y-coordinate. The counter of cnt_X_arr is 2-dimension because I want to count how much X-coordinates
I have for each value of Y-coordinate. After this I have full information of number of rows of spots and how much spots there is in each row. 
'
                    //    Y1   : X1 + focal_width || X2 + focal_width || X3 + focal_width || X4 + focal_width || X5 + focal_width || X6 + focal_width || X7 + focal_width        //  array_of_X[0]
                    //    Y1+1 : X1 + focal_width || X2 + focal_width || X3 + focal_width || X4 + focal_width || X5 + focal_width || X6 + focal_width || X7 + focal_width        //  array_of_X[0]
first row           //    Y1+2 : X1 + focal_width || X2 + focal_width || X3 + focal_width || X4 + focal_width || X5 + focal_width || X6 + focal_width || X7 + focal_width        //  array_of_X[0]
of spots            //    Y1+3 : X1 + focal_width || X2 + focal_width || X3 + focal_width || X4 + focal_width || X5 + focal_width || X6 + focal_width || X7 + focal_width        //  array_of_X[0]
focal_height = 5    //    Y1+4 : X1 + focal_width || X2 + focal_width || X3 + focal_width || X4 + focal_width || X5 + focal_width || X6 + focal_width || X7 + focal_width        //  cnt_X_arr[0] = 7    //The set of X-coor is same inside one spot for all Y-coor of this spot

                    //    Y2   : X'1 + focal_width || X'2 + focal_width || X'3 + focal_width || X'4 + focal_width || X'5 + focal_width || X'6 + focal_width || X'7 + focal_width || X'8 + focal_width       //  array_of_X[1]
                    //    Y2+1 : X'1 + focal_width || X'2 + focal_width || X'3 + focal_width || X'4 + focal_width || X'5 + focal_width || X'6 + focal_width || X'7 + focal_width || X'8 + focal_width       //  array_of_X[1]
second row          //    Y2+2 : X'1 + focal_width || X'2 + focal_width || X'3 + focal_width || X'4 + focal_width || X'5 + focal_width || X'6 + focal_width || X'7 + focal_width || X'8 + focal_width       //  array_of_X[1]
of spots            //    Y2+3 : X'1 + focal_width || X'2 + focal_width || X'3 + focal_width || X'4 + focal_width || X'5 + focal_width || X'6 + focal_width || X'7 + focal_width || X'8 + focal_width       //  array_of_X[1]
focal_height = 5    //    Y2+4 : X'1 + focal_width || X'2 + focal_width || X'3 + focal_width || X'4 + focal_width || X'5 + focal_width || X'6 + focal_width || X'7 + focal_width || X'8 + focal_width       //  cnt_X_arr[1] = 8

                    //    Y3   : X''1 + focal_width || X''2 + focal_width || X''3 + focal_width || X''4 + focal_width || X''5 + focal_width || X''6 + focal_width || X''7 + focal_width || X''8 + focal_width || X''9 + focal_width        //  array_of_X[2]
                    //    Y3+1 : X''1 + focal_width || X''2 + focal_width || X''3 + focal_width || X''4 + focal_width || X''5 + focal_width || X''6 + focal_width || X''7 + focal_width || X''8 + focal_width || X''9 + focal_width        //  array_of_X[2]
third row           //    Y3+2 : X''1 + focal_width || X''2 + focal_width || X''3 + focal_width || X''4 + focal_width || X''5 + focal_width || X''6 + focal_width || X''7 + focal_width || X''8 + focal_width || X''9 + focal_width        //  array_of_X[2]
of spots            //    Y3+3 : X''1 + focal_width || X''2 + focal_width || X''3 + focal_width || X''4 + focal_width || X''5 + focal_width || X''6 + focal_width || X''7 + focal_width || X''8 + focal_width || X''9 + focal_width        //  array_of_X[2]
focal_height = 5    //    Y3+4 : X''1 + focal_width || X''2 + focal_width || X''3 + focal_width || X''4 + focal_width || X''5 + focal_width || X''6 + focal_width || X''7 + focal_width || X''8 + focal_width || X''9 + focal_width        //  cnt_X_arr[2] = 9

Y2 - Y1 = Y3 - Y2 = focal_height of spot

array_of_Y[0] - initial value of Y-coordinate for fisrt row of spots. I need to take the number of rows = 'focal_height' downstream the first row.
The set of X-coor is constant for this rows.

row_address_bot takes values of 0,2,4,6,8 and so on
row_address_top takes valuse of 1,3,5,7,9...
So, I can use this addresses to derminate the fisrt row of spots of interest. This condition is something like this:
row_address_bot == array_of_Y[0] || row_address_top == array_of_Y[0].

I have FULL double_row_bot or double_row_top when the cnt_bot_Pclk = 163 || 164 or the cnt_top_Pclk = 163 || 164. If so, I can calculate
everything I need. I will calculate the centroids for each set of X-coor for initial row determined by array_of_Y[0] and continue for the next 
rows until array_of_Y[0] + k < focal_height, where k - counter inside this row.
*/


logic read_finished = 0;


logic [31:0] sum_Ix [0:max_number_rows][0:max_number_columns] = '{default:32'd0};
logic [31:0] sum_Iy [0:max_number_rows][0:max_number_columns] = '{default:32'd0};
logic [21:0] sum_I [0:max_number_rows][0:max_number_columns]= '{default:22'd0};
logic[$clog2(focal_height)-1:0]  h  = 'd0;



/* I use the conditions of  (2*row_address_bot + i >= array_of_Y[r]+f[r][c]) and  (2*row_address_top + i >= array_of_Y[r]+f[r][c])
to check weather I'm inside the spot. It's neccesary because it's possible that array_of_Y[r] is equal 51 for example and I don't 
need to process double_row_bot with the address of 50. It's condition that works on the top of spot.

On the other hand the condition that works on the bottom of spot is (f[r][c] + i) < spot_size[r][c][0]. For example if spot height
is eqaul 19 I need to stop before f[r][c] will be 20. The wright moment is f[r][c] = 18 and i = 1.
*/
//f[r][c] - height of spot 

logic [5:0] w = 6'd0;
logic [$clog2(max_number_rows)-1:0] r = 0;
logic row_done;
always_ff @ (posedge Pclk_x4_shifted) begin                                                                 
    if ((!enable_read_bot | !enable_read_top) && row_address_bot != 'd511 && row_address_top != 'd511) begin     
        if (h < focal_height) begin
            if (w < focal_width) begin            
                if ((h == 0) && array_of_Y[r]&1 && (((array_of_Y[r] == (2*row_address_bot + 1)) && !enable_read_bot && cnt_bot_Pclk != 0) || ((array_of_Y[r] == (2*row_address_top + 1)) && !enable_read_top && cnt_top_Pclk != 0))) begin
                    for (int c = 0; c < cnt_X_arr[r]; c++) begin  
                        sum_Ix[r][c] <= sum_Ix[r][c] + ((array_of_Y[r] == (2*row_address_bot + 1))? double_row_bot[array_of_X[r][c]+ w][1] * (array_of_X[r][c] + w): 
                                                                                                    double_row_top[array_of_X[r][c]+ w][1] * (array_of_X[r][c] + w));    

                        sum_Iy[r][c] <= sum_Iy[r][c] + ((array_of_Y[r] == (2*row_address_bot + 1))? double_row_bot[array_of_X[r][c]+ w][1] * array_of_Y[r]: 
                                                                                                    double_row_top[array_of_X[r][c]+ w][1] * array_of_Y[r]);

                        sum_I[r][c]  <= sum_I[r][c]  + ((array_of_Y[r] == (2*row_address_bot + 1))? double_row_bot[array_of_X[r][c]+ w][1] : 
                                                                                                    double_row_top[array_of_X[r][c]+ w][1]);    
                    end
                    w <= w + 1;
                    if (w == (focal_width - 1)) h <= h + 1;
                end 
                else if (!((array_of_Y[r] + h)&1) && ((h + 1) != focal_height) && ((((array_of_Y[r] + h) == 2*row_address_bot) && !enable_read_bot && cnt_bot_Pclk != 0) || (((array_of_Y[r] + h) == 2*row_address_top) && !enable_read_top && cnt_top_Pclk != 0))) begin
                    for (int c = 0; c < cnt_X_arr[r]; c++) begin  
                        sum_Ix[r][c] <= sum_Ix[r][c] + (((array_of_Y[r] + h) == (2*row_address_bot))? (double_row_bot[array_of_X[r][c]+ w][0] + double_row_bot[array_of_X[r][c]+ w][1]) * (array_of_X[r][c] + w): 
                                                                                                      (double_row_top[array_of_X[r][c]+ w][0] + double_row_top[array_of_X[r][c]+ w][1]) * (array_of_X[r][c] + w));    

                        sum_Iy[r][c] <= sum_Iy[r][c] + (((array_of_Y[r] + h) == (2*row_address_bot))? double_row_bot[array_of_X[r][c]+ w][0] * (array_of_Y[r] + h) + double_row_bot[array_of_X[r][c]+ w][1] * (array_of_Y[r] + h + 1): 
                                                                                                      double_row_top[array_of_X[r][c]+ w][0] * (array_of_Y[r] + h) + double_row_top[array_of_X[r][c]+ w][1] * (array_of_Y[r] + h + 1));
 
                        sum_I[r][c]  <= sum_I[r][c]  + (((array_of_Y[r] + h) == (2*row_address_bot))? double_row_bot[array_of_X[r][c]+ w][0] + double_row_bot[array_of_X[r][c]+ w][1]: 
                                                                                                      double_row_top[array_of_X[r][c]+ w][0] + double_row_top[array_of_X[r][c]+ w][1]);    
                    end
                    w <= w + 1;
                    if (w == (focal_width -1)) h <= h + 2;
                end 
                else if (!((array_of_Y[r] + h)&1) && ((h + 1) == focal_height) && ((((array_of_Y[r] + h) == 2*row_address_bot) && !enable_read_bot && cnt_bot_Pclk != 0) || (((array_of_Y[r] + h) == 2*row_address_top) && !enable_read_top && cnt_top_Pclk != 0 ))) begin
                    for (int c = 0; c < cnt_X_arr[r]; c++) begin  
                        sum_Ix[r][c] <= sum_Ix[r][c] + ((array_of_Y[r] == (2*row_address_bot))? double_row_bot[array_of_X[r][c]+ w][0] * (array_of_X[r][c] + w): 
                                                                                                double_row_top[array_of_X[r][c]+ w][0] * (array_of_X[r][c] + w));    

                        sum_Iy[r][c] <= sum_Iy[r][c] + ((array_of_Y[r] == (2*row_address_bot))? double_row_bot[array_of_X[r][c]+ w][0] * array_of_Y[r]: 
                                                                                                double_row_top[array_of_X[r][c]+ w][0] * array_of_Y[r]);

                        sum_I[r][c]  <= sum_I[r][c]  + ((array_of_Y[r] == (2*row_address_bot))? double_row_bot[array_of_X[r][c]+ w][0] : 
                                                                                                double_row_top[array_of_X[r][c]+ w][0]);       
                    end
                    w <= w + 1;
                    if (w == (focal_width -1)) h <= h + 1;
                end 
                
            end else w <= 0;
        end else h <= 0;
    end
    if (row_done) begin 
        r <= r + 1;
        for (int c = 0; c < cnt_X_arr[r]; c++) begin  
            Xc_result_reg[r][c] <= sum_Ix[r][c]/sum_I[r][c];
            Yc_result_reg[r][c] <= sum_Iy[r][c]/sum_I[r][c];
        end
    end
end



always_comb begin
   row_done = 0;
   if (h >= focal_height) row_done = 1'b1; 
end


endmodule
