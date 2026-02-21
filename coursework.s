.data

MAP_W: .word 12	# Map width
MAP_H: .word 8	# Map hight

# 10 = new line, @ = reward, P = player, # = walls
map:
	.byte '#','#','#','#','#','#','#','#','#','#','#','#',10
	.byte '#',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','#',10
	.byte '#',' ',' ',' ',' ','P',' ',' ',' ',' ',' ','#',10
	.byte '#',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','#',10
	.byte '#',' ',' ',' ',' ',' ',' ',' ',' ',' ','@','#',10
	.byte '#',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','#',10
	.byte '#',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','#',10
	.byte '#','#','#','#','#','#','#','#','#','#','#','#',10,0
    
score: 		.asciiz "Score: 0\n"
game_over: 	.asciiz "Game Over 0\n"
    
x_player: .word 5	# inital row location of the player
y_player: .word 2	# initial column location of the player

# ----------------------------------
.text

# Starting Point -------------------

main:
	li $sp,0x7fffeffc	# Address of the stock pointer top of the memmory
	
	li $t7, 0		# points = 0
	
	jal print_score		# Go to print score
	
	# Move map 2 lines down
	li $t0,0
	li $t1,2

print_blank:
	li $a0,10            # newline
	jal print
	addi $t0,$t0,1
	blt $t0,$t1,print_blank
    
	jal print_map         # Go print map
loop:
    j loop			# Infinite loop -> keeps the program running
    

# Printing -------------------------
print:
	addi $sp, $sp, -8	# Allocate 8 bytes on stack
	sw   $ra, 4($sp)	# Save return address
	sw   $s0, 0($sp)	# Save $s0 (we’ll use it as pointer)

	move $s0, $a0		# $s0 = pointer to string

print_loop:
	lbu  $t0, 0($s0)		# Load byte from string
	beqz $t0, print_end		# Stop at null terminator
    
MMIO:
	li   $t1, 0xffff000c	# MMIO Transmitter Data Register
	sw   $t0, 0($t1)	# Write character

	addi $s0, $s0, 1	# Move pointer to next char
	j print_loop		# Repeat for next character

print_end:
	lw   $s0, 0($sp)	# Restore $s0
	lw   $ra, 4($sp)	# Restore return address
	addi $sp, $sp, 8	# Restore stack
	jr   $ra		# Return
	
	
# Printing map ---------------------

# x = $t0
# y = $t1
print_map:
	addi $sp,$sp,-16	# Allocating 16 bytes of the stack (negative because it grows dowonward)
	sw $ra,12($sp)		# Saves the return address back to main
	sw $s0,8($sp)		# Base address of the map
	sw $s1,4($sp)		# Map width
	sw $s2,0($sp)		# Reserves for temporary variables
    	
	la $s0,map		# Loads address of the map into $s0
	li $s1,13		# Sets map width (including the new line char '10')
	li $t0,0		# Sets y to start at x = 0

line_loop:
	li $t1,0		# The y for each new row (always rests to 0 at the start of a new row)

char_loop:
	mul $t2,$t0,$s1		# Multiplies x * width -> starts the offset for the row.
	add $t2,$t2,$t1		# Adds offset to the column (t2 points to the current char)
	add $t2,$s0,$t2 	# Final memmory address of the char
	lbu $t3,0($t2)		# The actual ASCII char
	beqz $t3,end_print	# if byte = 0 -> end function


# Wating for input -----------------
	li $t4,0xffff0008	# Address of transmitter control register
	
wait_ready:
	lw $t5,0($t4)		# Read control register	
	andi $t5,$t5,1		# Check for a ready bit (1 = ready)
	beqz $t5,wait_ready	# Loop until ready

	li $t4,0xffff000c	# Register that will receive the char
	sw $t3,0($t4)		# Write char at the terminal
	addi $t1,$t1,1		# Move to the next column
	blt $t1,$s1,char_loop	# Loop until column < width

	addi $t0,$t0,1		# Move to the next row
	blt $t0,8,line_loop	# Loop until row < 8 (nuber of rows)

end_print:
	lw $s2,0($sp)		# Restores the temp variables 
	lw $s1,4($sp)		# Restore map width
	lw $s0,8($sp)		# Restore the base address of the map
	lw $ra,12($sp)		# Restore return address
	addi $sp,$sp,16		# Deallocate stack space
	jr $ra			# Return to caller
	
# Printing score and game --------------------
print_score:
	addi $sp, $sp, -8	# Allocating memmory	
	sw $ra,4($sp)		# Saving return address

	la $a0,score		# $a0 = address of score string
	jal print		# Call your general print function

	lw $ra,4($sp)		# Restoring return address
	addi $sp,$sp,8		# Restor allocated memory
	jr $ra			# Jump back to main
	
	
