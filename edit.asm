#importonce 
#import "zeropage.asm"
#import "constants.asm"

#import "memory.asm"
#import "cursor.asm"
#import "colors.asm"


// ------------------
//  EDITING 
//    - all editing routines only edit memory, not screen!  
// ------------------
EDIT: {

set_ptr2_to_end_of_last_line: {
        lda lines_total
        cmp #$17
        bcs calc_end_of_mem
        lda #$17
calc_end_of_mem:
        tax     // put lines_total in X
        
        // set end 
        lda #>MEM_BASE
        sta ptr2+1
        lda #<MEM_BASE
        sta ptr2
        
        // add X (lines_total) * LINE_LENGTH to ptr2
!:      lda ptr2
        clc
        adc #LINE_LENGTH
        sta ptr2
        lda ptr2+1
        adc #$00
        sta ptr2+1
        dex
        bne !-
        rts
}

get_line_length: {
        // find the end of the current line - returns the position in A
        sty $04         // save Y
        ldy #LINE_LENGTH
look_for_end:
        dey
        bmi end_found
        lda (mem_line),y
        cmp #SPACE
        beq look_for_end
end_found:
        iny
        tya
        ldy $04         // restore Y
        rts        
}

newline: {
        // reset insert state
        lda #$00
        sta insert_line_y

        jsr shift_lines_down

        // length of first line is xpos
        // length of second line is (endofline / line_length) - xpos

        // keep the first line as is, but clear the remaining (after xpos)
        ldy xpos
        dey             // adjust xpos to zero-offset
        lda #SPACE
!:      sta (mem_line),y
        iny
        cpy #LINE_LENGTH
        bne !-

        // shift the second line xpos-characters to the left
        // ptr1 is the beginning of the line
        // ptr2 is where to find the first character
        lda mem_line
        clc
        adc #LINE_LENGTH
        sta ptr1
        lda mem_line+1
        adc #$00
        sta ptr1+1

        ldx xpos
        dex
        txa
        clc
        adc ptr1
        sta ptr2
        lda ptr1+1
        adc #$00
        sta ptr2+1

        // copy from ptr2 to ptr1, until end of line ptr2 has been reached
        ldy #$00
        ldx xpos
!:      lda (ptr2),y
        sta (ptr1),y
        iny
        inx
        cpx #LINE_LENGTH+1
        bne !-

        // clear remaining of line 
        lda #SPACE
!:      cpy #LINE_LENGTH
        bcs done_clear
        sta (ptr1),y
        iny
        jmp !-
done_clear:
        inc lines_total

        // set pos to beginning of next/new line
        lda #$01
        sta xpos
        inc ypos

        rts
}

insert: {
        // inserts an empty space at xpos - shifts remainder of line to the right
        // if line shifts beyond LINE_LENGTH, a new line is inserted below, and then shifts into that
        // subsequent shifts keep shifting into the same new line, until inserting on another line

        // find end of the line
        jsr get_line_length
        cmp xpos
        bpl insert_and_shift
        // if nothing is after cursor, ignore
        rts
insert_and_shift:
        tay
        // Check if A is LINE_LENGTH - that means we need a new (empty) line
        cmp #LINE_LENGTH
        bne shift

        // we are shifting two lines, so add one line_length to y
        clc
        adc #LINE_LENGTH-1
        tay

        // check if we have already created a new line from this position
        lda ypos
        cmp insert_line_y
        beq shift

        // store this line as the last time we inserted a new line
        sta insert_line_y
        jsr shift_lines_down
        inc lines_total
        tya
        tax                     // store Y in X
        // clear the new line before using
        ldy #LINE_LENGTH
        lda #SPACE
!:      sta (mem_line),y
        iny
        cpy #LINE_LENGTH*2
        bne !-
        txa
        tay                     // restore Y from X
shift:  
        dey
        lda (mem_line),y
        iny
        sta (mem_line),y
        dey        
        cpy xpos
        bpl shift
        lda #SPACE
        sta (mem_line),y
        
        rts        
}

delete: {
        // Deletes a single character - or if at the beginning of a line, deletes the "newline", ie joins this line with the previous
        lda xpos
        cmp #$01
        bne delete_character
        lda ypos
        cmp #$01
        bne delete_line
        // at top of memory-text - nothing to delete here
        rts
}

delete_character: {
        // deletes a single character somewhere on a line
        // - shift every character after XPOS one character to the left, until end of line (LINE_LENGTH)
        ldy xpos
        dey
!:      lda (mem_line),y
        dey
        sta (mem_line),y
        iny
        iny
        cpy #LINE_LENGTH
        bne !-
        dey
        // - add a new space as the last character on the line
        lda #SPACE
        sta (mem_line),y

        // move xpos to cover the deleted character
        dec xpos

        rts
}

delete_line: {
        // deleting a line means joining this line (mem_line) with the previous
        // if the resulting joined line is longer than a single line, the rest of the second line (this line) is overwritten with spaces
        // else, the remaining lines are shifted up, effectively removing this line

        // reset insert state
        lda #$00
        sta insert_line_y

        // get the length of this line
        jsr get_line_length
        sta $03

        // store pointer to this line in ptr2
        lda mem_line
        sta ptr2
        lda mem_line+1
        sta ptr2+1

        // find previous line
        lda mem_line
        sec
        sbc #LINE_LENGTH
        sta mem_line
        lda mem_line+1
        sbc #$00
        sta mem_line+1

        // get the length of that line
        jsr get_line_length
        // if previous line is LINE_LENGTH, ie a full line, we can't delete anything
        cmp #LINE_LENGTH
        bne go_ahead
        // so just cancel without doing anything ... 
        // we have destroyed mem_line, but ypos is okay, so a cursor_calculate should fix it
        rts

go_ahead:
        sta $02

        // also store the pointer in ptr1
        lda mem_line
        sta ptr1
        lda mem_line+1
        sta ptr1+1

        // now join the two lines
        // - first add the length of line 1 to ptr1
        lda ptr1
        clc
        adc $02
        sta ptr1
        lda ptr1+1
        adc #$00
        sta ptr1+1

        // - then copy from beginning of line 2 to end of line 1 - until the end of line 2
        ldy #$00
!:      cpy $03         // Y could be 0 from the beginning, so maybe skip
        beq done_copy
        lda (ptr2),y
        sta (ptr1),y
        iny
        jmp !-

done_copy:

        // set new xpos to the joining of the two lines
        lda $02
        sta xpos
        inc xpos
        // move ypos one line up
        dec ypos

        // calculate the total length of the new line
        lda $02
        clc
        adc $03
        // if it is shorter than LINE_LENGTH, shift lines up
        cmp #LINE_LENGTH+1
        bcs keep_both_lines
        
        jsr shift_lines_up
        jsr clear_lastline
        dec lines_total
        rts

keep_both_lines:
        // clear the remaining of line1, that now spans two LINE_LENGTHs
        // Calculate the total characters to "erase" - total is LINE_LENGTH * 2
        // but with an offset of length of line 1 (in $02)
        lda #LINE_LENGTH*2
        sec
        sbc $02
        sta $02         // overwrite length, don't think we need it anymore
        
        lda #$20
!:      sta (ptr1),y
        iny
        cpy $02
        bne !-        
        
        rts
}

clear_lastline: {
        // clears the last line in the text after a shift up
        // abuses the fact that ptr3 points to the beginning of the last line
        ldy #$00
        lda #SPACE
!:      sta (ptr3),y
        iny
        cpy #LINE_LENGTH
        bne !-
        rts
}

shift_lines_up: {
        // move all lines after this, actually after next, one line up
        // mem_line is expected to be the line to keep - the next line is overwritten with the next again
        // ptr1 (start) = next-next line
        // ptr2 (end) = end of last line
        // ptr3 (destination) = next line
        lda mem_line
        clc
        adc #LINE_LENGTH
        sta ptr3
        lda mem_line+1
        adc #$00
        sta ptr3+1

        lda ptr3
        clc
        adc #LINE_LENGTH
        sta ptr1
        lda ptr3+1
        adc #$00
        sta ptr1+1

        jsr set_ptr2_to_end_of_last_line

        // if last line (ptr2) is somehow before start (ptr1) (can happen if we are deleting the very last line)
        // - then don't copy, but clear the line starting at start
        lda ptr1+1
        cmp ptr2+1
        bcc go_copy
        lda ptr1
        cmp ptr2
        bcc go_copy

        // don't copy, but clear line
        ldy #$00
        lda #SPACE
!:      sta (ptr1),y
        iny
        cpy #LINE_LENGTH
        bne !-
        rts
go_copy:
        jsr mem_copy
        rts
}

shift_lines_down: {
        // move all lines after this one line down (duplicates this line)
        // ptr1 (start) = this line
        // ptr2 (end) = end of last line
        // ptr3 (destination) = next line

        lda mem_line
        sta ptr1
        lda mem_line+1
        sta ptr1+1

        lda mem_line
        clc
        adc #LINE_LENGTH
        sta ptr3
        lda mem_line+1
        adc #$00
        sta ptr3+1

        jsr set_ptr2_to_end_of_last_line

        jsr mem_copy

        rts
}

}