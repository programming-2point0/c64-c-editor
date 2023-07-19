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
        jsr make_crsr

        // draw border
        jsr border

        // initialize memory

        // show memory on screen

        // initialize cursor
        jsr crsr_init
        
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
        beq crsr_home_line
        cmp #$93
        beq crsr_home
        cmp #$91
        beq crsr_up
        cmp #$11
        beq crsr_down
        cmp #$9d
        beq crsr_left
        cmp #$1d
        beq crsr_right

        // todo: only if printable char
        jsr printchar
        

show_crsr:
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

        lda xpos
        ldx #$2f
        sec
ct100s: inx
        sbc #100
        bcs ct100s
        adc #100
        stx $0410
        ldx #$2f
        sec
ct10s:  inx
        sbc #10
        bcs ct10s
        adc #$3a
        stx $0411

        tax
        stx $0412

        jmp wait

crsr_init:
        lda #$01
        sta xpos
        sta ypos
        rts

crsr_home:
        lda #$01
        sta ypos
crsr_home_line:
        lda #$01
        sta xpos
        jmp show_crsr
crsr_up:
        dec ypos
        bne show_crsr
        lda #$01
        sta ypos
        jmp show_crsr

crsr_down:
        inc ypos
        // TODO: Handle scroll
        jmp show_crsr
crsr_left:
        dec xpos
        bne show_crsr
        lda #$01
        cmp ypos
        beq stay
        lda #$26
stay:   sta xpos
        jmp crsr_up
crsr_right:
        inc xpos
        lda xpos
        cmp #$27
        bne show_crsr
        lda #$01
        sta xpos
        jmp crsr_down

// NOTO: This should be part of the font-file ... not code here
make_crsr:
        ldx #$00
        txa
clr_crsr:
        sta $3800,x
        inx
        cpx #$40
        bne clr_crsr

        lda #$ff
      //  sta $3812
        sta $3815

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
