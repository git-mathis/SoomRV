
module ControlRegs
#
(
    parameter NUM_UOPS=2,
    parameter NUM_WBS=3
)
(
    input wire clk,
    input wire rst,
    
    input wire IN_ce,
    input wire IN_we,
    input wire[3:0] IN_wm,
    input wire[5:0] IN_addr,
    input wire[31:0] IN_data,
    
    output reg[31:0] OUT_data,
    
    
    // Various Signals to update perf counters
    input wire IN_comValid[NUM_UOPS-1:0],
    input BranchProv IN_branch,
    input wire IN_wbValid[NUM_WBS-1:0],
    input wire IN_ifValid[NUM_UOPS-1:0],
    input wire IN_comBranch,
    
    // Control Registers I/0
    output wire[31:0] OUT_irqAddr,
    input wire IN_irqTaken,
    input wire[31:0] IN_irqSrc,
    input Flags IN_irqFlags,
    
    output reg[15:0] OUT_GPIO_oe,
    output reg[15:0] OUT_GPIO,
    input wire[15:0] IN_GPIO
);

integer i;

// Registered Inputs
reg ceReg;
reg weReg;
reg[3:0] wmReg;
reg[5:0] addrReg;
reg[31:0] dataReg;


// 64-bit Regs
// 0 CR_cycles
// 1 CR_decInstrs
// 2 CR_exeInstrs
// 3 CR_comInstrs
// 4 CR_invalids
// 5 CR_branches
reg[63:0] cRegs64[6:0];


// 32-bit Control Regs
// 0 IRQ handler,
// 1 IRQ src
// 2 IRQ flags
// 3
// 4
// 5 GPIO oe | out
// 6 GPIO aen | ade | acnt | ...
// 7 GPIO in

reg[7:0] gpioCnt;
reg[31:0] cRegs[7:0];
always_comb begin
    OUT_GPIO_oe = cRegs[5][15:0];
    OUT_GPIO = cRegs[5][31:16];
end
assign OUT_irqAddr = cRegs[0];

always_ff@(posedge clk) begin
    
    if (rst) begin
        gpioCnt <= 0;
        ceReg <= 1;
        for (i = 0; i < 6; i=i+1)
            cRegs64[i] <= 0;
    end
    else begin
        
        gpioCnt <= gpioCnt - 1;
        
        if (!ceReg) begin
            if (!weReg) begin
                // 64-bit
                if (addrReg[4]) begin
                    
                    // No need to have perf counters writeable for now
                    
                    // Upper
                    /*if (addrReg[0]) begin
                        if (wmReg[0]) cRegs64[addrReg[3:1]][39:32] <= dataReg[7:0];
                        if (wmReg[1]) cRegs64[addrReg[3:1]][47:40] <= dataReg[15:8];
                        if (wmReg[2]) cRegs64[addrReg[3:1]][55:48] <= dataReg[23:16];
                        if (wmReg[3]) cRegs64[addrReg[3:1]][63:56] <= dataReg[31:24];
                    end
                    // Lower
                    else begin
                        if (wmReg[0]) cRegs64[addrReg[3:1]][7:0] <= dataReg[7:0];
                        if (wmReg[1]) cRegs64[addrReg[3:1]][15:8] <= dataReg[15:8];
                        if (wmReg[2]) cRegs64[addrReg[3:1]][23:16] <= dataReg[23:16];
                        if (wmReg[3]) cRegs64[addrReg[3:1]][31:24] <= dataReg[31:24];
                    end*/
                end
                else begin
                    if (wmReg[0]) cRegs[addrReg[2:0]][7:0] <= dataReg[7:0];
                    if (wmReg[1]) cRegs[addrReg[2:0]][15:8] <= dataReg[15:8];
                    if (wmReg[2]) cRegs[addrReg[2:0]][23:16] <= dataReg[23:16];
                    if (wmReg[3]) cRegs[addrReg[2:0]][31:24] <= dataReg[31:24];
                    
                    if (addrReg[2:0] == 5)
                        gpioCnt <= cRegs[6][7:0];
                end
            end
            else begin
                if (addrReg[4]) begin
                    if (addrReg[0])
                        OUT_data <= cRegs64[addrReg[3:1]][63:32];
                    else
                        OUT_data <= cRegs64[addrReg[3:1]][31:0];
                end
                else begin
                    if (addrReg[2:0] == 7)
                        OUT_data <= {16'bx, IN_GPIO};
                    else
                        OUT_data <= cRegs[addrReg[2:0]];
                end
            end
        end
        
        ceReg <= IN_ce;
        weReg <= IN_we;
        wmReg <= IN_wm;
        addrReg <= IN_addr;
        dataReg <= IN_data;
        
        if (gpioCnt == 0) begin
            cRegs[5][31:24] <= (cRegs[5][31:24] | cRegs[6][15:8]) & (~cRegs[6][23:16]);
        end
        
        
        if (IN_irqTaken) begin
            cRegs[1] <= IN_irqSrc;
            cRegs[2] <= {30'b0, IN_irqFlags[1:0]};
        end
        
        
        // Update Perf Counters
        cRegs64[0] <= cRegs64[0] + 1;
        
        for (i = 0; i < NUM_UOPS; i=i+1) begin
        
            if (IN_ifValid[i])
                cRegs64[1] = cRegs64[1] + 1;
            if (IN_comValid[i])
                cRegs64[3] = cRegs64[3] + 1;
        end
        for (i = 0; i < NUM_WBS; i=i+1) begin
            if (IN_wbValid[i])
                cRegs64[2] = cRegs64[2] + 1;
        end
        if (IN_branch.taken)
            cRegs64[4] <= cRegs64[4] + 1;
        
        if (IN_comBranch)
            cRegs64[5] <= cRegs64[5] + 1;
        
    end

end

endmodule