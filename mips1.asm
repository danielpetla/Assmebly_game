.data
# map: 12 visible chars + newline = 13 bytes per row
map:
    .asciiz "############\n#          #\n#     P    #\n#          #\n#     @    #\n#          #\n#          #\n############\n"

score:      .asciiz "Score: "
new_line:   .asciiz "\n"
int_buffer: .space 12

# player coords (row, col)
x_player: .word 2
y_player: .word 6

new_row:  .word 0
new_col:  .word 0

# single-byte input buffer
key_buffer: .byte 0

.text
.globl main

# -------------------------
# Main
main:
    # Initialize stack & score
    li $sp, 0x7fffeffc
    li $s7, 0

    # Set up CP0 Status: enable IE (bit0) and IM0 (bit8).
    # IM0 is the hardware interrupt line used by the MMIO keyboard in MARS.
    mfc0 $t0, $12
    ori  $t0, $t0, 0x00000101   # set IE=1 and IM0=1
    mtc0 $t0, $12

    # Print score and map
    jal print_score

    # Move map 2 lines down
    li $s5, 0
    li $s6, 2
print_blank:
    la $a0, new_line
    jal print
    addi $s5, $s5, 1
    blt $s5, $s6, print_blank

    jal print_map

    # main loop: just call movement repeatedly (keyboard will be filled by interrupts)
game_loop:
    jal movement
    j game_loop

# -------------------------
# Printing routine ($a0 = pointer)
print:
    addi $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)

    move $s0, $a0
print_loop:
    lbu $t0, 0($s0)
    beqz $t0, print_end

    # wait transmitter ready
    li $t1, 0xffff0008
wait_ready:
    lw $t2, 0($t1)
    andi $t2, $t2, 1
    beqz $t2, wait_ready

    # send char
    li $t1, 0xffff000c
    sb $t0, 0($t1)

    addi $s0, $s0, 1
    j print_loop

print_end:
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# -------------------------
print_map:
    la $a0, map
    jal print
    jr $ra

# -------------------------
print_score:
    addi $sp, $sp, -8
    sw $ra, 4($sp)

    la $a0, score
    jal print

    move $a0, $s7
    jal int_to_string
    move $a0, $v0
    jal print

    la $a0, new_line
    jal print

    lw $ra, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# -------------------------
int_to_string:
    addi $sp, $sp, -8
    sw $ra, 4($sp)

    la $t0, int_buffer
    addi $t0, $t0, 11
    sb $zero, 0($t0)

    move $t1, $a0
    li $t2, 10
    beqz $t1, zero_case

convert_loop:
    div $t1, $t2
    mfhi $t3
    mflo $t1
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
update_score:
    addi $s7, $s7, 5
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal print_score
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# -------------------------
# Kernel exception vector for MARS keyboard MMIO
# This label must be exactly __kernel_entry_point for MARS to jump here.
.ktext 0x80000180
__kernel_entry_point:
    # We are in kernel context—save a small set of registers we use.
    addi $sp, $sp, -16
    sw   $ra, 12($sp)
    sw   $s0, 8($sp)
    sw   $s1, 4($sp)
    sw   $s2, 0($sp)

    # Read keyboard data register (0xffff0004). If no data, just return.
    li $t0, 0xffff0004
    lb $t1, 0($t0)        # t1 = ASCII char (if available)

    # Store key into key_buffer (single byte)
    la $t2, key_buffer
    sb $t1, 0($t2)

    # Echo the char immediately so you can see it in the display (optional)
    li $t0, 0xffff000c
    sb $t1, 0($t0)

    # Clear/acknowledge the interrupt by reading receiver control register
    li $t0, 0xffff0000
    lw $t3, 0($t0)        # reading clears the pending bit in this MMIO model

    # restore registers and return from exception
    lw   $s2, 0($sp)
    lw   $s1, 4($sp)
    lw   $s0, 8($sp)
    lw   $ra,12($sp)
    addi $sp, $sp, 16
    eret

    .text

# -------------------------
# Using player's input (movement reads key_buffer)
movement:
    la $t9, key_buffer
    lb $t0, 0($t9)
    beqz $t0, end_move

    # Optional small debug echo by printing a 1-byte buffer (uses normal print)
    # (uncomment for debugging; leave commented for final coursework)
    # addi $sp,$sp,-4
    # sw $ra,0($sp)
    # la $a0, debug_char
    # sb $t0, debug_char
    # jal print
    # lw $ra,0($sp)
    # addi $sp,$sp,4

    beq $t0, 119, up   # 'w'
    beq $t0, 115, down # 's'
    beq $t0, 97, left  # 'a'
    beq $t0, 100, right# 'd'
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
    addi $t0, $t0, 1
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
    addi $t1, $t1, 1
    sw $t1, new_col
    j update_player

end_move:
    la $t9, key_buffer
    sb $zero, 0($t9)
    jr $ra

# -------------------------
update_player:
    addi $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    sw $s4, 0($sp)

    la $s0, map
    lw $s2, new_row
    lw $s3, new_col
    li $s4, 13          # row stride (12 chars + '\n')

    mul $t2, $s2, $s4
    add $t2, $t2, $s3
    add $s1, $s0, $t2

    lbu $t5, 0($s1)
    li $t3, '#'
    beq $t5, $t3, exit_update

    li $t3, '@'
    bne $t5, $t3, clear_old
    jal update_score

clear_old:
    lw $t6, x_player
    lw $t7, y_player
    la $s0, map
    mul $t2, $t6, $s4
    add $t2, $t2, $t7
    add $s0, $s0, $t2
    li $t3, ' '
    sb $t3, 0($s0)

    sw $s2, x_player
    sw $s3, y_player

    li $t3, 'P'
    sb $t3, 0($s1)

    jal print_map

exit_update:
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