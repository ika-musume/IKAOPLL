module IKAOPLL_dac (
    //master clock
    input   wire            i_EMUCLK, //emulator master clock
    input   wire            i_phiM_PCEN_n,

    //master reset
    input   wire            i_IC_n,

    //internal clock
    input   wire            i_phi1_PCEN_n, //positive edge clock enable for emulation
    input   wire            i_phi1_NCEN_n, //negative edge clock enable for emulation

    //timings
    input   wire            i_DAC_EN, i_CYCLE_00, i_MO_CTRL, i_RO_CTRL, i_INHIBIT_FDBK,

    //rhythm enable
    input   wire            i_RHYTHM_EN,

    //io
    output  wire    [8:0]   o_REG_TEST_SNDDATA,
    output  wire    [8:0]   i_DAC_OPDATA,

    //sign+magnitude output with no zero-level fluctuation
    output  wire                o_IMP_NOFLUC_SIGN,
    output  wire signed [8:0]   o_IMP_NOFLUC_MAG_MO, 
    output  wire signed [8:0]   o_IMP_NOFLUC_MAG_RO,

    //signed output with zero-level fluctuation
    output  wire signed [9:0]   o_IMP_FLUC_SIGNED_MO,    
    output  wire signed [9:0]   o_IMP_FLUC_SIGNED_RO,

    //"accumulated" output
    output  reg  signed [15:0]  o_ACC_SIGNED
);


/*
    OP output
    5:  CH1 CAR
    8:  CH2 CAR
    9:  CH3 CAR
    13: CH4 CAR
    16: CH5 CAR
    17: CH6 CAR

    /FM 3ch
    21: CH7 CAR
    0:  CH8 CAR
    1:  CH9 CAR

    //precussion 5ch
    19: CH8 MOD
    20: CH9 MOD
    21: CH7 CAR
    22: CH8 CAR
    0:  CH9 CAR
*/


///////////////////////////////////////////////////////////
//////  Clock and reset
////

wire            emuclk = i_EMUCLK;
wire            phiMpcen_n = i_phiM_PCEN_n;
wire            phi1pcen_n = i_phi1_PCEN_n;
wire            phi1ncen_n = i_phi1_NCEN_n;



///////////////////////////////////////////////////////////
//////  Percussion sample storage
////

wire            perc_sr_shift_n = ~(~i_RHYTHM_EN | i_RO_CTRL);
wire    [8:0]   perc_sr_q;
wire    [8:0]   perc_sr_d = i_INHIBIT_FDBK ? (i_RHYTHM_EN ? perc_sr_q : 9'd0) : i_DAC_OPDATA;

IKAOPLL_sr #(.WIDTH(9), .LENGTH(5)) u_percussion_sr
(.i_EMUCLK(emuclk), .i_CEN_n(phi1ncen_n | perc_sr_shift_n), .i_D(perc_sr_d), .o_Q_LAST(perc_sr_q));



///////////////////////////////////////////////////////////
//////  Impulse DAC(1-bit sign + 8-bit magnitude)
////

//latch sign+magnitude
reg     [8:0]   snddata_signmag;
assign  o_REG_TEST_SNDDATA = snddata_signmag;
always @(posedge emuclk) if(!phi1ncen_n) begin
    snddata_signmag[8] <= perc_sr_d[8];
    snddata_signmag[7:0] <= perc_sr_d[8] ? ~perc_sr_d[7:0] : perc_sr_d[7:0];
end

//impulse control
reg             mo_ctrl_z, ro_ctrl_z;
wire            fm_dac_en = mo_ctrl_z & i_DAC_EN;
wire            perc_dac_en = ro_ctrl_z & i_DAC_EN;
always @(posedge emuclk) if(!phi1ncen_n) begin
    mo_ctrl_z <= i_MO_CTRL;
    ro_ctrl_z <= i_RO_CTRL;
end

//dac - no fluctuation
assign  o_IMP_NOFLUC_SIGN = snddata_signmag[8];
assign  o_IMP_NOFLUC_MAG_MO = fm_dac_en   ? snddata_signmag[7:0] + 9'd1 : 9'd0;
assign  o_IMP_NOFLUC_MAG_RO = perc_dac_en ? snddata_signmag[7:0] + 9'd1 : 9'd0;

//dac
wire signed [9:0]   dac_out = snddata_signmag[8] ? {1'b1, ~snddata_signmag[7:0]} : ({1'b0, snddata_signmag[7:0]} + 9'sd1);
wire signed [9:0]   dac_zlv = snddata_signmag[8] ? 10'h3FF : 10'h1; //zero level
assign  o_IMP_FLUC_SIGNED_MO = fm_dac_en   ? dac_out : dac_zlv;
assign  o_IMP_FLUC_SIGNED_RO = perc_dac_en ? dac_out : dac_zlv;



///////////////////////////////////////////////////////////
//////  Accumulation DAC(12-bit signed)
////

reg         [2:0]   cyc0_dly;
reg                 dac_acc_en;
reg signed  [15:0]  dac_acc;
always @(posedge emuclk) if(!phi1ncen_n) begin
    cyc0_dly[0] <= i_CYCLE_00;
    cyc0_dly[2:1] <= cyc0_dly[1:0];

    dac_acc_en <= ~i_INHIBIT_FDBK;
    
    if(cyc0_dly[2]) begin
        dac_acc <= 16'sd0;
        o_ACC_SIGNED <= dac_acc;
    end
    else begin
        if(ro_ctrl_z) dac_acc <= dac_acc + $signed(perc_sr_d) * 16'sd2;
        else          dac_acc <= dac_acc + $signed(perc_sr_d);
    end
end


endmodule