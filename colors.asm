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

color_line: {
        // colorizes the current line, according to syntax highlighting
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
