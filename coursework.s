.data

MAP_W: .word 12	# Map width
MAP_H: .word 8	# Map height

# @ = reward, P = player, # = walls
map:
	.asciiz "############\n#          #\n#    P     #\n#          #\n#         @#\n#          #\n#          #\n############\n"
    
score: 		.asciiz "Score: "
game_over: 	.asciiz "Game Over\n"
new_line:	.asciiz "\n"
int_buffer:	.space 12   # enough for 32-bit number + null
    
x_player: .word 5	# initial row location of the player
y_player: .word 2	# initial column location of the player

.text

# -------------------------
# Main
main:
	li $sp,0x7fffeffc	# Initialize stack
	li $t7, 0		# points = 0

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
loop:
	j loop	# -> keeps the program running

# -------------------------
# Printing Function (polling)
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
	move $a0,$t7
	jal int_to_string
	move $a0,$v0
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
	sb $zero,0($t0)  # null terminator

	move $t1,$a0
	li $t2,10
	beqz $t1,zero_case

convert_loop:
	div $t1,$t2
	mfhi $t3       # remainder
	mflo $t1       # quotient

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
	addi $t7, $t7, 5	# adding points
	jal print_score
	