module IKAOPLL #(
    parameter FULLY_SYNCHRONOUS = 1,        //use DFF only
    parameter FAST_RESET = 0,               //speed up reset
    parameter ALTPATCH_CONFIG_MODE = 0,   //0 to use external wire, 1 to use bit[4] of TEST register
    parameter USE_PIPELINED_MULTIPLIER = 0  //1 to add pipelined multiplier to increase fmax
    ) (
    //chip clock
    input   wire            i_XIN_EMUCLK, //emulator master clock, same as XIN
    output  wire            o_XOUT,

    //clock enables
    input   wire            i_phiM_PCEN_n, //phiM positive edge clock enable(negative logic)

    //chip reset
    input   wire            i_IC_n,    

    //bus control and address
    input   wire            i_CS_n,
    input   wire            i_WR_n,
    input   wire            i_A0,

    //bus data
    input   wire    [7:0]   i_D,
    output  wire    [1:0]   o_D, //YM2413 uses only two LSBs

    //output driver enable
    output  wire            o_D_OE,

    //output
    output  wire            o_MO_SAMPLE, o_RO_SAMPLE,
    output  wire signed     [9:0]  o_MO, o_RO
);


///////////////////////////////////////////////////////////
//////  Clocking information
////

/*
    phiM(XIN)   ¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|
    prescaler   -3-|-0-|-1-|-2-|-3-|-0-|-1-|-2-|-3-|-0-|-1-|
    phi1p       ¯|_________|¯¯¯¯¯|_________|¯¯¯¯¯|_________|
    phi1n       ___|¯¯¯¯¯|_________|¯¯¯¯¯|_________|¯¯¯¯¯|__

    phi1pcen    _______|¯¯¯|___________|¯¯¯|___________|¯¯¯|
    phi1ncen    ¯¯¯|___________|¯¯¯|___________|¯¯¯|________
    dacen       ___|¯¯¯|___________|¯¯¯|___________|¯¯¯|____
*/

//(* altera_attribute = "-name GLOBAL_SIGNAL GLOBAL_CLOCK" *) 


///////////////////////////////////////////////////////////
//////  Clock and reset
////

//master clock
wire            emuclk = i_XIN_EMUCLK;
assign  o_XOUT = ~emuclk;

//divided clock
wire            phi1pcen_n, phi1ncen_n, dac_en;

//reset(synchronized, not the nIC)
wire            mrst_n;



///////////////////////////////////////////////////////////
//////  Interconnects
////

wire            rhythm_en;
assign rhythm_en = 1'b0;



///////////////////////////////////////////////////////////
//////  TIMING GENERATOR
////

IKAOPLL_timinggen #(.FULLY_SYNCHRONOUS(FULLY_SYNCHRONOUS), .FAST_RESET(FAST_RESET)) u_TIMINGGEN (
    .i_EMUCLK                   (emuclk                     ),
    .i_phiM_PCEN_n              (i_phiM_PCEN_n              ),

    .i_IC_n                     (i_IC_n                     ),

    .o_phi1_PCEN_n              (phi1pcen_n                 ),
    .o_phi1_NCEN_n              (phi1ncen_n                 ),
    .o_DAC_EN                   (dac_en                     ),

    .i_RHYTHM_EN                (rhythm_en                  ),

    .o_CYCLE_00                 (                           ), 
    .o_CYCLE_12                 (                           ), 
    .o_CYCLE_17                 (                           ), 
    .o_CYCLE_20                 (                           ), 
    .o_CYCLE_21                 (                           ),

    .o_CYCLE_D4                 (                           ),
    .o_CYCLE_D3_ZZ              (                           ),
    .o_CYCLE_D4_ZZ              (                           ),

    .o_MnC_SEL                  (                           ),
    .o_INHIBIT_FDBK             (                           ),
    .o_HH_TT_SEL                (                           ),
    
    .o_MO_CTRL                  (                           ),
    .o_RO_CTRL                  (                           )
);


/*
IKAOPLL_reg #(.FULLY_SYNCHRONOUS(FULLY_SYNCHRONOUS), .ALTPATCH_CONFIG_MODE(ALTPATCH_CONFIG_MODE), .INSTROM_STYLE(0)) u_REG (
    .i_EMUCLK                   (emuclk                     ),
    .i_phiM_PCEN_n              (i_phiM_PCEN_n              ),

    .i_IC_n                     (i_IC_n                     ),

    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CS_n                     (i_CS_n                     ),
    .i_WR_n                     (i_WR_n                     ),
    .i_A0                       (i_A0                       ),
    
    .i_D                        (i_D                        ),
    .o_D                        (o_D                        ),
    .o_D_OE                     (o_D_OE                     ),

    .o_EG_FORCE_EGPARAM_ZERO    (                           )
);
*/


endmodule 