############################################################
# ROGUELIKE ENGINE BASE – TILEMAP PROFISSIONAL
############################################################

.data

MAP_W: .word 12
MAP_H: .word 8

# MAPA LÓGICO (sem ASCII)
map:
.byte 1,1,1,1,1,1,1,1,1,1,1,1
.byte 1,0,0,0,0,0,0,0,0,0,0,1
.byte 1,0,0,0,0,0,0,0,0,0,0,1
.byte 1,0,0,0,0,0,0,0,0,0,2,1
.byte 1,0,0,0,0,0,0,0,0,0,0,1
.byte 1,0,0,0,0,0,0,0,0,0,0,1
.byte 1,0,0,0,0,0,0,0,0,0,0,1
.byte 1,1,1,1,1,1,1,1,1,1,1,1

player_x: .word 5
player_y: .word 2

msg_block: .asciiz "Bateu na parede!\n"

############################################################
.text
############################################################

.globl main
main:
    li $sp,0x7fffeffc

    jal render_map

    li $a0,2      # move leste
    jal move_player

    li $a0,2
    jal move_player

    li $a0,1
    jal move_player

loop: j loop


############################################################
# MMIO PRINT CHAR
############################################################
print_char:
wait_ready:
    li $t0,0xffff0008
    lw $t1,0($t0)
    andi $t1,$t1,1
    beqz $t1,wait_ready

    li $t0,0xffff000c
    sw $a0,0($t0)
    jr $ra


############################################################
# GET TILE (a0=x, a1=y) -> v0=tile
############################################################
get_tile:
    la $t0,MAP_W
    lw $t0,0($t0)

    mul $t1,$a1,$t0
    add $t1,$t1,$a0

    la $t2,map
    add $t2,$t2,$t1
    lbu $v0,0($t2)

    jr $ra


############################################################
# RENDER TILE -> ASCII
# a0 = tile, v0 = char
############################################################
tile_to_char:
    beq $a0,0,floor
    beq $a0,1,wall
    beq $a0,2,door

floor: li $v0,' '
       jr $ra
wall:  li $v0,'#'
       jr $ra
door:  li $v0,'D'
       jr $ra


############################################################
# RENDER MAP COMPLETO
############################################################
render_map:
    addi $sp,$sp,-8
    sw $ra,4($sp)
    sw $s0,0($sp)

    la $s0,MAP_W
    lw $s0,0($s0)

    li $t1,0  # y

row_loop:
    li $t0,0  # x

col_loop:

    # checa jogador primeiro
    la $t2,player_x
    lw $t2,0($t2)
    la $t3,player_y
    lw $t3,0($t3)

    bne $t0,$t2,draw_tile
    bne $t1,$t3,draw_tile

    li $a0,'@'
    jal print_char
    j next_col

draw_tile:
    move $a0,$t0
    move $a1,$t1
    jal get_tile

    move $a0,$v0
    jal tile_to_char

    move $a0,$v0
    jal print_char

next_col:
    addi $t0,$t0,1
    blt $t0,$s0,col_loop

    li $a0,10
    jal print_char

    addi $t1,$t1,1
    blt $t1,8,row_loop

    lw $s0,0($sp)
    lw $ra,4($sp)
    addi $sp,$sp,8
    jr $ra


############################################################
# MOVE PLAYER
# a0 = dir (0=N,1=S,2=L,3=O)
############################################################
move_player:
    addi $sp,$sp,-4
    sw $ra,0($sp)

    la $t0,player_x
    lw $t0,0($t0)
    la $t1,player_y
    lw $t1,0($t1)

    beq $a0,0,north
    beq $a0,1,south
    beq $a0,2,east
    beq $a0,3,west
    j done

north: addi $t1,$t1,-1  
	j test
south: addi $t1,$t1,1  
	 j test
east:  addi $t0,$t0,1  
	 j test
west:  addi $t0,$t0,-1

test:
    move $a0,$t0
    move $a1,$t1
    jal get_tile

    beq $v0,1,blocked

    la $t2,player_x
    sw $t0,0($t2)
    la $t2,player_y
    sw $t1,0($t2)

    jal render_map
    j done

blocked:
    la $a0,msg_block
    # aqui poderia usar print string se quiser

done:
    lw $ra,0($sp)
    addi $sp,$sp,4
    jr $ra