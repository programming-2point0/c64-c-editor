BasicUpstart2(Entry)

*=$3000
        .import binary "c-font.font"

*=$e0 virtual
.zp {
ptr1:   .word 0
ptr2:   .word 0
ptr3:   .word 0
st_cursor: .word 0
scr_cursor: .word 0
scr_line: .word 0
mem_cursor: .word 0
mem_line: .word 0
} 
//      TODO: Get rid of these
        .var cur_line = $f9
       
        .var xpos = $fd
        .var ypos = $fe        
        .var lines = $ff
        
        .label SCNKEY = $ff9f
        .label GETIN = $ffe4
        
        * = $0820
Entry:  // blue background color
        lda #$06
        sta $d020
        sta $d021

        // clear screen
        ldx #$00
        lda #$20
rst_scr:sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $06e7,x
        inx
        bne rst_scr

        // select font
        lda #$1c        // select at address 00ab c000 0000 0000 - by setting xxxx abcx = xxxx 1100 => $3000
        sta $d018       

        // turn on cursor (sprite)
        lda #$1
        sta $d015
        lda #$e0
        sta $07f8

        // draw border
        jsr border

        // initialize memory

        // show memory on screen

        // initialize cursor
        jsr cursor_init
        jsr cursor_update
        
        lda #$17        // TODO: Make this number of lines somewhere else ...
        sta lines

wait:   jsr GETIN
        cmp #$00
        beq wait

        ldx #$01
        ldy #$00
        jsr st_setpos
        pha
        jsr st_print_hex        // only for debugging
        pla

        cmp #$13
        beq key_crsr_home
        cmp #$93
        beq key_crsr_sh_home
        cmp #$91
        beq key_crsr_up
        cmp #$11
        beq key_crsr_down
        cmp #$9d
        beq key_crsr_left
        cmp #$1d
        beq key_crsr_right

        // todo: only if printable char
        jsr printchar
nxtchar:jsr cursor_update
        jmp wait


key_crsr_home:
        jsr cursor_home
        jmp nxtchar
key_crsr_sh_home:
        jsr cursor_top
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

cursor_home:
        // move cursor to beginning of current line
        lda #$01
        sta xpos
        // TODO: Calculate new cursor positions for screen and memory
        rts

cursor_top:
        // move cursor to top of screen (and beginning of that line)
        // TODO: Handle scrolling - if screen isn't showing top of memory
        lda #$01
        sta xpos
        sta ypos
        // TODO: Calculate new cursor positions for screen and memory
        rts

cursor_left:
        // move cursor to the left - if already at beginning of line, move to end of previous line
        dec xpos
        bne !ret+       // not at beginning, return
        lda #$01
        cmp ypos
        beq stay        // if at very first line, ignore moving up, 
        jsr cursor_up

        lda #$26        // TODO: Find lastcharacter, rather than just end-pos
stay:   sta xpos
        
!ret:   // TODO: Calculate new cursor positions for screen and memory
        rts

cursor_right:
        // move cursor to the right - if at the end of line, move to beginning of next line
        inc xpos
        lda xpos
        cmp #$27
        bne !ret+       // not at end, return
        lda #$01        
        sta xpos        // reset x-pos
        jsr cursor_down

!ret:   // TODO: Calculate new cursor positions for screen and memory
        rts

cursor_up:
        // move cursor up - if at top of screen (and memory), don't move
        dec ypos
        bne !ret+       // not at top, return
        lda #$01
        sta ypos
!ret:   // TODO: Calculate new cursor positions for screen and memory
        rts

cursor_down:
        // move cursor down - if at end of screen, scroll ...
        inc ypos
        lda ypos
        cmp #$18
        bne !ret+
        // TODO: Handle scroll
        lda #$17        // Don't do this, this just prevents scrolling down
        sta ypos

!ret:   // TODO: Calculate new cursor positions for screen and memory
        rts     

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

        lda #$20        // Insert space before
        jsr st_print

        lda ypos
        jsr st_print_dec       

        lda #$3a        // :
        jsr st_print
        lda xpos
        jsr st_print_dec

        lda #$20        // insert space after
        jsr st_print

        lda #$80
        jsr st_print    // end with line to erase earlier characters
        jsr st_print
        jsr st_print    // just in case - add some extras

        rts


printchar:
        cmp #$0d
        beq makenewline
        cmp #$14
        beq backspace
        jsr convertchar
        // todo: keep curline, to avoid re-calculating
        ldy ypos
        jsr setcurline

        jsr print

        // move cursor to next position
        inc xpos
        lda xpos
        cmp #$27
        beq newline
        rts

makenewline:
        jsr insertline
        jsr breakline
        jsr newline
        rts


newline:
        lda #$01
        sta xpos
        inc ypos
        // TODO: Handle scroll
        rts


backspace:
        ldx xpos
        cpx #$01
        bne normal_bs // TODO: Move this line up to the one before

        ldy ypos
        dey
        jsr joinline

        // TODO: Calc new cursor
        rts

        // move rest of this line one to the left

normal_bs:        
        ldy ypos
        jsr scrptr
        txa
        tay
bs_left:lda (ptr1),y
        dey
        sta (ptr1),y
        iny
        iny
        cpy #$27
        bne bs_left
        lda #$20
        dey
        sta (ptr1),y

        dec xpos

no_bs:  rts        

joinline:
        // line 1 in y - line 2 is y+1 - x is ignored (and destroyed)
        sty $04
        // find last character on line 1 - store in pointer2
        jsr lastchr

        lda ptr1
        sta ptr2
        lda ptr1+1
        sta ptr2+1

        // ptr2 contains address of last character on line 1
        // find last character on line 2:
        ldy $04
        iny
        jsr scrptr
        ldy #$27
lspace: dey
        beq emptylin
        lda (ptr1),y
        cmp #$20
        beq lspace
        tya
        tax

        // ptr1 contains address of first character on line 2
        // y contains the index of the last character on the line
        
        // copy from line2[1] until line2[last] to line1[last++]
        ldy #$01
copy:   lda (ptr1),y
        sta (ptr2),y
        iny
        //cpy #$27
//        bne nextchar

nextchar:dex
        cpx #$00
        bne copy
        rts




lastchr:jsr scrptr
        ldy #$27
lsspace:dey
        beq emptylin
        lda (ptr1),y
        cmp #$20
        beq lsspace
        tya
        clc
        adc ptr1
        sta ptr1
        lda ptr1+1
        adc #$00
        sta ptr1+1
emptylin:
        rts

breakline:
        ldx xpos
        ldy ypos
        jsr scrptr
        // find last character on this line
        ldy #$27
space:  dey
        cpy xpos
        beq onlyspaces
        lda (ptr1),y
        cmp #$20
        beq space
        // y now contains the last xpos to have something in it
        // subtract xpos from y
        tya
        sec
        sbc xpos
        // a is now the number of characters AFTER current xpos
        pha
        // make ptr2 the current character
        lda ptr1
        clc
        adc xpos
        sta ptr2
        lda ptr1+1
        adc #$00
        sta ptr2+1

        // find beginning of next line
        ldx #$01
        ldy ypos
        iny
        jsr scrptr

        // copy from current-pos to last - to next line
        pla
        tay
br_copy:        lda (ptr2),y
        iny
        sta (ptr1),y
        dey
        lda #$20
        sta (ptr2),y
        dey
        bpl br_copy

onlyspaces:
        rts



insertline:
        // find last line - TODO: Find in memory, rather than on screen
        ldy lines
        dey
        ldx #$01
        jsr scrptr
        lda ptr1
        clc
        adc #$28
        sta ptr2
        lda ptr1+1
        adc #$00
        sta ptr2+1
        ldx lines

inserts:        ldy #$01
cp_line:lda (ptr1),y
        sta (ptr2),y
        iny
        cpy #$27
        bne cp_line
        dex
        cpx ypos
        beq in_end

        lda ptr1
        sec
        sbc #$28
        sta ptr1
        lda ptr1+1
        sbc #$00
        sta ptr1+1

        lda ptr2
        sec
        sbc #$28
        sta ptr2
        lda ptr2+1
        sbc #$00
        sta ptr2+1

        jmp inserts
in_end: lda #$20
        dey
        sta (ptr2),y
        cpy #$01
        bne in_end
        rts



convertchar:
        cmp #$40
        bcc not_letter
        bpl lower_case
        sbc #$40
lower_case:        
        sbc #$40
not_letter:
        rts


border: 
        // Draw border on screen
        lda #$40
        ldx #$27
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
        ldy #$27
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
        



scrptr: pha
        tya
        pha
        asl
        tay
        lda screen,y
        sta ptr1
        lda screen+1,y
        sta ptr1+1
        pla
        tay
        pla
        rts



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

st_print_hex:
        // prints a hexadecimal value (byte) to the current st-position
        pha
        lsr
        lsr
        lsr
        lsr
        jsr nibble
        inx
        pla
nibble: and #$0f
        ora #$30        // add digit "0"
        cmp #$3a        // check if it is a digit (0-9)
        bcc hx_echo
        adc #$06        // if not - add 7 (6+1c)
hx_echo:jsr st_print
        rts

st_print_dec:
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


print:
        // prints the character in a at xpos of current line
        ldy xpos
        sta (cur_line),y
        rts

clearline:
        // clears the current line - overwrites with spaces
        ldy #$01
        lda #$20
cl_loop:sta (cur_line),y
        iny
        cpy #$27
        bne cl_loop
        rts

setcurline:
        // set current line - use ypos to calculate the address of the current line on screen
        // store in cur_line
        pha
        tya
        pha
        lda ypos
        asl
        tay
        lda screen,y
        sta cur_line
        lda screen+1,y
        sta cur_line+1
        pla
        tay
        pla
        rts

screen: .word $0400, $0428, $0450, $0478, $04A0, $04C8, $04F0 
        .word $0518, $0540, $0568, $0590, $05B8, $05E0
        .word $0608, $0630, $0658, $0680, $06A8, $06D0, $06F8
        .word $0720, $0748, $0770, $0798, $07C0
