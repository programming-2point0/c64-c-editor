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
        rts

scroll_screen_down:
        lda lines_offset
        cmp #$00
        beq no_scroll
        dec lines_offset
        jsr mem_show
no_scroll:        
        rts