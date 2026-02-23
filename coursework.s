.data

Map_W: .word 12	# Map width (including null terminator)
Map_H: .word 8	# Map height

# @ = reward, P = player, # = walls
map:
	.asciiz "############\n#          #\n#     P    #\n#          #\n#     @    #\n#          #\n#          #\n############\n"
score: 		.asciiz "Score: "
game_over: 	.asciiz "Game Over\n"
new_line:	.asciiz "\n"
int_buffer:	.space 12   # enough for 32-bit number + null
    
x_player: .word 2	# initial row location of the player
y_player: .word 6	# initial column location of the player

new_row: .word 0	# initializing players new row
new_col: .word 0	# initializing players new column

key_buffer: .word 0	# initializing the variable

.text

# -------------------------
# Main
main:
	# Enables keyboard interrupt bit
	li $t0, 0x00000002
	sw $t0, 0xffff0000
	
	# Enables global interrupts
	mfc0 $t0, $12
	ori  $t0, $t0, 1
	mtc0 $t0, $12
	
	li $sp,0x7fffeffc	# Initialize stack
	li $s7, 0		# points = 0

	# Print score
	jal print_score
	
	# Move map 2 lines down
	li $t0,0
	li $t1,2
print_blank:
	la $a0, new_line
	jal print
	addi $t0,$t0,1
	blt $t0,$t1,print_blank
    
	# Print map
	jal print_map

	# Infinite loop
game_loop:
	jal movement
	j game_loop		# -> keeps the program running
	
# -------------------------
# Printing Function
# $a0 = pointer to null-terminated string
print:
	addi $sp, $sp, -8
	sw $ra,4($sp)
	sw $s0,0($sp)

	move $s0,$a0

print_loop:
	lbu $t0,0($s0)		# load byte
	beqz $t0, print_end	# stop at null terminator

	# Polling MMIO transmitter
	li $t1,0xffff0008
wait_ready:
	lw $t2,0($t1)
	andi $t2,$t2,1
	beqz $t2, wait_ready

	# Send char
	li $t1,0xffff000c
	sb $t0,0($t1)

	addi $s0,$s0,1
	j print_loop

print_end:
	lw $s0,0($sp)
	lw $ra,4($sp)
	addi $sp,$sp,8
	jr $ra

# -------------------------
# Print map
print_map:
	la $a0,map
	jal print
	jr $ra

# -------------------------
# Print score
print_score:
	addi $sp,$sp,-4
	sw $ra,0($sp)

	# Print "Score: "
	la $a0,score
	jal print

	# Convert integer score to string
	move $a0,$s7
	jal int_to_string
	move $a0,$v0
	jal print
	
	# New line
	la $a0, new_line
	jal print

	lw $ra,0($sp)
	addi $sp,$sp,4
	jr $ra

# -------------------------
# Convert integer to ASCII string
# $a0 = integer
# $v0 = pointer to string (converted integer)
int_to_string:
	addi $sp,$sp,-8
	sw $ra,4($sp)

	la $t0,int_buffer
	addi $t0,$t0,11
	sb $zero,0($t0)		# null terminator

	move $t1,$a0
	li $t2,10
	beqz $t1,zero_case

convert_loop:
	div $t1,$t2
	mfhi $t3	# remainder
	mflo $t1	# quotient

	addi $t3,$t3,'0'
	addi $t0,$t0,-1
	sb $t3,0($t0)

	bnez $t1,convert_loop
	j done

zero_case:
	addi $t0,$t0,-1
	li $t3,'0'
	sb $t3,0($t0)

done:
	move $v0,$t0

	lw $ra,4($sp)
	addi $sp,$sp,8
	jr $ra
	
# -------------------------
# Update score
update_score:
	addi $s7, $s7, 5	# adding points
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	jal print_score
	lw $ra,0($sp)
	addi $sp, $sp, 4
	jr $ra

# -------------------------
# Keyboard interrupt
.ktext 0x80000180		# places the following code in kernel text memory
 
kb_interrupt:
	li $k0, 0xffff0004	# Keyboard Data Register
	lb $k1, 0($k0)		# read ASCII key pressed
	

    # Store key in input buffer
	la $k0, key_buffer
	sb $k1, 0($k0)
	
	eret
    
    .text
# -------------------------
# Using player's input
movement:		
	# Reads from buffer
	la $t9, key_buffer
	lb $t0, 0($t9)
	beqz $t0, end_move
	
	beq $t0, 119, up	# input 'w'
	beq $t0, 115, down	# input 's'
	beq $t0, 97, left	# input 'a'
	beq $t0, 100, right	# input 'd'
	j end_move
	

up:
	lw $t0, x_player
	addi $t0, $t0, -1
	sw $t0, new_row
	
	lw $t1, y_player
	sw $t1, new_col
	j update_player
	
down:
	lw $t0, x_player
	addi $t0, $t0, +1
	sw $t0, new_row
	
	lw $t1, y_player
	sw $t1, new_col
	j update_player

left:
	lw $t0, x_player
	sw $t0, new_row
	
	lw $t1, y_player
	addi $t1, $t1, -1
	sw $t1, new_col
	j update_player

right:
	lw $t0, x_player
	sw $t0, new_row
	
	lw $t1, y_player
	addi $t1, $t1, +1
	sw $t1, new_col
	j update_player

end_move:
	la $t9, key_buffer
	sb $zero, 0($t9)
	jr $ra
# -------------------------
# Updating the player
# player offset = row * width + column

update_player:

	addi $sp, $sp, -8
	sw $s0, 4($sp)
	sw $s1, 0($sp)
	
	la $s1, map		# $s1 = new map
	lw $t0, new_row
	lw $t1, new_col
	lw $t4, Map_W

	# New offset
	mul $t2, $t0, $t4 	# row * Map_W
	add $t2, $t2, $t0 	# + row (for \n)
	add $t2, $t2, $t1 	# + col
	add $s1, $s1, $t2 	# new address
	lbu $t5, 0($s1)		# load new position
	
	# Collision check
	li $t3, '#'
	beq $t5, $t3, no_move
	
	# Reward check
	li $t3, '@'
	bne $t5, $t3, clear_old
	jal update_score	# add points
	
	# Reload registers needed for calculations after the update-socre function
	lw $t4, Map_W
	la $s0, map		# $s0 = the old map
	lw $t0, new_row
	lw $t1, new_col
	mul $t2, $t0, $t4
	add $t2, $t2, $t0
	add $t2, $t2, $t1
	add $s0, $s0, $t2    # Re-calculate target address
	
# Clear old position
clear_old:
	lw $t6, x_player
	lw $t7, y_player
	la $s0, map
	
	mul $t2, $t6, $t4 	# row * Map_W
	add $t2, $t2, $t6 	# + row (for \n)
	add $t2, $t2, $t7 	# + col
	add $s0, $s0, $t2
	li $t3, ' ' 		# clear old 'P'
	sb $t3, 0($s0)
	
	# Update players position
	sw $t0, x_player
	sw $t1, y_player
    
    # Putting P into the new location	
	li $t3, 'P'
	sb $t3, 0($s1)
    
	# Clear key buffer
	la $t9, key_buffer
	sb $zero, 0($t9)
	jal print_map
	lw $s0, 0($sp)		# restore $s0
	addi $sp, $sp, 4
	jr $ra
	
no_move:
	# Clear key buffer (move failed, but key processed)
	la $t9, key_buffer
	sb $zero, 0($t9)
	lw $s0, 0($sp)		# restore $s0
	addi $sp, $sp, 4
	jr $ra