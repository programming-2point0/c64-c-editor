BasicUpstart2(Entry)

*=$2000 "Graphics"
        .import c64 "c-font.font"

#import "zeropage.asm"
#import "constants.asm"

       
        * = $080d "Program"
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
        jsr drawborder

        // reset screen-colors
        jsr resetcolors

        // initialize memory
        jsr mem_init
        lda #$01
        sta lines_total
        lda #$00
        sta lines_offset

        // show memory on screen
        jsr mem_show

        // initialize cursor
        jsr cursor_init
        jsr cursor_calculate
        jsr cursor_update      

getkey: jsr GETIN
        cmp #$00
        beq getkey
/*
        ldx #$01
        ldy #$00
        jsr st_setpos
        pha
        jsr st_print_hex        // only for debugging
        pla
*/
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
        jsr color_line
nxtchar:jsr cursor_update
        jmp getkey

key_f1: jmp key_f1_long
key_f2: jmp key_f2_long
key_f3: jmp key_f3_long
key_f4: jmp key_f4_long
key_f5: jmp key_f5_long

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
        jsr return
        jmp nxtchar

key_delete:
        jsr delete
        jmp nxtchar

key_insert:
        jsr insert
        jmp nxtchar

insert:
        jsr EDIT.insert
        jsr color_line
        jsr mem_show
        rts

delete:
        jsr EDIT.delete
        // Cursor might have moved above screen, 
        // if so, scroll before recoloring
        lda ypos
        cmp lines_offset
        bne !no_scroll+
        // scroll three lines to help user understand that we scroll
        jsr scroll_screen_down
        jsr scroll_screen_down
        jsr scroll_screen_down
        
!no_scroll:        
        jsr cursor_calculate
        jsr color_line
        jsr mem_show
        rts

return:
        jsr EDIT.newline
        // Cursor might have moved below screen,
        // if so, scroll up before recoloring
        lda ypos
        sec
        sbc lines_offset
        cmp #$18
        bcc !no_scroll+

        jsr scroll_screen_up

!no_scroll:        
        jsr cursor_calculate
        jsr color_line
        jsr mem_show
        rts

key_f1_long:
        jmp nxtchar

key_f2_long:
        jmp nxtchar

key_f3_long:
        jmp nxtchar

key_f4_long:
        jmp nxtchar

key_f5_long:
        jmp nxtchar

drawborder: {
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

resetcolors:
        lda #$0e
        ldx #250
!:      sta $d7ff,x
        sta $d8f9,x
        sta $d9f3,x
        sta $daed,x
        dex
        bne !-
        rts


#import "cursor.asm"
#import "printing.asm"
#import "scrolling.asm"
#import "colors.asm"
#import "edit.asm"
#import "status.asm"
#import "memory.asm"
#import "screen.asm"