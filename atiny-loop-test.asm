.include "/usr/share/avra/tn9def.inc"

.CSEG ; code section
.ORG $0000 ; the starting address

setup:
	; set up the stack
	ldi r16, high(RAMEND)
	out SPH, r16
	ldi r16, low(RAMEND)
	out SPL, r16
	
	; set clock divider
	ldi r16, 0x00 ; clock divided by 1
	ldi r17, 0xD8 ; the key for CCP
	out CCP, r17 ; Configuration Change Protection, allows protected changes
	out CLKPSR, r16 ; sets the clock divider
	
	; nop for sync
	nop
	
	; LED grid:
	;r19 r22 r25
	;r20 r23 r26
	;r21 r24 r27
	
	;0,0 1,0 2,0
	;0,1 1,1 2,1
	;0,2 1,2 2,2
	
	ldi r19, 0x00
	ldi r20, 0x01
	ldi r21, 0x01
	
	ldi r22, 0x00
	ldi r23, 0x00
	ldi r24, 0x01
	
	ldi r25, 0x01
	ldi r26, 0x01
	ldi r27, 0x01
	
	; buttons
	; L r28
	; R r29
	; S r30

	ldi r28, 0x00
	ldi r29, 0x00
	ldi r30, 0x00
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


loop:

	;app logic
	mov r19, r28
	mov r22, r29
	mov r23, r30





	;button and LED loop
	
	;L button
	ldi r16, 1<<PB2 ; set as output
	out DDRB, r16 ; data direction
	ldi r16, 0x00 ; sets all pins low
	out PORTB, r16
	
	rcall buttonDelay
	in r16,PINB; read the pins
	mov r28, r16


	;R button
	ldi r16, 1<<PB1 ; set as output
	out DDRB, r16 ; data direction
	ldi r16, 0x00 ; sets all pins low
	out PORTB, r16
	
	rcall buttonDelay
	in r16,PINB; read the pins
	mov r29, r16


	;S button
	ldi r16, 1<<PB0 ; set as output
	out DDRB, r16 ; data direction
	ldi r16, 0x00 ; sets all pins low
	out PORTB, r16
	
	rcall buttonDelay
	in r16,PINB; read the pins
	mov r30, r16

led00:
	subi r19, 0
	breq led01
	ldi r16, 1<<PB3 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB2
	out PORTB, r16
led01:	
	rcall ledDelay
	subi r20, 0
	breq led02
	ldi r16, 1<<PB3 | 1<<PB1
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB1
	out PORTB, r16
led02:
	rcall ledDelay
	subi r21, 0
	breq led10
	ldi r16, 1<<PB3 | 1<<PB0
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB0
	out PORTB, r16
	
led10:
	rcall ledDelay
	subi r22, 0
	breq led11
	ldi r16, 1<<PB1 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB1
	out PORTB, r16
led11:
	rcall ledDelay
	subi r23, 0
	breq led12
	ldi r16, 1<<PB1 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB2
	out PORTB, r16
led12:
	rcall ledDelay
	subi r24, 0
	breq led20
	ldi r16, 1<<PB0 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB2
	out PORTB, r16
	
led20:
	rcall ledDelay
	subi r25, 0
	breq led21
	ldi r16, 1<<PB0 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB0
	out PORTB, r16
led21:
	rcall ledDelay
	subi r26, 0
	breq led22
	ldi r16, 1<<PB0 | 1<<PB1
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB0
	out PORTB, r16
led22:
	rcall ledDelay
	subi r27, 0
	breq loopEnd
	ldi r16, 1<<PB0 | 1<<PB1
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB1
	out PORTB, r16
	
loopEnd:
	rcall ledDelay
	ldi r16, 0x00
	out DDRB, r16 ; data direction
	rjmp loop

	




buttonDelay:	
	ldi r16, 0xff
	ldi r17, 0x0a ;lower starts to not work
delayLoop:
	subi r16, 1 ; subtract 1
	sbci r17, 0 ; if r16 was 0, subtract 1
	brne delayLoop ; while r17 is not 0, loop
	ret

ledDelay:	
	ldi r16, 0xff
	ldi r17, 0x06
	rjmp delayLoop



