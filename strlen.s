.text


strlen:
    lw t0, 4(x0)
    addi t2, t0, 1
    .loop:
        lb t1, 0(t0)
        addi t0, t0, 1
        bnez t1, .loop
    
    sub t0, t0, t2
    sw t0, 1023(x0)
    sw t0, 4(x0)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop