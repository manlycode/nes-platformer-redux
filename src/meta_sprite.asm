.struct MSprite
	status .byte
	pos .tag Point
	vector .tag Point
	frame_table .addr
.endstruct

MS_TILE_SIZE = 8
MS_STATUS_RIGHT = %00000001
MS_STATUS_UP		= %00000010


.macro MSprite_init sprite, fr_table, xPos, yPos
	MSprite_point_right sprite
	Point_init sprite+MSprite::pos, xPos, yPos
	Point_init sprite+MSprite::vector, #0, #0

	lda #<fr_table
	sta sprite+MSprite::frame_table
	lda #>fr_table
	sta sprite+MSprite::frame_table+1
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
	Point_set_x sprite+MSprite::vector, newVec
.endmacro

.macro MSprite_apply_vector sprite
	Point_apply_vector sprite+MSprite::pos, sprite+MSprite::vector
.endmacro
