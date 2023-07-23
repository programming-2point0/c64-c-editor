#importonce 
#import "zeropage.asm"
#import "constants.asm"

// ------------------------
//  MEMORY handling
// ------------------------

mem_init:
        // fill memory from MEM_BASE to MEM_BASE + $400 (1KB) with SPACES
        lda #>MEM_BASE
        sta ptr1+1
        lda #(>MEM_BASE)+4
        sta ptr2+1
        lda #<MEM_BASE
        sta ptr1
        sta ptr2
        lda #SPACE
        jsr mem_fill
        rts

mem_show: {
        // prints the entire screen full from memory
        // screen starts at 0429
        lda #$04
        sta ptr1+1
        lda #$29
        sta ptr1

        // Set memory base
        lda #>MEM_BASE
        sta ptr2+1
        lda #<MEM_BASE
        sta ptr2

        // add offset to base: base += offset * LINE_LENGTH
        ldy lines_offset
calc_offset:        
        cpy #$00
        beq cp_lines
        dey
        lda ptr2
        clc
        adc #LINE_LENGTH
        sta ptr2
        lda ptr2+1
        adc #$00
        sta ptr2+1
        jmp calc_offset

cp_lines:
        ldx #$17        // lines to copy - always 23, no matter the offset and total lines
pm_line:ldy #$00
pm_chr: lda (ptr2),y
        sta (ptr1),y
        iny
        cpy #LINE_LENGTH
        bne pm_chr

        // add y to memory-ptr
        tya
        clc
        adc ptr2
        sta ptr2
        lda ptr2+1
        adc #$00
        sta ptr2+1

        // add two more to screen-ptr
        iny
        iny
        tya
        clc
        adc ptr1
        sta ptr1
        lda ptr1+1
        adc #$00
        sta ptr1+1

        dex
        bne pm_line
        rts
}
mem_fill: {
        // fills the memory from ptr1 to ptr2 with whatever is in A
        tax
        lda #$00
        sta ptr_tmp
        lda ptr1+1
        sta ptr_tmp+1
        ldy ptr1
fill_loop:        
        txa
        sta (ptr_tmp),y
        iny
        bne same_page
        inc ptr_tmp+1
same_page:
        lda ptr_tmp+1
        cmp ptr2+1      // if we haven't reached the end yet, keep going
        bne fill_loop
        //  if ptr_tmp+1 is at ptr2+1 - check if y is ptr2
        cpy ptr2
        bne fill_loop
        rts
}
mem_copy: {
        // copies the memory from ptr1 to ptr2 into ptr3
        // if ptr3 (dest) is before/less than ptr1 (start of source) -> copy forwards
        // if ptr3 (dest) is after ptr1 (start of source) -> copy backward
        pha
        tya
        pha
        txa
        pha

        lda ptr3+1
        cmp ptr1+1
        beq check_lo
        bpl mem_copy_bwd
check_lo:
        lda ptr3
        cmp ptr1
        bpl mem_copy_bwd
        
mem_copy_fwd: 
        // copies the memory from ptr1 to ptr2 into ptr3 - starting from ptr1 (destroys ptr1 and ptr3)
        // TODO: Modify this to work like copy_bwd with calculating sizes and blocks
        ldy #$00
!loop:  lda (ptr1),y
        sta (ptr3),y
        
        // increment ptr3
        lda ptr3
        clc
        adc #$01
        sta ptr3
        lda ptr3+1
        adc #$00
        sta ptr3+1

        // increment ptr1
        lda ptr1
        clc
        adc #$01
        sta ptr1
        lda ptr1+1
        adc #$00
        sta ptr1+1

        // check if ptr1 has hit ptr2
        lda ptr1+1
        cmp ptr2+1
        bne !loop-
        lda ptr1
        cmp ptr2
        bne !loop-
mem_copy_done:
        pla
        tax
        pla
        tay
        pla        
        rts

mem_copy_bwd:      
        // copies the memory from ptr1 to ptr2 into ptr3 - starting with ptr2
        // calculate size to copy, and add to ptr3 - store size in ptr_tmp
        lda ptr2
        sec
        sbc ptr1
        sta ptr_tmp
        lda ptr2+1
        sbc ptr1+1
        sta ptr_tmp+1

        // copy last block - that is only a partial block
        // - find dest block start by adding size to dest
        lda ptr3+1
        clc
        adc ptr_tmp+1
        sta ptr3+1
        // - find src block start by adding size to src
        lda ptr1+1
        clc
        adc ptr_tmp+1
        sta ptr1+1
        // - copy block backwards, start with size
        ldy ptr_tmp
!:      lda (ptr1),y
        sta (ptr3),y
        dey
        cpy #$ff
        bne !-  

        // copy remaining blocks, if any
copy_bwd_block:        
        lda ptr_tmp+1           // the size is the number of full blocks
        beq copy_bwd_done       // no more blocks, means no more to copy

        // change src and dest to previous blocks
        dec ptr1+1
        dec ptr3+1
        // copy entire block backwards
        ldy #$ff
!:      lda (ptr1),y
        sta (ptr3),y
        dey
        cpy #$ff
        bne !-  

        // when done, decrement size - so it keeps track of remaining blocks
        dec ptr_tmp+1
        jmp copy_bwd_block
copy_bwd_done:
        jmp mem_copy_done
}