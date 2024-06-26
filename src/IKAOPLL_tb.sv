`timescale 10ps/10ps
module IKAOPLL_tb;

//BUS IO wires
reg             EMUCLK = 1'b1;
reg             IC_n = 1'b1;
reg             CS_n = 1'b1;
reg             WR_n = 1'b1;
reg             A0 = 1'b0;
reg     [7:0]   DIN = 8'hZZ;

//generate clock
always #1 EMUCLK = ~EMUCLK;

reg     [1:0]   clkdiv = 2'd0;
reg             phiMref = 1'b0;
wire            phiM_PCEN_n = ~(clkdiv[1:0] == 2'b11);
always @(posedge EMUCLK) begin
    if(clkdiv == 2'd3) begin clkdiv <= 2'd0; phiMref <= 1'b1; end
    else clkdiv <= clkdiv + 2'd1;

    if(clkdiv[1:0] == 2'd1) phiMref <= 1'b0;
end


//async reset
initial begin
    #30 IC_n <= 1'b0;
    #1300 IC_n <= 1'b1;
end


//main chip
IKAOPLL #(
    .FULLY_SYNCHRONOUS          (1                          ),
    .FAST_RESET                 (1                          ),
    .USE_VRC7_PATCH             (0                          )
) main (
    .i_XIN_EMUCLK               (EMUCLK                     ),
    .o_XOUT                     (                           ),

    .i_phiM_PCEN_n              (phiM_PCEN_n                ),

    .i_IC_n                     (IC_n                       ),

    .i_CS_n                     (CS_n                       ),
    .i_WR_n                     (WR_n                       ),
    .i_A0                       (A0                         ),

    .i_D                        (DIN                        ),
    .o_D                        (                           ),
    .o_D_OE                     (                           ),

    .o_MO_SAMPLE                (                           ),
    .o_RO_SAMPLE                (                           ),
    .o_MO                       (                           ),
    .o_RO                       (                           )
);



task automatic IKAOPLL_write (
    input               i_TARGET_ADDR,
    input       [7:0]   i_WRITE_DATA,
    ref logic           i_CLK,
    ref logic           o_CS_n,
    ref logic           o_WR_n,
    ref logic           o_A0,
    ref logic   [7:0]   o_DATA
); begin
    @(posedge i_CLK) o_A0 = i_TARGET_ADDR;
    @(negedge i_CLK) o_CS_n = 1'b0;
    @(posedge i_CLK) o_DATA = i_WRITE_DATA;
    @(negedge i_CLK) o_WR_n = 1'b0;
    @(posedge i_CLK) ;
    @(negedge i_CLK) o_WR_n = 1'b1;
                     o_CS_n = 1'b1;
    @(posedge i_CLK) o_DATA = 8'hZZ;
end endtask

initial begin
    #1500;

    #100 IKAOPLL_write(1'b0, 8'h00, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'h7A, phiMref, CS_n, WR_n, A0, DIN);
end

endmodule