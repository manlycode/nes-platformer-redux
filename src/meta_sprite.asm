.struct MSprite
	status .byte
	pos .tag Point
	x_vector .byte
	y_vector .byte
	frame_addr .addr
.endstruct

MS_TILE_SIZE = 8
MS_STATUS_RIGHT = %00000001
MS_STATUS_UP		= %00000010


.macro MSprite_init sprite, frame, xPos, yPos
	MSprite_point_right sprite
	Point_init sprite+MSprite::pos, xPos, yPos

	lda #00
	sta sprite+MSprite::x_vector
	sta sprite+MSprite::y_vector
.endmacro

.macro MSprite_point_right sprite
	lda #MS_STATUS_RIGHT
	ora sprite+MSprite::status		; Clear MS_STATUS_RIGHT bit
	sta sprite+MSprite::status
.endmacro

.macro MSprite_point_left sprite
	lda #($FF^MS_STATUS_RIGHT)
	and sprite+MSprite::status		; Clear MS_STATUS_RIGHT bit
	sta sprite+MSprite::status
.endmacro

.macro MSprite_set_up sprite
	lda #MS_STATUS_UP
	ora sprite+MSprite::status		; Clear MS_STATUS_RIGHT bit
	sta sprite+MSprite::status
.endmacro

.macro MSprite_set_down sprite
	lda #($FF^MS_STATUS_UP)
	and sprite+MSprite::status		; Clear MS_STATUS_RIGHT bit
	sta sprite+MSprite::status
.endmacro

.macro MSprite_set_x_vector sprite, newVec
	lda #newVec
	sta sprite+MSprite::x_vector
.endmacro

.macro MSprite_apply_vector sprite
	lda sprite+MSprite::x_vector
	beq :++
	lda #MS_STATUS_RIGHT
	bit sprite+MSprite::status
	bne :+
	Point_move_left sprite+MSprite::pos, sprite+MSprite::x_vector
: Point_move_right sprite+MSprite::pos, sprite+MSprite::x_vector
.endmacro
