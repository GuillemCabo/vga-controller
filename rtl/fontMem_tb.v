`timescale 1ns/1ns

module fontMem_tb;

    reg clk;
    reg [6:0] addr;
    wire [0:127] dout;
    reg [0:127] expected [0:127];
    reg error;

    initial begin
        $dumpfile("fontMem_tb.vcd");
        $dumpvars(0, fontMem_tb);
        wait(addr == 7'd127); // last character address
        if (error == 1'b0) $display("PASS");
        $finish;
    end

    initial begin
        clk = 1'b0;
        addr = 7'd0;
        error = 1'b0;
        $readmemb("charmem2.list", expected);
    end
        
    fontMem dut_fontMem( .clk_i(clk), .addr_i(addr), .dout_o(dout));

    // this test reads all memory positions starting from 0
    always @(posedge clk) begin
        #1 if (dout != expected[addr]) begin
            $display("Error at address %d", addr);
            error <= 1'b1;
        end
        addr <= addr + 1;
    end 

    /* Make a regular pulsing clock. */
    always #20 clk = !clk;

endmodule // test
