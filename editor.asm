.const SCNKEY = $ff9f
.const GETIN = $ffe4

.const LINE_LENGTH = $26
.const SPACE = $20



BasicUpstart2(Entry)

*=$2000 "Graphics"
        .import binary "c-font.font"

.var MEM_BASE = $3000

*=$e0 virtual
.zp {
        xpos:           .byte 0
        ypos:           .byte 0
        ptr1:           .word 0
        ptr2:           .word 0
        ptr3:           .word 0
        ptr_tmp:        .word 0
        st_cursor:      .word 0
        scr_cursor:     .word 0
        scr_line:       .word 0
        mem_cursor:     .word 0
        mem_line:       .word 0
}       // current 10 - max 16 bytes

       
        * = $0820 "Program"
Entry:  // blue background color
        lda #$06
        sta $d020
        sta $d021

        // select font
        lda #%0011000        // select at address 00ab c000 0000 0000 - by setting xxxx abcx = xxxx 1000 => $2000
        sta $d018       

        // disable SHIFT+C=
        lda #$80
        sta $0291

        // turn on cursor (sprite)
        lda #$1
        sta $d015
        lda #$a0              // cursor at Address $2800 = $a0 * $40
        sta $07f8

        // draw border
        jsr border

        // initialize memory
        jsr mem_init

        // show memory on screen
        jsr mem_show

        // initialize cursor
        jsr cursor_init
        jsr cursor_calculate
        jsr cursor_update      

getkey: jsr GETIN
        cmp #$00
        beq getkey

        ldx #$01
        ldy #$00
        jsr st_setpos
        pha
        jsr st_print_hex        // only for debugging
        pla

        cmp #$13
        beq key_crsr_home
//        cmp #$93
//        beq key_crsr_sh_home
        cmp #$91
        beq key_crsr_up
        cmp #$11
        beq key_crsr_down
        cmp #$9d
        beq key_crsr_left
        cmp #$1d
        beq key_crsr_right

        cmp #$0d
        beq key_return
        cmp #$14
        beq key_delete          // aka backspace
        cmp #$94
        beq key_insert


        // Debugging tools for displaying memory, erasing line and entering complete line
        cmp #$85
        beq key_f1
        cmp #$89
        beq key_f2
        cmp #$86
        beq key_f3
  
        cmp #$8a
        beq key_f4
        cmp #$87
        beq key_f5
/*        cmp #$8b
        beq key_f6
        cmp #$88
        beq key_f7
        cmp #$8c
        beq key_f8
*/
        // todo: only if printable char
        jsr printchar
nxtchar:jsr cursor_update
        jmp getkey


key_crsr_home:
        jsr cursor_home
        jmp nxtchar
key_crsr_left:
        jsr cursor_left
        jmp nxtchar
key_crsr_right:
        jsr cursor_right
        jmp nxtchar
key_crsr_up:
        jsr cursor_up
        jmp nxtchar
key_crsr_down:
        jsr cursor_down
        jmp nxtchar

key_return:
        jsr edit_newline
        jsr cursor_calculate
        jsr mem_show
        jmp nxtchar

key_delete:
        jsr edit_delete_char
        jsr cursor_calculate
        jsr mem_show
        jmp nxtchar

key_insert:
        jsr edit_insert_char
        jsr mem_show
        jmp nxtchar

key_f1:
        jsr mem_show
        jmp nxtchar
key_f2:
        // fill current line with letters and numbers
        ldy #$00
db_fl:  tya
        sta (mem_line),y
        iny
        cpy #LINE_LENGTH
        bne db_fl
        jsr mem_show
        jmp nxtchar

key_f3:
        // clear current line
        ldy #$00
        lda #SPACE
db_cl:  sta (mem_line),y
        iny
        cpy #LINE_LENGTH
        bne db_cl
        jsr mem_show
        jmp nxtchar
key_f5: jmp key_f5_long
key_f4:
        // clear screen
        lda #SPACE
        ldy #$00
clsr:   sta $3000,y
        sta $3100,y
        sta $3200,y
        sta $3300,y
        iny
        bne clsr
        jsr mem_show
        jmp nxtchar

key_f5_long:
        // write a, b, c, d and so on
        ldx #$41
alfa:   txa
        jsr printchar
        jsr cursor_down
        inx
        lda ypos
        cmp #$16
        bne alfa
        jmp nxtchar


// -------------------------------
//  CURSOR handling
// -------------------------------

cursor_init:
        lda #$01
        sta xpos
        sta ypos
        rts

cursor_update:
        jsr show_cursor
        jsr show_cursor_coords
        rts

cursor_home: {
        // move cursor to beginning of current line
        // if already at beginning of current line, move to top of screen
        // if already at top of screen, scroll to top of memory-text
        lda #$01
        cmp xpos
        bne setxpos
        cmp ypos
        bne setypos
        // TODO: scroll
setypos:sta ypos       
setxpos:sta xpos
        jmp cursor_calculate
}

cursor_top:
        // move cursor to top of screen (and beginning of that line)
        // TODO: Handle scrolling - if screen isn't showing top of memory
        lda #$01
        sta xpos
        sta ypos
        jmp cursor_calculate

cursor_left: {
        // move cursor to the left - if already at beginning of line, move to end of previous line
        dec xpos
        bne cursor_calculate // not at beginning, done
        lda #$01
        cmp ypos
        beq stay        // if at very first line, ignore moving up, 
        jsr cursor_up
        jsr edit_endofline // Move to last character, rather than just end-pos
stay:   sta xpos
        inc xpos
        jmp cursor_calculate
}

cursor_right:
        // move cursor to the right - if at the end of line, move to beginning of next line
        inc xpos
        lda xpos
        cmp #$27
        bne cursor_calculate       // not at end, done
        lda #$01        
        sta xpos        // reset x-pos
        jmp cursor_down

cursor_up:
        // move cursor up - if at top of screen (and memory), don't move
        dec ypos
        bne cursor_calculate       // not at top, done
        lda #$01
        sta ypos
        jmp cursor_calculate

cursor_down:
        // move cursor down - if at end of screen, scroll ...
        inc ypos
        lda ypos
        cmp #$18
        bne cursor_calculate
        // TODO: Handle scroll
        lda #$17        // Don't do this, this just prevents scrolling down
        sta ypos
        jmp cursor_calculate    // NOTE, while technically not needed here, makes for better structure

cursor_calculate:
        // use ypos and xpos to calculate screen and memory cursors
        pha
        txa
        pha
        tya
        pha
        jsr cursor_calc_scr
        jsr cursor_calc_mem
        pla
        tay
        pla
        tax
        pla
        rts

cursor_calc_scr:
        // calculate screen-cursors
        // scr_cursor - the exact address of the current position
        // scr_line   - the address of the current line (the border, +1 is the first character)
        // first the line - ignoring xpos
        lda ypos
        asl
        tay
        lda screen,y
        sta scr_line
        lda screen+1,y
        sta scr_line+1
        // then the cursor, add x to the line
        lda xpos
        clc
        adc scr_line
        sta scr_cursor
        lda scr_line+1
        adc #$00
        sta scr_cursor+1
        rts

cursor_calc_mem: {
        // calculate memory cursors
        // mem_cursor - the exact address of the current position
        // mem_line - the address of the current line (0 is the first character) 
        lda #<MEM_BASE
        sta mem_line
        lda #>MEM_BASE
        sta mem_line+1

        ldy ypos
nxline: dey
        beq thisline
        // add one line-length, Y times, to address
        lda mem_line
        clc
        adc #LINE_LENGTH
        sta mem_line
        lda mem_line+1
        adc #$00
        sta mem_line+1
        jmp nxline

thisline:        
        // found line - now add xpos to cursor
        ldx xpos
        dex
        txa
        clc
        adc mem_line
        sta mem_cursor
        lda mem_line+1
        adc #$00
        sta mem_cursor+1
        rts
}        
show_cursor:
        // shows the actual cursor at the current cursor_position
        ldx xpos        
        cpx #$1d        // Check for out of bounds
        lda #$00
        rol             // turn bit 8 on if greater than 1d
        sta $d010
        txa
        asl
        asl
        asl
        adc #$18
        sta $d000

        lda ypos
        asl
        asl
        asl
        adc #$32
        sta $d001
        rts

show_cursor_coords:
        // shows the current cursor coordinates in the status-line
        ldx #$02
        ldy #$18
        jsr st_setpos

        lda #SPACE      // Insert space before
        jsr st_print

        lda ypos
        jsr st_print_dec       

        lda #$3a        // :
        jsr st_print
        lda xpos
        jsr st_print_dec

        lda #SPACE      // insert space after
        jsr st_print

        lda #$80
        jsr st_print    // end with line to erase earlier characters
        jsr st_print
        jsr st_print    // just in case - add some extras

        rts

// ----------------------
//  PRINTING
// ----------------------

printchar:
        jsr convertchar

        // prints the character in A - on screen and in memory
        ldy #$00
        sta (scr_cursor),y
        sta (mem_cursor),y

        // move cursor to next position
        jsr cursor_right
        // TODO: Check if cursor is on new line - if so, then insert line
   
        rts

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
        inc ypos
        lda #$01
        sta xpos
        rts       
}

edit_dupl_line: {
        // add a new line in memory after current line
        // copy from current line until end of last line into next line

        // TODO: Find end of last line, right now, just fake it as hardcoded
        lda #$43
        sta ptr2+1
        lda #$69
        sta ptr2

        // current line and next line
        lda mem_line
        sta ptr1
        clc
        adc #LINE_LENGTH
        sta ptr3
        lda mem_line+1
        sta ptr1+1
        adc #$00
        sta ptr3+1

        jmp mem_copy
}

edit_remove_line: {
        // TODO: Find end of last line, right now, just fake it as hardcoded
        lda #$43
        sta ptr2+1
        lda #$69
        sta ptr2

 // current line and next line
        lda mem_line
        sta ptr3
        clc
        adc #LINE_LENGTH
        sta ptr1
        lda mem_line+1
        sta ptr3+1
        adc #$00
        sta ptr1+1

        jmp mem_copy
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

border: {
        // Draw border on screen
        lda #$40
        ldx #LINE_LENGTH+1
b_hori: sta $0400,x
        sta $07c0,x
        dex
        bne b_hori
        
        ldx #$00
b_vert: lda screen,x
        sta ptr1
        lda screen+1,x
        sta ptr1+1
        lda #$7b
        ldy #$00
        sta (ptr1),y
        ldy #LINE_LENGTH+1
        sta (ptr1),y
        inx
        inx
        cpx #$32        // lines on screen*2
        bne b_vert

        // Draw corners
        lda #$70  // top left corner
        sta $0400
        lda #$6D  // bottom left
        sta $07c0
        lda #$7D  // bottom right
        sta $07e7
        lda #$6E  // top right
        sta $0427
        rts
}       

st_setpos:
        // sets the position for the st-cursor x=x, y=y (a ignored (stacked))
        pha
        tya
        asl
        tay
        txa
        clc
        adc screen,y
        sta st_cursor
        lda screen+1,y
        adc #$00
        sta st_cursor+1
        pla
        rts

st_print:
        // prints a character at the st-cursor's position, and moves the cursor
        pha
        sty $04
        jsr convertchar
        ldy #$00
        sta (st_cursor),y
        lda st_cursor
        clc
        adc #$01
        sta st_cursor
        lda st_cursor+1
        adc #$00
        sta st_cursor+1
        pla
        ldy $04
        rts

convertchar: {
        cmp #$40
        bcc not_letter
        bpl lower_case
        sbc #$40
lower_case:        
        sbc #$40
not_letter:
        rts
}

st_print_hex: {
        // prints a hexadecimal value (byte) to the current st-position
        pha
        lsr
        lsr
        lsr
        lsr
        jsr nibble
        pla
nibble: and #$0f
        ora #$30        // add digit "0"
        cmp #$3a        // check if it is a digit (0-9)
        bcc hx_echo
        adc #$06        // if not - add 7 (6+1c)
hx_echo:jsr st_print
        rts
}
st_print_dec: {
        // prints a decimal value (byte) to the current st-position (without leading zeroes) (destroys all registers)
        ldy #$00
        ldx #$2f
        sec
ct100s: inx
        sbc #100        // count 100s
        bcs ct100s
        adc #100        // counts one too far, so add 100 again
        cpx #$30
        beq skip01      // don't print leading zeroes
        iny             // count printed characters
        pha
        txa
        jsr st_print    // print 100s
        pla
skip01: ldx #$2f
        sec
ct10s:  inx
        sbc #10         // count 10s
        bcs ct10s
        adc #10         // counts too far, so add 10 again
        cpx #$30
        bne print10
        cpy #$00
        beq skip02
print10:iny
        pha
        txa
        jsr st_print    // print tens
        pla

skip02: clc
        adc #$30
        jsr st_print    // print ones
        rts
}
screen: .word $0400, $0428, $0450, $0478, $04A0, $04C8, $04F0 
        .word $0518, $0540, $0568, $0590, $05B8, $05E0
        .word $0608, $0630, $0658, $0680, $06A8, $06D0, $06F8
        .word $0720, $0748, $0770, $0798, $07C0

        
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

        // TODO: use offset and enable scroll
        lda #>MEM_BASE
        sta ptr2+1
        lda #<MEM_BASE
        sta ptr2

        ldx #$17        // lines to copy
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
        // calculate size to copy, and add to ptr3
        // ptr3 = ptr2 + ptr3 - ptr1 
        // first calculate ptr3 = ptr2 + ptr3
        lda ptr2
        clc
        adc ptr3
        sta ptr3
        lda ptr2+1
        adc ptr3+1
        sta ptr3+1
        // anything in carry here? shouldn't be, unless we go over ffff, and we wouldn't

        // then calculate ptr3 = ptr3 - ptr1 (make sure to check for borrowing!)
        lda ptr3
        sec
        sbc ptr1
        sta ptr3
        lda ptr3+1
        sbc ptr1+1
        sta ptr3+1

        ldy #$00
        jmp mcpy
!loop:  // increment ptr3
        lda ptr3
        sec
        sbc #$01
        sta ptr3
        lda ptr3+1
        sbc #$00
        sta ptr3+1

        // decrement ptr2
        lda ptr2
        sec
        sbc #$01
        sta ptr2
        lda ptr2+1
        sbc #$00
        sta ptr2+1

mcpy:   lda (ptr2),y
        sta (ptr3),y

        // check if ptr2 has hit ptr1
        lda ptr2+1
        cmp ptr1+1
        bne !loop-
        lda ptr2
        cmp ptr1
        bne !loop-
        jmp mem_copy_done
}