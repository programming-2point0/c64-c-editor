#importonce 
#import "zeropage.asm"
#import "constants.asm"


// --------------------
//  COLORING
//    - syntax highlighting -
//    WHITE  - keywords, eg void, int, struct, char
//    YELLOW - symbols, eg ()*&[]{}
//    GREEN  - letters (not in keywords)
//    GREY   - numbers

color_screen: {
        // colorizes the visible screen, by calling color_line for each line

        // store original cursor
        lda xpos
        sta $03
        lda ypos
        sta $04

        // set ypos to home = lines_offset+1
        lda #$01
        clc
        adc lines_offset
        sta ypos

        // calculate cursors
        jsr cursor_calculate

        lda #$17        // number of lines to colorize
        sta $02
color_next_line:        
        jsr color_line
        dec $02
        beq done_coloring

        // next line - screen
        lda scr_line
        clc
        adc #LINE_LENGTH+2
        sta scr_line
        lda scr_line+1
        adc #$00
        sta scr_line+1
        // and next line - memory
        lda mem_line
        clc
        adc #LINE_LENGTH
        sta mem_line
        lda mem_line+1
        adc #$00
        sta mem_line+1

        jmp color_next_line

done_coloring:
        // restore cursor
        lda $03
        sta xpos
        lda $04
        sta ypos
        rts

}

color_first_line: {
        // store original cursor
        lda xpos
        sta $03
        lda ypos
        sta $04

        lda #$01
        clc
        adc lines_offset
        sta ypos

        jsr cursor_calculate
        jsr color_line

        // restore cursor
        lda $03
        sta xpos
        lda $04
        sta ypos
        rts
}

color_last_line: {
        // store original cursor
        lda xpos
        sta $03
        lda ypos
        sta $04

        lda #$17
        clc
        adc lines_offset
        sta ypos

        jsr cursor_calculate
        jsr color_line

        // restore cursor
        lda $03
        sta xpos
        lda $04
        sta ypos
        rts
}

color_line: {
        // colorizes the current line, according to syntax highlighting
        // uses scr_line to find color-address
        // uses mem_line to find text
        // uses ptr_tmp to store color-addresses

        lda scr_line    // use the screen-line, as the mem-line might be offset
        clc
        adc #$01
        sta ptr_tmp
        lda scr_line+1
        adc #$d4
        sta ptr_tmp+1

        ldy #$00
        sty color_mode
        /*
        colorization uses a simple state-machine.
        State is stored in color_mode
        00 is char_mode (the initial mode)
        01 is letter_mode

        in char_mode, symbols and numbers are colored.
        if a letter is seen, the mode switches to letter_mode until a non-letter is seen
        when letter_mode ends, the letters, the word, is compared to a list of keywords, and 
        if it matches any of them, the word is colored WHITE - otherwise GREEN.

        the color_start and color_end variables are used to store the first and last index of the word
        
        */
colorize:        
        lda (mem_line),y        // check character
        ldx color_mode
        cpx #$00                // mode: char
        beq color_charmode
    
    // TODO: handle string-mode as well

color_lettermode:           
        // TODO: Also accept numbers when in letter-mode - a number can't start a lettermode, but it also can't stop it!
        
        // check if actually letter
        cmp #$1b
        bmi accept_letter
        cmp #$5a
        bpl letter_mode_end
        cmp #$40
        bmi letter_mode_end
accept_letter:
        // keep accepting letters - don't do anything with them yet
        jmp color_next_char
        
color_charmode:
        cmp #$1b
        bmi letter_mode_start
        cmp #$30
        bmi symbol
        cmp #$3a
        bmi number
        cmp #$40
        bmi symbol
        cmp #$5b
        bmi letter_mode_start

        // default to yellow
        lda #COLOR_YELLOW
color_char:
        sta (ptr_tmp),y
color_next_char:        
        iny
        cpy #LINE_LENGTH
        bne colorize                
        rts

symbol: lda #COLOR_YELLOW
        jmp color_char
number: lda #COLOR_GREY
        jmp color_char

letter_mode_start:
        // remember the start-index of word in letter-mode
        sty color_start

        // shift to letter-mode
        ldx #$01
        stx color_mode
        jmp color_lettermode

letter_mode_end:
        pha             // non-letter is in A - store it for color_charmode
        sty color_end   // store the end-index of word in letter-mode
        
        // go through each color_keyword, until one matches
        ldx #$ff
try_next_keyword:
        inx
        lda color_keywords,x    // check if next keyword is zero
        cmp #$00                // then:
        beq last_keyword_checked// we have checked all available keywords
        ldy color_start         // start looking at word from index
keyword_check:        
        lda color_keywords,x
        cmp #$00                // if keyword ends, we might be in luck
        beq keyword_ended
        cmp (mem_line),y        // if word doesn't match keyword
        bne get_next_keyword    // check the next keyword
        iny
        inx
        jmp keyword_check       // keep checking this keyword
get_next_keyword:
        // there was a mismatch BEFORE the keyword has ended
        // so find the next keyword (right after a zero)
        lda #$00
!:      cmp color_keywords,x
        beq try_next_keyword
        inx
        jmp !-

keyword_ended:
        // if the keyword has ended, and we have reached the end of the word
        cpy color_end 
        bne last_keyword_checked
        lda #COLOR_WHITE                // then it is a keyword, and should be colored white
        jmp colorize_word

        // if last keyword has been checked and no match was found
last_keyword_checked:
        lda #COLOR_GREEN        // mark text as normal text

colorize_word:
        // color every letter we have looked at in the letter_mode
        ldy color_start
 !:     sta (ptr_tmp),y
        iny
        cpy color_end                 
        bne !-

        // set mode back to char mode
        lda #$00
        sta color_mode

        pla             // get non-letter that ended letter mode, and show that as a char
        jmp color_charmode

color_keywords:
        .encoding "screencode_mixed"
        .text "int"
        .byte 0
        .text "void"
        .byte 0
        .text "char" 
        .byte 0
        .text "struct"
        .byte 0
        .text "return"
        .byte 0
        .text "sizeof"
        .byte 0, 0
}

copy_colors_one_line_up:
        // Copy colors from next line (scr_line + LINE_LENGTH+2) until end of screen into this line
        // set destination (ptr3) to current_line (add $d400 to get into color-space)
        lda scr_line
        sta ptr3    
        lda scr_line+1
        clc
        adc #$d4
        sta ptr3+1

        // set start (ptr1) to next line (ptr3 + LINE_LENGTH+2)
        lda ptr3
        clc
        adc #LINE_LENGTH+2
        sta ptr1
        lda ptr3+1
        adc #$00
        sta ptr1+1

        // set end (ptr2) to last line of text
        lda #$db
        sta ptr2+1
        lda #$bf        // skip last line, since that is for the border
        sta ptr2

        jsr mem_copy
        // NB: Now the last line on screen will have wrong colors!
        
        rts
        
        
        


copy_colors_one_line_down:
        // Copy colors from current line (scr_line) until end of screen, to next line (scr_line + LINE_LENGTH)
        // set start (ptr1) to current line (add $d400 to get into color-space)
        lda scr_line
        sta ptr1
        lda scr_line+1
        clc
        adc #$d4
        sta ptr1+1

        // set end (ptr2) to end of secondlast text-line on screen ($db98 is the last textline)
        lda #$db
        sta ptr2+1
        lda #$97        // skip last two lines, since that is for the border
        sta ptr2

        // set destination (ptr3) to next line (ptr1+LINE_LENGTH)
        // first add D4 to base addresses (gives us D8xx from 04xx)
        lda ptr1        
        clc
        adc #LINE_LENGTH+2      // (+2 because we include the border)
        sta ptr3
        lda ptr1+1
        adc #$00
        sta ptr3+1
        
        jsr mem_copy
        rts