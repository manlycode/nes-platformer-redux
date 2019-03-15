.struct Point
  x_pos .byte
  y_pos .byte
.endstruct

.macro Point_init point, newX, newY
  clc
  lda newX
  sta point+Point::x_pos
  lda newY
  sta point+Point::y_pos
.endmacro

.macro Point_move_right point, delta
  clc
  clv
  lda point+Point::x_pos
  adc delta
  sta point+Point::x_pos
.endmacro

.macro Point_move_left point, delta
  clc
  clv
  lda point+Point::x_pos
  sbc delta
  sta point+Point::x_pos
.endmacro

.macro Point_move_up point, delta
  clc
  clv
  lda point+Point::y_pos
  sbc delta
  sta point+Point::y_pos
.endmacro

.macro Point_move_down point, delta
  clc
  lda point+Point::y_pos
  adc delta
  sta point+Point::y_pos
.endmacro
