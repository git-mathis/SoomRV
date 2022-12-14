module FPU
(
    input wire clk,
    input wire rst,
    input wire en,
    
    input BranchProv IN_branch,
    input EX_UOp IN_uop,
    
    output RES_UOp OUT_uop
);

wire[32:0] srcArec;
wire[32:0] srcBrec;
fNToRecFN#(8, 24) recA (.in(IN_uop.srcA), .out(srcArec));
fNToRecFN#(8, 24) recB (.in(IN_uop.srcB), .out(srcBrec));

wire[2:0] rm = 0;

wire lessThan;
wire equal;
wire greaterThan;
wire[4:0] compareFlags;
compareRecFN#(8, 24) compare
(
    .a(srcArec),
    .b(srcBrec),
    .signaling(1'b1),
    .lt(lessThan),
    .eq(equal),
    .gt(greaterThan),
    .unordered(),
    .exceptionFlags(compareFlags)
);

wire[31:0] toInt;
wire[2:0] intFlags;
recFNToIN#(8, 24, 32) toIntRec
(
    .control(0),
    .in(srcArec),
    .roundingMode(rm),
    .signedOut(IN_uop.opcode == FPU_FCVTWS),
    .out(toInt),
    .intExceptionFlags(intFlags)
);

wire[32:0] fromInt;
wire[4:0] fromIntFlags;
iNToRecFN#(32, 8, 24)  intToRec
(
    .control(0),
    .signedIn(IN_uop.opcode == FPU_FCVTSW),
    .in(IN_uop.srcA),
    .roundingMode(rm),
    .out(fromInt),
    .exceptionFlags(fromIntFlags)
);

wire[32:0] addSub;
wire[4:0] addSubFlags;
addRecFN#(8, 24) addRec
(
    .control(0),
    .subOp(IN_uop.opcode == FPU_FSUB_S),
    .a(srcArec),
    .b(srcBrec),
    .roundingMode(rm),
    .out(addSub),
    .exceptionFlags(addSubFlags)
);

reg[32:0] recResult;
always_comb begin
    case(IN_uop.opcode)
        FPU_FCVTSWU,
        FPU_FCVTSW: recResult = fromInt;
        default: recResult = addSub;
    endcase
end
wire[31:0] fpResult;
recFNToFN#(8, 24) recode
(
    .in(recResult),
    .out(fpResult)
);

always@(posedge clk) begin
    
    if (rst) begin
        OUT_uop.valid <= 0;
    end
    else if (en && IN_uop.valid && (!IN_branch.taken || $signed(IN_uop.sqN - IN_branch.sqN) <= 0)) begin
        
        OUT_uop.tagDst <= IN_uop.tagDst;
        OUT_uop.nmDst <= IN_uop.nmDst;
        OUT_uop.sqN <= IN_uop.sqN;
        OUT_uop.flags <= 0;
        OUT_uop.valid <= 1;
        OUT_uop.pc <= IN_uop.pc;
        OUT_uop.compressed <= 0;
            
        case (IN_uop.opcode)
            
            FPU_FADD_S,
            FPU_FSUB_S,
            FPU_FCVTSWU,
            FPU_FCVTSW: OUT_uop.result <= fpResult;
            
            FPU_FEQ_S: OUT_uop.result <= {31'b0, equal};
            FPU_FLE_S: OUT_uop.result <= {31'b0, equal || lessThan};
            FPU_FLT_S: OUT_uop.result <= {31'b0, lessThan};
            
            FPU_FSGNJ_S: OUT_uop.result <= {IN_uop.srcB[31], IN_uop.srcA[30:0]};
            FPU_FSGNJN_S: OUT_uop.result <= {!IN_uop.srcB[31], IN_uop.srcA[30:0]};
            FPU_FSGNJX_S: OUT_uop.result <= {IN_uop.srcA[31] ^ IN_uop.srcB[31], IN_uop.srcA[30:0]};
            
            FPU_FCVTWS,
            FPU_FCVTWUS: OUT_uop.result <= toInt;
            
            
            // TODO: Handle edge cases for min/max in accordance to standard
            FPU_FMIN_S: OUT_uop.result <= lessThan ? IN_uop.srcA : IN_uop.srcB;
            FPU_FMAX_S: OUT_uop.result <= lessThan ? IN_uop.srcB : IN_uop.srcA;
            default: begin end
        endcase
    end
    else begin
        OUT_uop.valid <= 0;
    end

end

endmodule
