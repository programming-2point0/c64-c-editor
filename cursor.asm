#importonce 
#import "zeropage.asm"
#import "constants.asm"

#import "screen.asm"
#import "memory.asm"
#import "edit.asm"
#import "scrolling.asm"
#import "status.asm"

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
        bne home_xpos
        clc
        adc lines_offset
        cmp ypos
        bne home_ypos
        // scroll to top of memory
        lda #$00
        sta lines_offset
        jsr mem_show

home_ypos:
        lda #$01
        clc
        adc lines_offset
        sta ypos

home_xpos:
        lda #$01
        sta xpos
        jmp cursor_calculate
}

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
        // move cursor up - if at top of memory, don't move
        lda ypos
        cmp #$01
        beq cursor_stay

        dec ypos

        // if cursor has moved up before offset, scroll_screen_down
        lda ypos
        sec
        sbc lines_offset
        cmp #$00
        bne cursor_calculate
        jsr scroll_screen_down

        jmp cursor_calculate

cursor_down:
        // move cursor down - until ypos meets lines_total
        lda ypos
        cmp lines_total
        beq cursor_stay

        inc ypos            

        // if cursor has left screen: scroll_screen_up                
        lda ypos        
        sec
        sbc lines_offset
        cmp #$18
        bne cursor_calculate
        jsr scroll_screen_up
        
        jmp cursor_calculate    // TODO: Maybe eliminate this ... NOTE, while technically not needed here, makes for better structure
cursor_stay:
        rts

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
        // first the line - ignoring xpos, but subtracting possible offset
        lda ypos
        sec
        sbc lines_offset
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

        // TODO: Improve this calculation to multiply rather than run through every Y-value

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
        sec
        sbc lines_offset
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