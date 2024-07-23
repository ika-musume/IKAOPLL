module IKAOPLL #(
    parameter FULLY_SYNCHRONOUS = 1,        //use DFF only
    parameter FAST_RESET = 0,               //speed up reset
    parameter ALTPATCH_CONFIG_MODE = 0,     //0 to use external wire, 1 to use bit[4] of TEST register
    parameter USE_PIPELINED_MULTIPLIER = 0  //1 to add pipelined multiplier to increase fmax
    ) (
    //chip clock
    input   wire            i_XIN_EMUCLK, //emulator master clock, same as XIN
    output  wire            o_XOUT,

    //clock enables
    input   wire            i_phiM_PCEN_n, //phiM positive edge clock enable(negative logic)

    //chip reset
    input   wire            i_IC_n,

    //VRC7 patch enable
    input   wire            i_ALTPATCH_EN,

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
wire            rst_n;



///////////////////////////////////////////////////////////
//////  Interconnects
////

//timings
wire            cycle_00, cycle_12, cycle_17, cycle_20, cycle_21;
wire            cycle_d4, cycle_d3_zz, cycle_d4_zz;
wire            m_nc_sel, inhibit_fdbk, hh_tt_sel;
wire            mo_ctrl, ro_ctrl;

//reg data
wire    [3:0]   test;
wire            rhythm_en;
wire    [8:0]   fnum;
wire    [2:0]   block;
wire            kon, susen;
wire    [5:0]   tl;
wire            dc, dm;
wire    [2:0]   fb;
wire            am, pm, etyp, ksr;
wire    [3:0]   mul;
wire    [1:0]   ksl;
wire    [3:0]   ar, dr, rr, sl;
wire            envcntr_test_data;

//lfo
wire    [2:0]   pmval; //signed
wire    [3:0]   amval;


///////////////////////////////////////////////////////////
//////  TIMING GENERATOR
////

IKAOPLL_timinggen #(.FULLY_SYNCHRONOUS(FULLY_SYNCHRONOUS), .FAST_RESET(FAST_RESET)) u_TIMINGGEN (
    .i_EMUCLK                   (emuclk                     ),
    .i_phiM_PCEN_n              (i_phiM_PCEN_n              ),

    .i_IC_n                     (i_IC_n                     ),
    .o_RST_n                    (rst_n                      ),

    .o_phi1_PCEN_n              (phi1pcen_n                 ),
    .o_phi1_NCEN_n              (phi1ncen_n                 ),
    .o_DAC_EN                   (dac_en                     ),

    .i_RHYTHM_EN                (rhythm_en                  ),

    .o_CYCLE_00                 (cycle_00                   ), 
    .o_CYCLE_12                 (cycle_12                   ), 
    .o_CYCLE_17                 (cycle_17                   ), 
    .o_CYCLE_20                 (cycle_20                   ), 
    .o_CYCLE_21                 (cycle_21                   ),

    .o_CYCLE_D4                 (cycle_d4                   ),
    .o_CYCLE_D3_ZZ              (cycle_d3_zz                ),
    .o_CYCLE_D4_ZZ              (cycle_d4_zz                ),

    .o_MnC_SEL                  (m_nc_sel                   ),
    .o_INHIBIT_FDBK             (inhibit_fdbk               ),
    .o_HH_TT_SEL                (hh_tt_sel                  ),
    
    .o_MO_CTRL                  (mo_ctrl                    ),
    .o_RO_CTRL                  (ro_ctrl                    )
);



///////////////////////////////////////////////////////////
//////  REGISTER
////

IKAOPLL_reg #(.FULLY_SYNCHRONOUS(FULLY_SYNCHRONOUS), .ALTPATCH_CONFIG_MODE(ALTPATCH_CONFIG_MODE), .INSTROM_STYLE(0)) u_REG (
    .i_EMUCLK                   (emuclk                     ),
    .i_phiM_PCEN_n              (i_phiM_PCEN_n              ),

    .i_RST_n                    (rst_n                      ),

    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CS_n                     (i_CS_n                     ),
    .i_WR_n                     (i_WR_n                     ),
    .i_A0                       (i_A0                       ),
    
    .i_D                        (i_D                        ),
    .o_D                        (o_D                        ),
    .o_D_OE                     (o_D_OE                     ),

    .i_ALTPATCH_EN              (i_ALTPATCH_EN              ),

    .i_CYCLE_12                 (cycle_12                   ),
    .i_CYCLE_21                 (cycle_21                   ),
    .i_CYCLE_D3_ZZ              (cycle_d3_zz                ),
    .i_CYCLE_D4_ZZ              (cycle_d4_zz                ),
    .i_MnC_SEL                  (m_nc_sel                   ),

    .o_TEST                     (test                       ),

    .o_RHYTHM_EN                (rhythm_en                  ),
    .o_FNUM                     (fnum                       ),
    .o_BLOCK                    (block                      ),
    
    .o_KON                      (kon                        ),
    .o_SUSEN                    (susen                      ),
    .o_TL                       (tl                         ),

    .o_DC                       (dc                         ), 
    .o_DM                       (dm                         ),

    .o_FB                       (fb                         ),
    .o_AM                       (am                         ),
    .o_PM                       (pm                         ),
    .o_ETYP                     (etyp                       ),
    .o_KSR                      (ksr                        ),
    .o_MUL                      (mul                        ),
    .o_KSL                      (ksl                        ),
    .o_AR                       (ar                         ),
    .o_DR                       (dr                         ),
    .o_RR                       (rr                         ),
    .o_SL                       (sl                         ),

    .o_EG_ENVCNTR_TEST_DATA     (envcntr_test_data          )
);



///////////////////////////////////////////////////////////
//////  LFO
////

IKAOPLL_lfo u_LFO (
    .i_EMUCLK                   (emuclk                     ),

    .i_RST_n                    (rst_n                      ),

    .i_phi1_PCEN_n              (phi1pcen_n                 ),
    .i_phi1_NCEN_n              (phi1ncen_n                 ),

    .i_CYCLE_00                 (cycle_00                   ),
    .i_CYCLE_21                 (cycle_21                   ),
    .i_CYCLE_D4                 (cycle_d4                   ),
    .i_CYCLE_D3_ZZ              (cycle_d3_zz                ),

    .i_TEST                     (test                       ),

    .o_PMVAL                    (pmval                      ),
    .o_AMVAL                    (amval                      )
);


endmodule 