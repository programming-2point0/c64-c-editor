#importonce 
#import "zeropage.asm"
#import "constants.asm"
#import "cursor.asm"

// ----------------------
//  PRINTING
// ----------------------

printchar: {
        jsr convertchar

        // prints the character in A - on screen and in memory
        ldy #$00
        sta (scr_cursor),y
        sta (mem_cursor),y

        // move cursor to next position
        jsr cursor_right
        // TODO: Check if cursor is on new line - if so, then insert line
   
        rts
}

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