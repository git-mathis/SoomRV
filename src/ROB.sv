  
typedef struct packed 
{
    Flags flags;
    Tag tag;
    bit sqN_msb;
    //bit[30:0] pc;
    RegNm name;
    //bit isBranch;
    //bit branchTaken;
    //bit predicted;
    //BranchPredInfo bpi;
    FetchOff_t fetchOffs;
    FetchID_t fetchID;
    //BHist_t history;
    bit compressed;
    bit valid;
    bit executed;
} ROBEntry;


module ROB
#(
    // how many entries, ie how many instructions can we
    // speculatively execute?
    parameter LENGTH = 64,

    parameter WIDTH = 4,
    parameter WIDTH_WB = 4
    )
(
    input wire clk,
    input wire rst,

    input R_UOp IN_uop[WIDTH-1:0],
    input wire IN_uopValid[WIDTH-1:0],
    
    input RES_UOp IN_wbUOps[WIDTH_WB-1:0],
    
    input BranchProv IN_branch,
    

    output SqN OUT_maxSqN,
    output SqN OUT_curSqN,

    output CommitUOp OUT_comUOp[WIDTH-1:0],
    
    output BPUpdate OUT_bpUpdate,
    
    input wire[31:0] IN_irqAddr,
    output Flags OUT_irqFlags,
    output reg[31:0] OUT_irqSrc,
    output reg[31:0] OUT_irqMemAddr,
    
    output FetchID_t OUT_pcReadAddr,
    input PCFileEntry IN_pcReadData,
    
    
    output BranchProv OUT_branch,
    output FetchID_t OUT_curFetchID,
    
    input wire IN_irq,
    input wire IN_MEM_busy,
    
    output reg OUT_fence,
    output reg OUT_clearICache,
    output wire OUT_disableIFetch,
    output reg OUT_irqTaken,
    output reg OUT_halt,
    output reg OUT_mispredFlush
);

integer i;
integer j;

localparam ID_LEN = $clog2(LENGTH);

R_UOp rnUOpSorted[WIDTH-1:0];
reg rnUOpValidSorted[WIDTH-1:0];
always_comb begin
    for (i = 0; i < WIDTH; i=i+1) begin
        rnUOpValidSorted[i] = 0;
        rnUOpSorted[i] = 101'bx;
        
        for (j = 0; j < WIDTH; j=j+1) begin
            // This could be one-hot...
            if (IN_uopValid[j] && IN_uop[j].sqN[1:0] == i[1:0]) begin
                rnUOpValidSorted[i] = 1;
                rnUOpSorted[i] = IN_uop[j];
            end
        end
    end
end

ROBEntry entries[LENGTH-1:0];
SqN baseIndex;

assign OUT_maxSqN = baseIndex + LENGTH - 1;
assign OUT_curSqN = baseIndex;

SqN pcLookupEntrySqN;
ROBEntry pcLookupEntry;
assign OUT_pcReadAddr = pcLookupEntry.fetchID;
wire[30:0] baseIndexPC = {IN_pcReadData.pc[30:3], pcLookupEntry.fetchOffs} - (pcLookupEntry.compressed ? 0 : 1);
BHist_t baseIndexHist;
BranchPredInfo baseIndexBPI;
always_comb begin
    if (IN_pcReadData.bpi.predicted && !IN_pcReadData.bpi.isJump && pcLookupEntry.fetchOffs > IN_pcReadData.branchPos)
        baseIndexHist = {IN_pcReadData.hist[$bits(BHist_t)-2:0], IN_pcReadData.bpi.taken};
    else
        baseIndexHist = IN_pcReadData.hist;
        
        baseIndexBPI = (pcLookupEntry.fetchOffs == IN_pcReadData.branchPos) ?
            IN_pcReadData.bpi :
            0;
end

reg stop;
reg memoryWait;
reg instrFence;
reg externalIRQ;

assign OUT_disableIFetch = memoryWait;

reg misprReplay;
reg misprReplayEnd;
SqN misprReplayIter;
SqN misprReplayEndSqN;


/* verilator lint_off UNOPTFLAT */
// All commits/reads from the ROB are sequenatial.
// This should convince synthesis of that too.
reg[3:0] deqAddresses[WIDTH-1:0];
ROBEntry deqPorts[WIDTH-1:0];
always_comb begin
    for (i = 0; i < WIDTH; i=i+1) begin
        deqPorts[i] = entries[{deqAddresses[i], i[1:0]}];
    end
end
ROBEntry deqEntries[WIDTH-1:0];
always_comb begin
    reg[5:0] addr = (misprReplay && !IN_branch.taken) ? misprReplayIter[5:0] : baseIndex[5:0];
    
    // So synthesis doesn't generate latches... (actually, 16 latches seems worth it vs. 1k std cells)
    //for (i = 0; i < WIDTH; i=i+1)
    //    deqAddresses[i] = 4'bx;
    
    for (i = 0; i < WIDTH; i=i+1) begin
    
        deqAddresses[addr[1:0]] = addr[5:2];
        deqEntries[i] = deqPorts[addr[1:0]];
        addr = addr + 6'b1;
    end
end

// 19112
always_ff@(posedge clk) begin

    OUT_branch.taken <= 0;
    OUT_halt <= 0;
    OUT_fence <= 0;
    OUT_clearICache <= 0;
    OUT_irqTaken <= 0;
    externalIRQ <= externalIRQ | IN_irq;
    
    if (rst) begin
        baseIndex <= 0;
        for (i = 0; i < LENGTH; i=i+1) begin
            entries[i].valid <= 0;
            entries[i].executed <= 0;
        end
        for (i = 0; i < WIDTH; i=i+1) begin
            OUT_comUOp[i].valid <= 0;
        end
        OUT_branch.taken <= 0;
        misprReplay <= 0;
        OUT_mispredFlush <= 0;
        OUT_curFetchID <= -1;
        OUT_bpUpdate.valid <= 0;
        pcLookupEntry.valid <= 0;
        stop <= 0;
        memoryWait <= 0;
    end
    else if (IN_branch.taken) begin
        for (i = 0; i < LENGTH; i=i+1) begin
            if ($signed(({entries[i].sqN_msb, i[5:0]}) - IN_branch.sqN) > 0) begin
                entries[i].valid <= 0;
                entries[i].executed <= 0;
            end
        end
        misprReplay <= 1;
        misprReplayEndSqN <= IN_branch.sqN;
        misprReplayIter <= baseIndex;
        misprReplayEnd <= 0;
        OUT_mispredFlush <= 0;
    end
    
    if (!rst) begin
    
        OUT_bpUpdate.valid <= 0;
        
        if (memoryWait && !IN_MEM_busy) begin
            if (instrFence) begin
                instrFence <= 0;
                OUT_clearICache <= 1;
            end
            else begin
                memoryWait <= 0;
            end
        end
        
        // Exception and branch prediction update handling
        pcLookupEntry.valid <= 0;
        if (pcLookupEntry.valid) begin
            if (pcLookupEntry.flags == FLAGS_BRK || pcLookupEntry.flags == FLAGS_FENCE || pcLookupEntry.flags == FLAGS_ORDERING) begin
                
                if (pcLookupEntry.flags == FLAGS_BRK)
                    OUT_halt <= 1;
                else if (pcLookupEntry.flags == FLAGS_ORDERING) begin
                    memoryWait <= 1;
                end
                else if (pcLookupEntry.flags == FLAGS_FENCE) begin
                    instrFence <= 1;
                    memoryWait <= 1;
                    OUT_fence <= 1;
                end
                
                OUT_branch.taken <= 1;
                OUT_branch.dstPC <= {baseIndexPC + (pcLookupEntry.compressed ? 31'd1 : 31'd2), 1'b0};
                OUT_branch.sqN <= pcLookupEntrySqN;
                OUT_branch.flush <= 1;
                OUT_branch.storeSqN <= 0;
                OUT_branch.loadSqN <= 0;
                OUT_branch.fetchID <= pcLookupEntry.fetchID;
                OUT_branch.history <= baseIndexHist;
                stop <= 0;
            end
            else if (pcLookupEntry.flags == FLAGS_EXCEPT || externalIRQ) begin
                
                OUT_irqTaken <= 1;
                
                OUT_branch.taken <= 1;
                OUT_branch.dstPC <= IN_irqAddr;
                OUT_branch.sqN <= pcLookupEntrySqN;
                OUT_branch.flush <= 1;
                // These don't matter, the entire pipeline will be flushed
                OUT_branch.storeSqN <= 0;
                OUT_branch.loadSqN <= 0;
                OUT_branch.fetchID <= pcLookupEntry.fetchID;
                OUT_branch.history <= baseIndexHist;
                
                OUT_irqSrc <= {baseIndexPC, 1'b0};
                OUT_irqFlags <= externalIRQ ? 3'b000 : pcLookupEntry.flags;
                externalIRQ <= 0;
                
                stop <= 0;
            end
            else begin
                OUT_bpUpdate.valid <= 1;
                OUT_bpUpdate.pc <= IN_pcReadData.pc;
                OUT_bpUpdate.compressed <= pcLookupEntry.compressed;
                OUT_bpUpdate.history <= IN_pcReadData.hist;
                OUT_bpUpdate.bpi <= IN_pcReadData.bpi;
                OUT_bpUpdate.branchTaken <= pcLookupEntry.flags == FLAGS_PRED_TAKEN;
            end
        end
        
        // After mispredict, we replay all ops from last committed to the branch
        // without actually committing them, to roll back the Rename Map.
        if (misprReplay && !IN_branch.taken) begin
            
            if (misprReplayEnd) begin
                misprReplay <= 0;
                for (i = 0; i < WIDTH; i=i+1)
                    OUT_comUOp[i].valid <= 0;
                OUT_mispredFlush <= 0;
            end
            else begin
                OUT_mispredFlush <= 1;
                for (i = 0; i < WIDTH; i=i+1) begin
                    if ($signed((misprReplayIter + i[$bits(SqN)-1:0]) - misprReplayEndSqN) <= 0) begin
                        
                        //reg[$clog2(LENGTH)-1:0] id = misprReplayIter[ID_LEN-1:0]+i[ID_LEN-1:0];
                        
                        OUT_comUOp[i].valid <= 1;
                        OUT_comUOp[i].nmDst <= deqEntries[i].name;
                        OUT_comUOp[i].tagDst <= deqEntries[i].tag;
                        OUT_comUOp[i].compressed <= deqEntries[i].executed;
                        for (j = 0; j < WIDTH_WB; j=j+1)
                            if (IN_wbUOps[j].valid && IN_wbUOps[j].nmDst != 0 && IN_wbUOps[j].tagDst == deqEntries[i].tag)
                                OUT_comUOp[i].compressed <= 1;
                    end
                    else begin
                        OUT_comUOp[i].valid <= 0;
                        misprReplayEnd <= 1;
                    end
                end
                misprReplayIter <= misprReplayIter + WIDTH;
            end
        end
        else if (!stop && !IN_branch.taken) begin
            
            reg temp = 0;
            reg pred = 0;
            reg[ID_LEN-1:0] cnt = 0;
            reg[WIDTH-1:0] deqMask = 0;
            
            for (i = 0; i < WIDTH; i=i+1) begin
            
                reg[$clog2(LENGTH)-1:0] id = baseIndex[ID_LEN-1:0] + i[ID_LEN-1:0];
                
                if (!temp && deqEntries[i].executed && (!pred || (deqEntries[i].flags == FLAGS_NONE))) begin
                    OUT_comUOp[i].nmDst <= deqEntries[i].name;
                    OUT_comUOp[i].tagDst <= deqEntries[i].tag;
                    OUT_comUOp[i].sqN <= {deqEntries[i].sqN_msb, id[5:0]};
                    OUT_comUOp[i].isBranch <= deqEntries[i].flags == FLAGS_BRANCH || 
                        deqEntries[i].flags == FLAGS_PRED_TAKEN || deqEntries[i].flags == FLAGS_PRED_NTAKEN;
                    OUT_comUOp[i].compressed <= deqEntries[i].compressed;
                    OUT_comUOp[i].valid <= 1;
                    OUT_curFetchID <= deqEntries[i].fetchID;
                    
                    deqMask[id[1:0]] = 1;
                                   
                    if (|deqEntries[i].flags[2:1] || externalIRQ) begin
                        pcLookupEntry <= deqEntries[i];
                        pcLookupEntrySqN <= {deqEntries[i].sqN_msb, id[5:0]};
                        pred = 1;
                    end
                    
                    if (deqEntries[i].flags[2] || externalIRQ) begin
                        // Redirect result of exception to x0 (TODO: make sure this doesn't leak registers?)
                        if (deqEntries[i].flags == FLAGS_EXCEPT)
                            OUT_comUOp[i].nmDst <= 0;
                        
                        stop <= 1;
                        temp = 1;
                    end
                    
                    entries[id].valid <= 0;
                    entries[id].executed <= 0;     
                    
                    cnt = cnt + 1;
                end
                else begin
                    temp = 1;
                    OUT_comUOp[i].valid <= 0;
                end
            end
            

            /*for (i = 0; i < WIDTH; i=i+1) begin
                if (commitedMask[i]) begin
                    entries[{deqAddresses[i], i[1:0]}].valid <= 0;
                    entries[{deqAddresses[i], i[1:0]}].executed <= 0;
                end
            end*/
            
            baseIndex <= baseIndex + cnt;
        end
        else
            for (i = 0; i < WIDTH; i=i+1)
                OUT_comUOp[i].valid <= 0;
        
        // Enqueue ops directly from Rename
        for (i = 0; i < WIDTH; i=i+1) begin
            if (rnUOpValidSorted[i] && (!IN_branch.taken)) begin
                
                reg[5:0] id = {rnUOpSorted[i].sqN[5:2], i[1:0]};
                
                entries[id].valid <= 1;
                entries[id].tag <= rnUOpSorted[i].tagDst;
                entries[id].name <= rnUOpSorted[i].nmDst;
                entries[id].sqN_msb <= rnUOpSorted[i].sqN[6];
                entries[id].compressed <= rnUOpSorted[i].compressed;
                entries[id].fetchID <= rnUOpSorted[i].fetchID;
                entries[id].executed <= rnUOpSorted[i].fu == FU_RN;
                entries[id].flags <= FLAGS_NONE;
                entries[id].fetchOffs <= rnUOpSorted[i].fetchOffs;
            end
        end
        
        // Mark committed ops as valid and set flags
        for (i = 0; i < WIDTH_WB; i=i+1) begin
            if (IN_wbUOps[i].valid && (!IN_branch.taken || $signed(IN_wbUOps[i].sqN - IN_branch.sqN) <= 0)) begin
            
                reg[$clog2(LENGTH)-1:0] id = IN_wbUOps[i].sqN[ID_LEN-1:0];
                entries[id].executed <= 1;
                entries[id].flags <= IN_wbUOps[i].flags;
            end
        end
        
    end
end


endmodule
