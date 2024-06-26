module IKAOPLL_pg #(parameter USE_BOOTH_MULTIPLIER = 0) (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock

    //core internal reset
    input   wire            i_MRST_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation



    //send signals to other modules
    input   wire            i_PG_PHASE_RST, //phase reset request signal from PG
    output  wire    [4:0]   o_EG_PDELTA_SHIFT_AMOUNT, //send shift amount to EG
    output  wire    [9:0]   o_OP_PHASEDATA, //send phase data to OP
    output  wire            o_REG_PHASE_CH6_C2 //send Ch6, Carrier2 phase data to REG serially
);


endmodule