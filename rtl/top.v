//`define __ICARUS__ 0

module top (
    input wire clk,	          // 25MHz clock input
    //input wire RSTN_BUTTON,   // rstn,
    //input wire rx,            // Tx from the computer
    output wire [15:0] PMOD,  // VGA PMOD
    //segments outputs
  );

//--------------------
//Local parameters
//--------------------
    //V for Video output resolution
    localparam Vwidth=640;
    localparam Vheight=480;
    //C for Character resolution
    localparam Cwidth=8;
    localparam Cheight=16;
    //Number of columns and rows
    localparam Ncol=Vwidth/Cwidth;
    localparam Nrow=Vheight/Cheight;

//--------------------
//IO pins assigments
//--------------------
    //Names of the signals on digilent VGA PMOD adapter
    wire R0, R1, R2, R3; // red
    wire G0, G1, G2, G3; // green
    wire B0, B1, B2, B3; // blue
    wire HS,VS;
    //wire rstn;
    //pmod1
    assign PMOD[0] = B0;
    assign PMOD[1] = B1;
    assign PMOD[2] = B2;
    assign PMOD[3] = B3;
    assign PMOD[4] = R0;
    assign PMOD[5] = R1;
    assign PMOD[6] = R2;
    assign PMOD[7] = R3;
    //pmod2
    assign PMOD[8] = HS;
    assign PMOD[9] = VS;
    assign PMOD[10] = 0;
    assign PMOD[11] = 0;
    assign PMOD[12] = G0;
    assign PMOD[13] = G1;
    assign PMOD[14] = G2;
    assign PMOD[15] = G3;
    //sync reset from button and enable pull up
    /*wire rstn_button_int; //internal signal after pullups
    reg bf1_rstn;
    reg bf2_rstn;
    always @(posedge px_clk) begin
        bf1_rstn <= rstn_button_int;
        bf2_rstn <= bf1_rstn;
    end
    assign  rstn = bf2_rstn;*/

//--------------------
// IP internal signals
//--------------------
    wire [9:0] x_px; // current X position of the pixel
    wire [9:0] y_px; // current Y position of the pixel
    //wire px_clk;
    wire activevideo; 
    VGAsyncGen vga_inst( .clk(clk), .hsync(HS), .vsync(VS), .x_px(x_px), .y_px(y_px), .activevideo(activevideo));
    //Internal registers for current pixel color
    reg [3:0] R_int = 4'b1111; //white
    reg [3:0] G_int = 4'b1111;
    reg [3:0] B_int = 4'b1111;
    //RGB values assigment from pixel color register
    assign R0 = activevideo ? R_int[0] :0; 
    assign R1 = activevideo ? R_int[1] :0; 
    assign R2 = activevideo ? R_int[2] :0; 
    assign R3 = activevideo ? R_int[3] :0; 
    assign G0 = activevideo ? G_int[0] :0; 
    assign G1 = activevideo ? G_int[1] :0; 
    assign G2 = activevideo ? G_int[2] :0; 
    assign G3 = activevideo ? G_int[3] :0; 
    assign B0 = activevideo ? B_int[0] :0; 
    assign B1 = activevideo ? B_int[1] :0; 
    assign B2 = activevideo ? B_int[2] :0; 
    assign B3 = activevideo ? B_int[3] :0; 
    
    //Track current column and row
    `ifdef ASSERTIONS
        assert Cwidth == 8;
        assert Cheight == 16;
        //if that assertions fail current_col current_row range need to change
        //along other parameters as the lookup and pixel within image
    `endif
    wire [9:0] current_col;
    wire [9:0] current_row;
    assign current_col = x_px[9:3]; // column of the current tile
    assign current_row = y_px[9:4]; // row of the current tile
    //x_img and y_img are used to index within the look up
    wire [2:0] x_img; 
    wire [3:0] y_img;
    assign x_img = x_px[2:0]; // indicate X position inside the tile (0-7)
    assign y_img = y_px[3:0]; // inidicate Y position inside the tile (0-15)

    wire wr_en;
    assign wr_en = 1'b0;
    wire [6:0] col_w;
    wire [4:0] row_w;
    assign col_w = 7'd0;
    assign row_w = 5'd0;
    wire [6:0] din;
    assign din = 7'd0;

    reg [6:0] char_addr; // address of the char in the bitmap, ASCII code
    reg [0:Cheight-1][Cwidth-1:0] char; // bitmap of 1 character
    
    buffer buf_inst( .clk(clk), .wr_en(wr_en), .col_w(col_w), .row_w(row_w), .col_r(current_col), .row_r(current_row), .din(din), .dout(char_addr));
    fontMem fmem_inst( .clk(clk), .addr(char_addr), .dout(char));

    //Update next pixel color
    always @(posedge clk, negedge rstn) begin
        /*
        if (!rstn) begin
                R_int <= 4'b0;
                G_int <= 4'b0;
                B_int <= 4'b0;
        end else
        */
        //remember that there is a section outside the screen
        //if We don't use the active video pixel value will increase in the 
        //section outside the display as well.
        if (activevideo) begin
                R_int <= {4{char[y_img][x_img]}}; // replicate current pixel x4 to draw white if 1 or black otherwise
                G_int <= {4{char[y_img][x_img]}};
                B_int <= {4{char[y_img][x_img]}};
        end
    end

endmodule