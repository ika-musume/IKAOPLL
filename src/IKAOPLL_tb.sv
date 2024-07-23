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
    .ALTPATCH_CONFIG_MODE       (0                          )
) main (
    .i_XIN_EMUCLK               (EMUCLK                     ),
    .o_XOUT                     (                           ),

    .i_phiM_PCEN_n              (phiM_PCEN_n                ),

    .i_IC_n                     (IC_n                       ),

    .i_ALTPATCH_EN              (1'b0                       ),

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

`define AD #150
`define DD #800

initial begin
    #1500;

    #100 IKAOPLL_write(1'b0, 8'h00, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'hFF, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b0, 8'h01, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'hFF, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b0, 8'h02, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'hFF, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b0, 8'h03, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'hFF, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b0, 8'h04, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'hFF, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b0, 8'h05, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'hFF, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b0, 8'h06, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'hFF, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b0, 8'h07, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'hFF, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b0, 8'h0E, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'hFF, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'h00, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b0, 8'h0F, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'hFF, phiMref, CS_n, WR_n, A0, DIN);
    #100 IKAOPLL_write(1'b1, 8'h00, phiMref, CS_n, WR_n, A0, DIN);

    `DD IKAOPLL_write(1'b0, 8'h10, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'hAC, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h11, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'hAC, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h12, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'hAC, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h13, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'hAC, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h14, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'hAC, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h15, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'hAC, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h16, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'hAC, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h17, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'hAC, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h18, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'hAC, phiMref, CS_n, WR_n, A0, DIN);

    `DD IKAOPLL_write(1'b0, 8'h20, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h12, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h21, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h12, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h22, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h12, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h23, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h12, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h24, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h12, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h25, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h12, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h26, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h12, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h27, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h12, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h28, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h12, phiMref, CS_n, WR_n, A0, DIN);

    `DD IKAOPLL_write(1'b0, 8'h30, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h0C, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h31, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h1C, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h32, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h2C, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h33, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h3C, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h34, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h4C, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h35, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h5C, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h36, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h6C, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h37, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h7C, phiMref, CS_n, WR_n, A0, DIN);
    `DD IKAOPLL_write(1'b0, 8'h38, phiMref, CS_n, WR_n, A0, DIN);
    `AD IKAOPLL_write(1'b1, 8'h8C, phiMref, CS_n, WR_n, A0, DIN);
end

endmodule