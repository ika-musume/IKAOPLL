module IKAOPLL_lfo (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //core internal reset
    input   wire            i_MRST_n,

    output  wire    [7:0]   o_LFP,
    output  wire    [7:0]   o_LFA,

    output  wire            o_REG_LFO_CLK
);


endmodule