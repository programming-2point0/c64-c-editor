#importonce 
#import "zeropage.asm"
#import "constants.asm"

#import "memory.asm"
// --------------------
//  SCROLLING
// --------------------

scroll_screen_up:
        // scroll the visible screen, just by changing the lines-offset and re-copying
        inc lines_offset
        jsr mem_show
        lda #$04
        sta scr_line+1
        lda #$28
        sta scr_line
        jsr copy_colors_one_line_up
        jsr color_last_line
        rts

scroll_screen_down:
        lda lines_offset
        cmp #$00
        beq no_scroll
        dec lines_offset
        jsr mem_show
        lda #$04
        sta scr_line+1
        lda #$28
        sta scr_line
        jsr copy_colors_one_line_down
        jsr color_first_line
no_scroll:        
        rts