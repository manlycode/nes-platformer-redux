.macro load_pointer pointer_label, var_label
        lda #<pointer_label
        sta var_label
        lda #>pointer_label
        sta var_label+1
.endmacro

.macro load_pointer_from_table table_label, idx, destination
        ldy #(idx*2)
        lda table_label, y
        sta destination

        iny
        lda table_label, y
        sta destination+1
.endmacro

.macro inc_pointer addr
.proc
        clc
        inc addr
        bne :+
        inc addr+1
Skip:
.endproc
.endmacro

.macro inc_pointer_by_y var_label
        clc
        clv
        sty temp8
        lda var_label
        adc temp8
        sta var_label
        bcc :+
        inc var_label+1
.endmacro
