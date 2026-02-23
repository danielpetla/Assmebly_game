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