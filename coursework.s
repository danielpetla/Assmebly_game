.data

# columns =  13 (12 + null terminator)
# rows =  8	

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

key_buffer: .space 1	# initializing the variable

debug_char: .byte 0,0

.text

# -------------------------
# Main
main:
	# Enable keyboard interrupt level + global interrupt
	mfc0 $t0, $12
	ori  $t0, $t0, 0x00000101   # IE=1 and IM0=1 (enable hardware interrupt line)
	mtc0 $t0, $12
	
	# Enables global interrupts
	mfc0 $t0, $12
	ori  $t0, $t0, 1
	mtc0 $t0, $12
	
	li $sp,0x7fffeffc	# Initialize stack
	li $s7, 0		# points = 0

	# Print score
	jal print_score
	
	# Move map 2 lines down
	li $s5,0
	li $s6,2
print_blank:
	la $a0, new_line
	jal print
	addi $s5,$s5,1
	blt $s5,$s6,print_blank
    
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
 
__kernel_entry_point:
	li $k0, 0xffff0004	# Keyboard Data Register
	lb $k1, 0($k0)		# read ASCII key pressed
	

	# Store key in input buffer
	la $k0, key_buffer
	sb $k1, 0($k0)
	
	# DEBUG echo (optional)
    	li $k0, 0xffff000c
    	sb $k1, 0($k0)
	
	# clear interrupt by reading control register
    	li $k0, 0xffff0000
    	lw $k1, 0($k0)		# read receiver control to clear interrupt
	
	eret
    
    .text
# -------------------------
# Using player's input
movement:		
	# Reads from buffer
	la $t9, key_buffer
	lb $t0, 0($t9)
	beqz $t0, end_move
	
	# --- DEBUG ECHO (temporary) ---
    	addi $sp,$sp,-4
    	sw $ra,0($sp)

    	la $a0, debug_char
    	sb $t0, debug_char
    	jal print

    	lw $ra,0($sp)
    	addi $sp,$sp,4
    	# -------------------------------
	
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

	addi $sp, $sp, -24
	sw $ra, 20($sp)
	sw $s0, 16($sp)
	sw $s1, 12($sp)
	sw $s2, 8($sp)
	sw $s3, 4($sp)
	sw $s4, 0($sp)
	
	la $s0, map		# $s0 = old map
	lw $s2, new_row		# t1
	lw $s3, new_col		# t0
	li $s4, 13		# t4

	# New offset
	mul $t2, $s2, $s4 	# row * Map_W
	add $t2, $t2, $s3 	# + col
	add $s1, $s0, $t2 	# new address -> new map
	
	lbu $t5, 0($s1)		# load new position
	
	# Collision check
	li $t3, '#'
	beq $t5, $t3, exit_update
	
	# Reward check
	li $t3, '@'
	bne $t5, $t3, clear_old
	jal update_score	# add points
	
# Clear old position
clear_old:
	lw $t6, x_player
	lw $t7, y_player
	la $s0, map
	
	mul $t2, $t6, $s4 	# row_old * Map_W
	add $t2, $t2, $t7 	# + col_old
	la $s0, map
	add $s0, $s0, $t2
	li $t3, ' ' 		# clear old 'P'
	sb $t3, 0($s0)
	
	# Update players position
	sw $s2, x_player
	sw $s3, y_player
    
	# Putting P into the new location	
	li $t3, 'P'
	sb $t3, 0($s1)
	
	# Reprint
	jal print_map
	
	
exit_update:
	# Clear key buffer (move failed, but key processed)
	la $t9, key_buffer
	sb $zero, 0($t9)
	
	lw $s4, 0($sp)
	lw $s3, 4($sp)
	lw $s2, 8($sp)
	lw $s1, 12($sp)
	lw $s0, 16($sp)
	lw $ra, 20($sp)
	addi $sp, $sp, 24
	jr $ra
