.data

MAP_W: .word 12	# Map width
MAP_H: .word 8	# Map hight

# @ = reward, P = player, # = walls
map:
	.asciiz "############\n#          #\n#    P     #\n#          #\n#         @#\n#          #\n#          #\n############\n"
    
score: 		.asciiz "Score: \n"
game_over: 	.asciiz "Game Over \n"
new_line:	.asciiz "\n"
    
x_player: .word 5	# inital row location of the player
y_player: .word 2	# initial column location of the player

# ----------------------------------
.text

# Starting Point -------------------

main:
	li $sp,0x7fffeffc	# Initialize stack
	
	li $t7, 0		# points = 0
	
# Print score
	jal print_score
	
# Move map 2 lines down
	li $t0,0
	li $t1,2
	
print_blank:
	la $a0, new_line            # newline
	jal print
	addi $t0,$t0,1
	blt $t0,$t1,print_blank
    
# Print map
	jal print_map         # Go print map

# Infinite
loop:
    j loop			# Infinite loop -> keeps the program running
    

# Printing Function ----------------

# $a0 = pointer to null-terminated string
print:
	addi $sp, $sp, -8	# Allocate 8 bytes on stack
	sw   $ra, 4($sp)	# Save return address
	sw   $s0, 0($sp)	# Save $s0 (we’ll use it as pointer)

	move $s0, $a0		# $s0 = pointer to string

print_loop:
	lbu  $t0, 0($s0)		# Load byte from string
	beqz $t0, print_end		# Stop at null terminator
    
wait_ready:
	li $t1, 0xffff0008	# Transmitter Control Register
	lw $t2,0($t1)
	andi $t2,$t2,1		# Check ready bit
	beqz $t2, wait_ready

	li $t1,0xffff000c	# Transmitter Data Register
	sw $t0,0($t1)		# Writes char

    addi $s0,$s0,1       # move pointer
    j print_loop
   
print_end:
	lw   $s0, 0($sp)	# Restore $s0
	lw   $ra, 4($sp)	# Restore return address
	addi $sp, $sp, 8	# Restore stack
	jr   $ra		# Return
	
	
# Printing map ---------------------
print_map:
    	
	la $a0,map		# Loads address of the map into $s0
	jal print		# Calling general print function
	
	jr $ra			# Return
	
# Printing score and game over -----
print_score:
	addi $sp, $sp, -4	# Allocating memmory	
	sw $ra,0($sp)		# Saving return address

	la $a0,score		# $a0 = address of score string
	jal print		# Call your general print function

	lw $ra,0($sp)		# Restoring return address
	addi $sp,$sp,4		# Restor allocated memory
	jr $ra			# Jump back to main
	
	
