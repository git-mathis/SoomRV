
module BranchSelector
#(
    parameter NUM_BRANCHES=4
)
(
    input wire clk,
    input wire rst,
    
    input BranchProv IN_branches[NUM_BRANCHES-1:0],
    output BranchProv OUT_branch,
    
    input SqN IN_ROB_curSqN,
    input SqN IN_RN_nextSqN,
    input wire IN_mispredFlush
    //output reg OUT_mispredFlush
);

integer i;

SqN mispredFlushSqN;
reg disableMispredFlush;

always_comb begin
    OUT_branch.taken = 0;
    OUT_branch = 0;
    for (i = 0; i < 4; i=i+1) begin
        if (IN_branches[i].taken && 
            (!OUT_branch.taken || $signed(IN_branches[i].sqN - OUT_branch.sqN) < 0) &&
            (!IN_mispredFlush || $signed(IN_branches[i].sqN - mispredFlushSqN) < 0)) begin
            OUT_branch.taken = 1;
            OUT_branch.dstPC = IN_branches[i].dstPC;
            OUT_branch.sqN = IN_branches[i].sqN;
            OUT_branch.loadSqN = IN_branches[i].loadSqN;
            OUT_branch.storeSqN = IN_branches[i].storeSqN;
            if (i == 3)
                OUT_branch.flush = IN_branches[i].flush;
            OUT_branch.fetchID = IN_branches[i].fetchID;
            OUT_branch.history = IN_branches[i].history;
        end
    end
end

always_ff@(posedge clk) begin
    
    if (rst) begin
        mispredFlushSqN <= 0;
        disableMispredFlush <= 0;
        //OUT_mispredFlush <= 0;
    end
    else if (OUT_branch.taken) begin
        mispredFlushSqN <= OUT_branch.sqN;
        //OUT_mispredFlush <= (IN_ROB_curSqN != IN_RN_nextSqN);
        //disableMispredFlush <= 0;
    end
    /*else if (OUT_mispredFlush) begin
        disableMispredFlush <= (IN_ROB_curSqN == IN_RN_nextSqN);
        if (disableMispredFlush)
            OUT_mispredFlush <= 0;
    end*/

end

endmodule
