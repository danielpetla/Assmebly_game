.data

# columns =  13 (12 + null terminator)
# rows =  8    

# @ = reward, P = player, # = walls
map:
	.asciiz "############\n#          #\n#     P    #\n#          #\n#     @    #\n#          #\n#          #\n############\n"

score:		.asciiz "Score: "
game_over:	.asciiz "Game Over\n"
new_line:	.asciiz "\n"
clear_screen:	.asciiz "\033[3J\033[H\033[2J"

# -------------------------
x_player: .word 2	# initial row location of the player
y_player: .word 6	# initial column location of the player

new_row:  .word 0	# initializing players new row
new_col:  .word 0	# initializing players new column

# -------------------------
int_buffer: .space 12	# enough for 32-bit number + null
key_buffer: .space 1	# initializing the variable
last_key:   .byte 0

.text

# -------------------------
# Main
main:
	li $sp, 0x7ffffffc	# safer / more common value
	li $s7, 0		# points = 0

	jal update_screen
    
	# Enable interrupts
	li $t0, 0xffff0000
	lw $t1, 0($t0)
	ori $t1, $t1, 2
	sw $t1, 0($t0)

	mfc0 $t0, $12
	ori $t0, $t0, 0x00000201
	mtc0 $t0, $12
    
    # Eat the spurious key MARS always sends
	li $t0, 0xffff0004
	lb $t1, 0($t0)

    # Infinite loop
game_loop:
	jal movement
	j game_loop        # -> keeps the program running
    
# -------------------------
# Printing Function
# $a0 = pointer to null-terminated string
print:
	addi $sp, $sp, -8
	sw $ra, 4($sp)
	sw $s0, 0($sp)

	move $s0, $a0

print_loop:
	lbu $t0, 0($s0)		# load byte
	beqz $t0, print_end	# stop at null terminator

	# Polling MMIO transmitter
	lui $t1, 0xffff
	ori $t1, $t1, 0x0008
wait_ready:
	lw $t2, 0($t1)
	andi $t2, $t2, 1
	beqz $t2, wait_ready

	# Send char
	lui $t1, 0xffff
	ori $t1, $t1, 0x000c
	sb $t0, 0($t1)

	addi $s0, $s0, 1
	j print_loop

print_end:
	lw $s0, 0($sp)
	lw $ra, 4($sp)
	addi $sp, $sp, 8
	jr $ra

# -------------------------
# Print map
print_map:
	addi $sp, $sp, -4	# Allocate space on the stack
	sw $ra, 0($sp)		# Save the current return address
    
	la $a0, map
	jal print
    
	lw $ra, 0($sp)		# Restore the return address
	addi $sp, $sp, 4	# Deallocate stack space
	jr $ra			# Return safely to the caller

# -------------------------
# Print score
print_score:
	addi $sp, $sp, -4
	sw $ra, 0($sp)

	# Print "Score: "
	la $a0, score
	jal print

	# Convert integer score to string
	move $a0, $s7
	jal int_to_string
	move $a0, $v0
	jal print
    
	# New line
	la $a0, new_line
	jal print

	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra

# ---------- New: redraw entire screen ----------
update_screen:
	addi $sp, $sp, -8
	sw   $ra, 4($sp)
	sw   $s0, 0($sp)	# Save $s0 so we can use it as a loop counter safely

	# clear screen by printing newlines
	li   $s0, 40		# Using $s0 instead of $t0 because print overwrites $t0
    
clear_nl_loop:
	la   $a0, new_line
	jal  print
	addi $s0, $s0, -1
	bgtz $s0, clear_nl_loop

	# print score line
	jal  print_score

	# print map
	la   $a0, map
	jal  print

	lw   $s0, 0($sp)
	lw   $ra, 4($sp)
	addi $sp, $sp, 8
	jr   $ra

# -------------------------
# Convert integer to ASCII string
int_to_string:
	addi $sp, $sp, -8
	sw $ra, 4($sp)

	la $t0, int_buffer
	addi $t0, $t0, 11
	sb $zero, 0($t0)	# null terminator

	move $t1, $a0
	li $t2, 10
	beqz $t1, zero_case

convert_loop:
	div $t1, $t2
	mfhi $t3	# remainder
	mflo $t1	# quotient

	addi $t3, $t3, '0'
	addi $t0, $t0, -1
	sb $t3, 0($t0)

	bnez $t1, convert_loop
	j done

zero_case:
	addi $t0, $t0, -1
	li $t3, '0'
	sb $t3, 0($t0)

done:
	move $v0, $t0

	lw $ra, 4($sp)
	addi $sp, $sp, 8
	jr $ra
    
# -------------------------
# Update score
update_score:
	addi $s7, $s7, 5	# just add points, the screen will be redrawn by update_player
	jr $ra

# -------------------------
# Using player's input
movement:
	# read key
	la   $t9, key_buffer
	lb   $t0, 0($t9)

	# if no key -> clear last_key and return
	beqz $t0, reset_last

	# check if same as last processed key
	la   $t8, last_key
	lb   $t1, 0($t8)
	beq  $t0, $t1, ignore_repeat	# if it's the same key, ignore but consume buffer

	# store new key as last and consume input
	sb   $t0, 0($t8)
	sb   $zero, 0($t9)
    
	# Movement dispatch
	beq $t0, 119, up	# input 'w'
	beq $t0, 115, down	# input 's'
	beq $t0, 97, left	# input 'a'
	beq $t0, 100, right	# input 'd'
	j end_move
    
ignore_repeat:
	# consume the repeating key so we can detect release later
	sb   $zero, 0($t9)
	j    end_move

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
	jr $ra
    
reset_last:
	la $t8, last_key
	sb $zero, 0($t8)
	jr $ra

# -------------------------
# Updating the player
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
	li $s4, 13		# width

	# New offset
	mul $t2, $s2, $s4	# row * Map_W
	add $t2, $t2, $s3	# + col
	add $s1, $s0, $t2	# new address -> new map
    
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
    
	mul $t2, $t6, $s4	# row_old * Map_W
	add $t2, $t2, $t7	# + col_old
	add $s0, $s0, $t2
	li $t3, ' '		# clear old 'P'
	sb $t3, 0($s0)
    
	# Update players position
	sw $s2, x_player
	sw $s3, y_player
    
	# Putting P into the new location    
	li $t3, 'P'
	sb $t3, 0($s1)
    
	# Reprint screen ONCE after all changes are done
	jal update_screen
    
exit_update:
	lw $s4, 0($sp)
	lw $s3, 4($sp)
	lw $s2, 8($sp)
	lw $s1, 12($sp)
	lw $s0, 16($sp)
	lw $ra, 20($sp)
	addi $sp, $sp, 24
	jr $ra

# -------------------------
# Keyboard interrupt
.ktext 0x80000180
kb_interrupt:
	.set noat		# Tell assembler not to use $at
	move $k0, $at		# Save main program's $at state into $k0
	.set at			# Re-enable $at for pseudo-instructions below

	li $k1, 0xffff0004
	lb $k1, 0($k1)		# read key + auto-clear interrupt
	la $at, key_buffer	# temporarily use $at for memory address
	sb $k1, 0($at)

	.set noat
	move $at, $k0		# Restore main program's $at state
	.set at
	eret