    	.cpu    cortex-a53
        .fpu    neon-fp-armv8
        .syntax unified         		@ modern syntax

	.equ   PERIPH,0x3f000000   		@ RPi 2 & 3 peripherals
        .equ   GPIO_OFFSET,0x200000  		@ start of GPIO device
        .equ   O_RDWR,00000002   		@ open for read/write
        .equ   O_DSYNC,00010000
        .equ   __O_SYNC,04000000
        .equ   O_SYNC,__O_SYNC|O_DSYNC
@ The following are defined in /usr/include/asm-generic/mman-common.h:
        .equ    PROT_READ,0x1   		@ page can be read
        .equ    PROT_WRITE,0x2  		@ page can be written
        .equ    MAP_SHARED,0x01 		@ share changes

@ The following are defined by me:
        .equ    O_FLAGS,O_RDWR|O_SYNC 	@ open file flags
        .equ    PROT_RDWR,PROT_READ|PROT_WRITE
        .equ    NO_PREF,0
        .equ    PAGE_SIZE,4096  		@ Raspbian memory page
        .equ    INPUT,0         		@ use pin for input
        .equ    OUTPUT,1        		@ use pin for ouput
        .equ    PIN_BTN,17        		@ button pin
        .equ	MAX, 10				@ maximum value of the counter
.data
	filepath: .asciz "/dev/lcd_1602"
	e: .ascii "e"
    	l: .ascii "l"
    	v: .ascii "v"
   	i: .ascii "i"
    	s: .ascii "s"
	person: .ascii "$"
	blank: .ascii " "
	position: .word 2818
	devErr:	.asciz  "Cannot open /dev/gpiomem\n"
	memErr: .asciz  "Cannot map /dev/gpiomem\n"
	message: .asciz	"Counter: %i \n"
	halfdelay: 
		.long 0
		.long 150000000
		
	delay: 
		.long 0
		.long 299999999
	.section .rodata
	.align 2

device: .asciz "/dev/gpiomem"   

	.text
	.global main
	.align 2
	.type main, %function


main:
	MOV R3, #0
	MOV R8, #15
	MOV R10, #2
	MOV R7, #5 
	LDR R0, =filepath
	MOV R1, #0
	MOV R2, #00700
	SWI 0
	MOV R4, R0
	MOV R7, #54
	MOV R1, #1
	MOV R0, R4
	SWI 0
	MOV R5, #0
	BL set_position_person_down
	BL draw_person
	BL set_position_final
	BL loop


loop: 
        MOV r9, #17 // R9 armazena o numero do GPIO e depois armazena o valor da leitura do botão 
        BL read_button
	MOV R12, #2
	BL move_terrain
	BL set_delay
	MOV R7, #54
	B loop

read_button: 
        push	{lr}
        LDR     r0, deviceAddr  		@ address of /dev/gpiomem
        LDR     r1, openMode    		@ flags for accessing device        
	bl 	open
        cmp     r0, #-1          		@ check for error
        bne     gpioMemOK       		@ no error, continue
        bl      endGPIO
        pop     {lr}
        BX      lr
gpioMemOK:      
        mov     r10, r0          		@ use r4 for file descriptor
        ldr	r5,  gpio		@ address of the GPIO
	push	{r5, r10}
        mov     r0, #NO_PREF     		@ let kernel pick memory
        mov     r1, #PAGE_SIZE   		@ get 1 page of memory
        mov     r2, #PROT_RDWR   		@ read/write this memory
        mov     r3, #MAP_SHARED  		@ share with other processes
        bl      mmap
        pop	{r5, r10}
        cmp     r0, #0          		@ check for error
        bgt     mmapOK          		@ no error, continue
        pop     {lr}
        bx      lr
        
mmapOK:        
        mov r5, r0          		@ use r5 for programming memory address
        mov r0, r5          		@ programming memory
        mov r1, r9       		@ button pin
        mov r2, #INPUT     			@ it's an input
        bl gpioPinFSelect  		@ select function
        
readPin:
        ldr r0, =1				@ MODIFY THIS VALUE TO SEE THE EFFECT THE BOUNCE
        bl usleep
        mov r0, r5				@ GPIO programming memory
        mov r1, r9			@ pin to read
        bl gpioPinRead	
        mov r9, r0
        cmp r9, #1
        beq print_final
        mov r0, r4
        pop {lr}
        bx lr
    
endGPIO: 
        mov r0, r10          		@ /dev/gpiomem file descriptor
        bl  close           		@ close the file
        mov r0, r4
        pop {lr}
        bx lr

print_final: 
	MOV R7, #54
        MOV R1, #4
	LDR R2, =s
	MOV R0, R4
	SWI 0 
 
draw_person: 
	MOV R1, #4
	LDR R2, =person
	MOV R0, R4
	SWI 0 
	BX lr

set_position_person_down: 
	MOV R1, #11
	MOV R0, R4
	LDR R5,=position
	MOV R2, #2
	STR  R2, [R5]
	MOV R10, #1
	ADD R5, R5, R10
	MOV R2, #0
	STR R2, [R5]
	LSL R5, R5, #8
	ADD R2, R2, R5	
	LDR R2, =position
	SWI 0	
	BX lr

set_position_person_up:
	MOV R1, #11
	MOV R0, R4
	LDR R5,=position
	MOV R2, #1
	STR  R2, [R5]
	MOV R10, #1
	ADD R5, R5, R10
	MOV R2, #0
	STR R2, [R5]
	LSL R5, R5, #8
	ADD R2, R2, R5	
	LDR R2, =position
	SWI 0	
	BX lr

move_terrain:
	MOV R6,#0
	CMP R8,R6
	BNE move
	BEQ clear_final
	BX lr

move: 	
	MOV R11, R14
	SUB R8, R8, #1
	BL set_position
	MOV R14, R11
	MOV R1, #4
	MOV R0, R4
	LDR R2, =e
	SWI 0
	MOV R0, R4
	SWI 0
	MOV R0, R4
	SWI 0
	MOV R0, R4
	LDR R2, =blank
	SWI 0
	BX lr

clear_final:
	MOV R7, #54
	CMP R10,R6
	BLT set_position_final
	MOV R8, #0
	BLT loop
	ADD R8, R12, R8
	BL set_position
	SUB R10, #1
	MOV R1, #4
	MOV R0, R4
	LDR R2, =blank
	SWI 0
        MOV R8, #0
	BL set_delay
	B loop
set_position:
	MOV R1, #11
	MOV R0, R4
	LDR R5,=position
	MOV R2, #2
	STR  R2, [R5]
	MOV R10, #1
	ADD R5, R5, R10
	MOV R2, R8
	STR R2, [R5]
	LSL R5, R5, #8
	ADD R2, R2, R5	
	LDR R2, =position
	SWI 0	
	BX lr

set_position_final:
	MOV R7, #54
	MOV R1, #11
	MOV R0, R4
	LDR R5,=position
	MOV R2, #2
	STR  R2, [R5]
	MOV R10, #1
	ADD R5, R5, R10
	MOV R2, #15
	STR R2, [R5]
	LSL R5, R5, #8
	ADD R2, R2, R5	
	LDR R2, =position
	SWI 0
	MOV R10, #2
	MOV R8, #15
	BX lr

set_delay: 
	MOV R7, #162
	MOV R1, #0
	LDR R0, =delay
	MOV R2, #0
	SWI 0
	BX lr

set_half_delay:
	MOV R7, #162
	MOV R1, #0
	LDR R0, =halfdelay
	MOV R2, #0
	SWI 0
	BX lr		

deviceAddr: .word device
gpio: .word PERIPH+GPIO_OFFSET
openMode: .word O_FLAGS	
	


