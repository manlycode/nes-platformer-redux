.struct Point
  x_val .byte
  y_val .byte
.endstruct

.macro Point_init point, newX, newY
  lda newX
  sta point+Point::x_val
  lda newY
  sta point+Point::y_val
.endmacro

.macro Point_set_x point, newVal
  lda newVal
  sta point+Point::x_val
.endmacro

.macro Point_apply_vector point, vector
  clv
  clc
  lda point+Point::x_val
  adc vector+Point::x_val
  sta point+Point::x_val

  clv
  clc
  lda point+Point::y_val
  adc vector+Point::y_val
  sta point+Point::y_val
.endmacro

