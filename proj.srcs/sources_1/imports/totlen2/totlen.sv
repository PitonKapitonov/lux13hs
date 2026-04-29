
module totlen (
    input   logic           clk,
    input   logic           srst,
    // doble_row_bot in
    input   logic           s_tvalid,
    output  logic           s_tready,
    input   logic[7:0]      s_tdata,
    input   logic           s_tlast,
    // doble_row_bot out
    output  logic           m_tvalid,
    input   logic           m_tready,
    output  logic[7:0]      m_tdata,
    output  logic           m_tlast,
    // length out
    output  logic           length_tvalid,
    input   logic           length_tready,
    output  logic[15:0]     length_tdata
);

    localparam int Nmax = 810-1;  // number of bytes before doble_row_bot is broken.

    logic max_compare, faux_tlast;
    
    // this fifo buffers the data
    logic data_fifo_full, data_fifo_empty;
    
    totlen_data_fifo data_fifo (
 
        .clk(clk), 
        .full(data_fifo_full),   
        .wr_en(s_tvalid), 
        .din({s_tdata, faux_tlast}),  // we need to control the assertion of s_tlast for the short doble_row_bots.
        .empty(data_fifo_empty), 
        .rd_en(m_tready), 
        .dout({m_tdata, m_tlast}) 
    );
    assign s_tready = ~data_fifo_full;
    assign m_tvalid = ~data_fifo_empty;


    logic count_tvalid, count_tready;
    logic[15:0] count_tdata;


    // this fifo holds the length counts of the doble_row_bots that go into the data fifo.
    logic length_fifo_full, length_fifo_empty;
    
    totlen_length_fifo length_fifo (

        .clk(clk), 
        .full(length_fifo_full),   
        .wr_en(count_tvalid),  
        .din(count_tdata),
        .empty(length_fifo_empty), 
        .rd_en(length_tready), 
        .dout(length_tdata) 
    );
    assign count_tready  = ~length_fifo_full;
    assign length_tvalid = ~length_fifo_empty;
    

    // here below is where we need to break up the doble_row_bots. Maybe a state machine would be nice.
    
    // count bytes
    logic[15:0] count = 0;
    always_ff @(posedge clk) begin
        if ((s_tvalid) && (s_tready)) begin
            if (faux_tlast) begin
                count <= 0;
            end else begin
                count <= count + 1;
            end
        end
    end
    
    assign max_compare = (count == Nmax);
    assign faux_tlast = s_tlast | max_compare;     

    // when the last byte of a doble_row_bot comes, write the count to the length fifo.
    always_comb begin
        if ((s_tvalid) && (s_tready) && (faux_tlast)) begin
            count_tvalid <= 1;
        end else begin
            count_tvalid <= 0;
        end        
    end
    assign count_tdata = count;
    
endmodule


