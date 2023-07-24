#importonce 

*=$e0 virtual
.zp {
        xpos:           .byte 0 // e0
        ypos:           .byte 0 // e1
        ptr1:           .word 0 // e2-e3
        ptr2:           .word 0 // e4-e5
        ptr3:           .word 0 // e6-e7
        ptr_tmp:        .word 0 // e8-e9
        st_cursor:      .word 0 // ea-eb
        scr_cursor:     .word 0 // ec-ed
        scr_line:       .word 0 // ee-ef
        mem_cursor:     .word 0 // f0-1
        mem_line:       .word 0 // f2-3
        lines_total:    .byte 0 // f4
        KEYTAB:         .word 0 // CANNOT BE USED!!! f5 and f6 are used by the KERNALs SCNKEY routine
        lines_offset:   .byte 0 // f7
        color_mode:     .byte 0 // f8
        color_start:    .byte 0 // f9
        color_end:      .byte 0 // fa
        insert_line_y:  .byte 0 // fb   - remembers the last line used for inserts (so it can shift to the next line)
}