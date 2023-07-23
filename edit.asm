#importonce 
#import "zeropage.asm"
#import "constants.asm"

#import "memory.asm"
#import "cursor.asm"

// ------------------
//  EDITING 
//    - all editing routines only edit memory, not screen!  
// ------------------

edit_newline: {
        // inserts a new-line below this one - breaks the current line at current xpos if needed
        // - if cursor is at beginning, insert empty line BEFORE this
        // - if cursor is at end, or line is empty, insert empty line AFTER this
        // - if cursor is in the middle, break line at cursor

        // duplicate current line no matter what
        jsr edit_dupl_line      

        // if we are at the beginning of the line, or there are only empty spaces before cursor:
        // - insert a new line BEFORE this
        // - else, go to not_at_beginning, and break the line
        lda xpos
        cmp #$01
        beq at_beginning
        tay
        dey
only_spaces:
        lda (mem_line),y
        cmp #SPACE
        bne not_at_beginning
        dey
        bpl only_spaces

at_beginning:
        // clear current line (insert empty line before)
        ldy #$00
        lda #SPACE
!:      sta (mem_line),y
        iny
        cpy #LINE_LENGTH
        bne !-
        jmp newline_end

not_at_beginning:
        // The line is not empty - if we are at the end of the line
        // - insert a new line AFTER this
        // - else, break the line at cursor position

        // find end of current (original) line
        jsr edit_endofline      
        cmp xpos        
        bpl newline_break       // line ends after xpos

        // insert new line AFTER this (by clearing the duplicate)
        ldy #LINE_LENGTH
        lda #SPACE
!:      sta (mem_line),y
        iny
        cpy #LINE_LENGTH*2
        bne !-
        jmp newline_end      

newline_break:
        // break the line at the cursor        
        sec
        sbc xpos                // x = end_of_line - xpos
        tax

        // find next line, store in ptr_tmp
        lda mem_line
        clc
        adc #LINE_LENGTH
        sta ptr_tmp
        lda mem_line+1
        adc #$00
        sta ptr_tmp+1
        // copy / move from current-pos to next_line
        ldy #$00
!:      lda (mem_cursor),y
        sta (ptr_tmp),y
        lda #SPACE              // "remove" (overwrite with space) after copy
        sta (mem_cursor),y
        iny
        dex                     // copy only characters between xpos and end of line/last character
        bpl !-

        // clear remaining of next line
!:      cpy #LINE_LENGTH
        beq newline_end
        lda #SPACE
        sta (ptr_tmp),y
        iny
        jmp !-
newline_end:
        lda #$01
        sta xpos
        jsr cursor_down
        rts       
}

edit_dupl_line: {
        // add a new line in memory after current line
        // copy from current line until end of last line into next line

        // set start (ptr1) to this line (mem_line)
        lda mem_line
        sta ptr1
        lda mem_line+1
        sta ptr1+1

        // set end (ptr2) to end of last line
        jsr set_ptr2_to_end_of_last_line
  
        // set destination (ptr3) to next line (mem_line + LINE_LENGTH)
        lda mem_line
        clc
        adc #LINE_LENGTH
        sta ptr3
        lda mem_line+1
        adc #$00
        sta ptr3+1

        jsr mem_copy
        inc lines_total         // increase total number of lines

        // duplicate colors, but only if ypos is on the visible screen!
        lda ypos
        sec
        sbc lines_offset
        cmp #$16
        bcc duplicate_colors
        rts
duplicate_colors:        
// TODO: Put in own sub-routine
        lda #$db
        sta ptr2+1
        lda #$97        // skip last line, since that is for the border
        sta ptr2

        // first add D4 to base addresses (gives us D8xx from 04xx)
        lda scr_line+1
        clc
        adc #$d4
        sta ptr1+1
        sta ptr3+1

        // then add one screen line length to dest
        lda scr_line
        sta ptr1
        clc
        adc #LINE_LENGTH+2      // screen lines are +2 including border
        sta ptr3
        lda ptr3+1
        adc #$00
        sta ptr3+1
        
        jmp mem_copy     
}

set_ptr2_to_end_of_last_line:
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

edit_remove_line: {
        // remove the current line (mem_line)
        // if this is the last line, then just fill with spaces
        // else copy from next line to last line into this
        lda ypos
        cmp lines_total
        beq last_line

        // copy from the next line until end of last line into current line
        // set start (ptr1) to next line (mem_line + LINE_LENGTH)
        lda mem_line
        clc
        adc #LINE_LENGTH
        sta ptr1
        lda mem_line+1
        adc #$00
        sta ptr1+1

        // set end (ptr2) to end of last line
        jsr set_ptr2_to_end_of_last_line

        // set destination (ptr3) to this line (mem_line)
        lda mem_line
        sta ptr3
        lda mem_line+1
        sta ptr3+1

        jsr mem_copy
        dec lines_total         // decrement the total number of lines

        // also move colors (shift one line up)
        // TODO: Put in own sub-routine
        lda #$db
        sta ptr2+1
        lda #$97        // skip last line, since that is for the border
        sta ptr2

        // first add D4 to base addresses (gives us D8xx from 04xx)
        lda scr_line+1
        clc
        adc #$d4
        sta ptr1+1
        sta ptr3+1

        // then add one screen line length to src (keep dest)
        lda scr_line
        sta ptr3
        clc
        adc #LINE_LENGTH+2
        sta ptr1
        lda ptr1+1
        adc #$00
        sta ptr1+1

        jmp mem_copy
        
last_line:
        // don't move anything in memory, just make sure that this line is cleared
        ldy #$00
        lda #SPACE
!:      sta (mem_line),y
        iny
        cpy #LINE_LENGTH
        bne !-

        // but still decrement the total number of lines
        dec lines_total         
        rts

}

edit_endofline: {
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

edit_delete_char: {
        // if at first xpos, join this and previous line
        // else - move remaining characters (until last) one to the left
        lda xpos
        cmp #$01
        beq edit_joinlines

        // find last character
        tay             // store xpos in y
        dey             // offset in memory
        jsr edit_endofline
        sta $02

        // if we are beyond the last character, skip shifting
        cpy $02
        bcs clr_last

shift_left:        
        lda (mem_line),y
        dey
        sta (mem_line),y
        iny
        iny
        cpy $02
        bne shift_left
        
clr_last:
        // put a space over the last position
        lda #SPACE
        dey
        sta (mem_line),y
        dec xpos
        rts
}

edit_joinlines: {
        // find end of this line
        jsr edit_endofline      
        cmp #$00        // if empty line - just delete the entire line
        beq delete_line_in_mem
        sta $02         // remember the end for later

        // find previous line (keep this one in ptr_tmp)
        lda mem_line
        sta ptr_tmp;
        sec
        sbc #LINE_LENGTH
        sta mem_line
        lda mem_line+1
        sta ptr_tmp+1
        sbc #$00
        sta mem_line+1

        // find end of previous line - set mem_cursor to that pos, and remember in xpos
        jsr edit_endofline
        // if end of previous line is the line-length - nothing can be joined into it
        cmp #LINE_LENGTH
        bne joinline_go
        rts
joinline_go:        
        sta xpos
        inc xpos
        tax
        clc
        adc mem_line
        sta mem_cursor
        lda mem_line+1
        adc #$00
        sta mem_cursor+1

        // copy from beginning of this line to end of previous 
        ldy #$00
!:      lda (ptr_tmp),y
        sta (mem_cursor),y
        inx                     // count total characters 
        iny
        cpy $02                 // check if we have reached the end of the original line
        bne !-

        // if total is less than LINE_LENGTH delete this line
        // else, fill remaining with spaces
        cpx #LINE_LENGTH
        bcc delete_line
        beq delete_line
        // fill remaining line with spaces
        lda #SPACE
!:      sta (mem_cursor),y
        iny
        inx
        cpx #$4c        // Two lines
        bne !-
joinline_end:
        jmp cursor_up        

delete_line:
        // delete the line currently in tmp (by copying tmp to mem)
        lda ptr_tmp
        sta mem_line
        lda ptr_tmp+1
        sta mem_line+1
delete_line_in_mem:        
        jsr edit_remove_line
     
        jmp joinline_end
}

edit_insert_char: {
        // inserts an empty space at xpos - shifts remainder of line to the right
        // find end of the line
        jsr edit_endofline
        cmp xpos
        bpl insert_and_shift
        // if nothing is after cursor, ignore
        rts
insert_and_shift:
        tay
        // Check if A is LINE_LENGTH - that means we need a new (empty) line
        cmp #LINE_LENGTH
        bne shift
        jsr edit_dupl_line
        tya
        tax                     // store Y in X
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
