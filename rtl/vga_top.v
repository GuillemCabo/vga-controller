/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vga_top.v
 * Organization   : Barcelona Supercomputing Center
 * Modified by    : Narcis Rodas
 * Email(s)       : narcis.rodaquiroga@bsc.es
 */

`default_nettype none

// Top module, instantiates and wires other modules, defines background and character color, adjusts current pixel positions
// and processes data from and to the AXI bus
module vga_top #(
    parameter C_AXI_DATA_WIDTH = 32,                // Width of the AXI-lite bus
    parameter C_AXI_ADDR_WIDTH = 13,                // AXI addr width based on the number of registers
    parameter ADDRLSB = $clog2(C_AXI_DATA_WIDTH)-3  // Least significant bits from address not used due to write strobes
)
(
`ifdef FORMAL
    input wire [C_AXI_DATA_WIDTH-1:0] f_rdata_i,    // AXI read data
    input wire f_past_valid_i,                      // 1 after the first clock edge
    input wire f_reset_i,                           // AXI reset
    input wire f_ready_i,                           // AXI read ready
`endif
    input wire                          clk_i,	       // 25MHz clock input
    input wire                          rstn_i,
    output wire [15:0]                  PMOD,          // VGA PMOD
    input wire [C_AXI_DATA_WIDTH-1:0]   axil_wdata_i,  // AXI write data
    input wire [C_AXI_DATA_WIDTH/8-1:0] axil_wstrb_i,  // AXI write strobe
    input wire [C_AXI_ADDR_WIDTH-1:0]   axil_waddr_i,  // AXI write address
    input wire                          axil_wready_i, // AXI address write ready
    input wire                          axil_rreq_i,   // Determines when the VGA reads from the registers
    input wire [C_AXI_ADDR_WIDTH-1:0]   axil_raddr_i,  // AXI read address
    output wire [C_AXI_DATA_WIDTH-1:0]  axil_rdata_o   // Data read from the registers
  );

//--------------------
//Local parameters
//--------------------
    // V for Video output resolution
    localparam V_WIDTH=640;
    localparam V_HEIGHT=480;
    // C for Character resolution
    localparam C_WIDTH=8;
    localparam C_HEIGHT=16;
    // Number of columns and rows
    localparam N_COL=V_WIDTH/C_WIDTH;
    localparam N_ROW=V_HEIGHT/C_HEIGHT;
    
    localparam N_COUNTER_WIDTH = 10;
    localparam N_PIXEL_WIDTH = 10;
    localparam UART_DATA_WIDTH = 8;
    localparam COLOR_WIDTH = 4;
    localparam REG_ADDR_WIDTH = 5;
    localparam N_ROW_WIDTH = 5;
    localparam N_COL_WIDTH = 7;
    localparam N_TOT_WIDTH = N_ROW_WIDTH + N_COL_WIDTH;
    localparam N_CHARS_WIDTH = 7;
    localparam H_PIXELS = 800;
    localparam V_PIXELS = 525;
    localparam H_BLACK = H_PIXELS - V_WIDTH;
    localparam V_BLACK = V_PIXELS - V_HEIGHT;
    localparam C_ADDR_WIDTH = 3;
    localparam C_ADDR_HEIGHT = 4;
    localparam ROM_ADDR_WIDTH = 11;
    localparam BUF_ADDR_WIDTH = 10;

//--------------------
//IO pins assigments
//--------------------
    //Names of the signals on digilent VGA PMOD adapter
    wire R0, R1, R2, R3; // red
    wire G0, G1, G2, G3; // green
    wire B0, B1, B2, B3; // blue
    wire HS,VS;          // horizontal and vertical sync
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
    
    reg clk25 = 1'b0; // 25 Mhz clock
    // Divide the 50 Mhz clock to generate the 25 Mhz one
    always @(posedge clk_i) begin
        clk25 <= ~clk25;
    end

//--------------------
// IP internal signals
//--------------------
    
    wire [N_PIXEL_WIDTH-1:0] x_px;  // current X position of the pixel
    wire [N_PIXEL_WIDTH-1:0] y_px;  // current Y position of the pixel
    wire [N_COUNTER_WIDTH-1:0] hc;  // horizontal counter
    wire [N_COUNTER_WIDTH-1:0] vc;  // vertical counter
    wire activevideo;               // 1 if displaying pixels, 0 otherwise

    vga_syncGen vga_syncGen_inst( .clk_i(clk25), .rstn_i(rstn_i), .hsync_o(HS), .vsync_o(VS), .x_px_o(x_px), .y_px_o(y_px), 
    .hc_o(hc), .vc_o(vc), .activevideo_o(activevideo));

    //Internal registers for current pixel color
    reg [COLOR_WIDTH-1:0] R_int;
    reg [COLOR_WIDTH-1:0] G_int;
    reg [COLOR_WIDTH-1:0] B_int;
    //RGB values assigment from pixel color register or black if we are not in display zone
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

    reg [COLOR_WIDTH-1:0] red_color0;   // background color (black)
    reg [COLOR_WIDTH-1:0] red_color1;   // character color (white)
    reg [COLOR_WIDTH-1:0] blue_color0;  // background color (black)
    reg [COLOR_WIDTH-1:0] blue_color1;  // character color (white)
    reg [COLOR_WIDTH-1:0] green_color0; // background color (black)
    reg [COLOR_WIDTH-1:0] green_color1; // character color (white)
    reg wr_en_regs = 1'b0;
    always @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i)
            wr_en_regs <= 0;
        else
            wr_en_regs <= axil_wready_i & (~axil_waddr_i[C_AXI_ADDR_WIDTH-1]) & axil_waddr_i[C_AXI_ADDR_WIDTH-2] & axil_wstrb_i[0];
    end
    always @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            red_color0 <= 4'b0000;   // background color (black)
            red_color1 <= 4'b1111;   // character color (white)
            blue_color0 <= 4'b0000;  // background color (black)
            blue_color1 <= 4'b1111;  // character color (white)
            green_color0 <= 4'b0000; // background color (black)
            green_color1 <= 4'b1111; // character color (white)
        end
        else begin
            if (wr_en_regs) begin
                case(axil_waddr_i[REG_ADDR_WIDTH-1:ADDRLSB])
                    3'b000: red_color0 <= axil_wdata_i[COLOR_WIDTH-1:0];
                    3'b001: red_color1 <= axil_wdata_i[COLOR_WIDTH-1:0];
                    3'b010: blue_color0 <= axil_wdata_i[COLOR_WIDTH-1:0];
                    3'b011: blue_color1 <= axil_wdata_i[COLOR_WIDTH-1:0];
                    3'b100: green_color0 <= axil_wdata_i[COLOR_WIDTH-1:0];
                    3'b011: green_color1 <= axil_wdata_i[COLOR_WIDTH-1:0];
                endcase
            end
        end
    end

    wire [N_COL_WIDTH-1:0]   current_col; // column of the current tile
    wire [N_ROW_WIDTH-1:0]   current_row; // row of the current tile
    wire [N_PIXEL_WIDTH-1:0] hmem;        // adjusted current x position of the pixel
    wire [N_PIXEL_WIDTH-1:0] vmem;        // adjusted current y position of the pixel

    // register must be loaded 2 cycles before access, so we adjust the addr to be 2 px ahead
    assign hmem = (hc >= H_PIXELS-1) ? hc - H_BLACK : (hc >= H_BLACK-2) ? hc + 2 - H_BLACK : 0;
    // x_px and y_px are 0 when !activevideo, so we need to adjust the vertical pixel too for the first character
    assign vmem = (hc == H_BLACK-2 || hc == H_BLACK-1 || hc == H_BLACK) ? vc - V_BLACK : y_px;

    assign current_col = hmem[N_PIXEL_WIDTH-1:C_ADDR_WIDTH]; 
    assign current_row = vmem[N_PIXEL_WIDTH-1:C_ADDR_HEIGHT]; 
    // x_img and y_img are used to index within the look up
    wire [C_ADDR_WIDTH-1:0]  x_img; // indicate X position inside the tile (0-7)
    wire [C_ADDR_HEIGHT-1:0] y_img; // inidicate Y position inside the tile (0-15)
    // similar as hmem, we need to load the pixel 1 cycle earlier, so we adjust the fetch to be 1 ahead
    assign x_img = x_px[C_ADDR_WIDTH-1:0] + 1;
    // update y_img 1 cycle before to fetch the proper line in font memory
    assign y_img = (hc == H_BLACK-1) ? vmem[C_ADDR_HEIGHT-1:0] : y_px[C_ADDR_HEIGHT-1:0];

    wire [N_CHARS_WIDTH*4-1:0]             char_addr; // address of 4 characters in the bitmap, ASCII code
    wire [0:C_WIDTH-1]                     char;      // bitmap of 1 row of a character
    wire [N_CHARS_WIDTH+C_ADDR_HEIGHT-1:0] font_in;   // address for access to the font memory, concatenation of 1 character address and a row number

    reg wr_ena; // Write enable for the buffer
    // Write to the buffer if we are ready and the address is in the buffer range (4069-6496)
    always @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            wr_ena <= 0;
        end
        else begin
            wr_ena <= (axil_wready_i & axil_waddr_i[C_AXI_ADDR_WIDTH-1]) && axil_waddr_i < 13'd6496;
        end
    end

    wire [N_TOT_WIDTH-1:0] r_tile;            // number of the tile to be accessed
    wire [BUF_ADDR_WIDTH-1:0] vr_addr_buffer; // vga address to read from the buffer
    wire [BUF_ADDR_WIDTH-1:0] w_addr_buffer;  // write address to the buffer
    wire [N_CHARS_WIDTH*4-1:0] w_data_buffer; // write data for the buffer
    wire [BUF_ADDR_WIDTH-1:0] r_addr_buffer;  // AXI read address for the buffer
    wire [N_CHARS_WIDTH*4-1:0] r_data_buffer; // AXI read data from the buffer
    assign r_tile = current_row * N_COL + current_col;
    assign vr_addr_buffer = r_tile[N_TOT_WIDTH-1:ADDRLSB];
    assign w_addr_buffer = axil_waddr_i[C_AXI_ADDR_WIDTH-2:ADDRLSB];
    // select the least significant 7 bits from each group of 8 bits (discard the MSB from each byte)
    assign w_data_buffer = {axil_wdata_i[C_AXI_DATA_WIDTH-2-:N_CHARS_WIDTH], axil_wdata_i[C_AXI_DATA_WIDTH-2-(N_CHARS_WIDTH+1)-:N_CHARS_WIDTH],
           axil_wdata_i[C_AXI_DATA_WIDTH-2-(N_CHARS_WIDTH+1)*2-:N_CHARS_WIDTH], axil_wdata_i[C_AXI_DATA_WIDTH-2-(N_CHARS_WIDTH+1)*3-:N_CHARS_WIDTH]};
    assign r_addr_buffer = axil_raddr_i[C_AXI_ADDR_WIDTH-2:ADDRLSB];
    // pad the data read with a 0 before each group of 7 bits
    assign axil_rdata_o = {1'b0, r_data_buffer[N_CHARS_WIDTH*4-1-:N_CHARS_WIDTH], 1'b0, r_data_buffer[N_CHARS_WIDTH*3-1-:N_CHARS_WIDTH],
           1'b0, r_data_buffer[N_CHARS_WIDTH*2-1-:N_CHARS_WIDTH], 1'b0, r_data_buffer[N_CHARS_WIDTH-1:0]};


`ifdef FORMAL
    vga_buffer #(.C_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH), .C_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH))
    vga_buffer_inst( .clk_i(clk25), .wr_en_i(wr_ena), .w_addr_i(w_addr_buffer), .w_strb_i(axil_wstrb_i), .r_addr_i(r_addr_buffer), .r_req_i(axil_rreq_i), 
    .vr_addr_i(vr_addr_buffer), .din_i(axil_wdata_i), .dout_o(char_addr), .r_data_o(r_data_buffer), .f_rdata_i(f_rdata_i), 
    .f_past_valid_i(f_past_valid_i), .f_reset_i(f_reset_i), .f_ready_i(f_ready_i), .clk_axi_i(clk_i));
`else
    vga_buffer #(.C_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH), .C_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH))
    vga_buffer_inst( .clk_i(clk25), .wr_en_i(wr_ena), .w_addr_i(w_addr_buffer), .w_strb_i(axil_wstrb_i), .r_addr_i(r_addr_buffer), .r_req_i(axil_rreq_i), 
    .vr_addr_i(vr_addr_buffer), .din_i(w_data_buffer), .dout_o(char_addr), .r_data_o(r_data_buffer));
`endif
    
    wire [ROM_ADDR_WIDTH-1:0] w_addr_rom; // write address to the bitmap memory
    reg wr_en_rom;                 // write enable for the bitmap memory
    wire [0:C_WIDTH-1] w_data_rom;        // write data to the bitmap memory
    wire [ADDRLSB-1:0] char_sel;          // the specific character of the group of 4 to be read for the display
    always @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            wr_en_rom <= 0;
        end
        else begin
            wr_en_rom <= axil_wready_i & (~axil_waddr_i[C_AXI_ADDR_WIDTH-1]) & (~axil_waddr_i[C_AXI_ADDR_WIDTH-2]) & axil_wstrb_i[0];
        end
    end

    assign char_sel = r_tile[ADDRLSB-1:0];
    assign w_addr_rom = axil_waddr_i[ROM_ADDR_WIDTH-1:0]; 
    assign w_data_rom = axil_wdata_i[C_WIDTH-1:0]; // write only the least significant byte of the data
    assign font_in = {1'b0, char_addr[char_sel*7+:7], y_img};

    vga_fontMem vga_fontMem_inst( .clk_i(clk25), .addr_i(font_in), .dout_o(char), .addr_w_i(w_addr_rom), .wr_en_i(wr_en_rom), .din_i(w_data_rom));

    //Update next pixel color
    always @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
                R_int <= 4'b0;
                G_int <= 4'b0;
                B_int <= 4'b0;
        end 
        else begin
        //remember that there is a section outside the screen
        //if We don't use the active video pixel value will increase in the 
        //section outside the display as well.
            if (activevideo) begin
                    R_int <= char[x_img] ? red_color1 : red_color0; // paint white if pixel from the bitmap is active, black otherwise
                    G_int <= char[x_img] ? green_color1 : green_color0; 
                    B_int <= char[x_img] ? blue_color1 : blue_color0; 
            end
        end
    end

endmodule

`default_nettype wire
