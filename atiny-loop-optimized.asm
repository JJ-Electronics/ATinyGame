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
	;r20 r21 r23
	;r20 r22 r23
	;r21 r22 r24 (low half)
	
	;0,0 1,0 2,0
	;0,1 1,1 2,1
	;0,2 1,2 2,2
	
	; each LED has 4 bits
	; bits 2 & 3 => mode
	;
	; mode 00 => solid
	;   bits 0 & 1 => brightness
	; mode 01 => blinking
	;   bits 0 & 1 => speed
	; mode 10 => fading
	;   bits 0 & 1 => speed
	; mode 11 => unused
	;   bits 0 & 1 => unused
	; 
	; 0 off
	; 1 full brightness
	; 2 dim
	; 3 very dim
	; 4 blinking fast
	; 5 blinking med
	; 6 blinking slow
	; 7 blinking very slow
	; 8 fading fast
	; 9 fading med
	; a fading slow
	; b fading very slow
	; c unused
	; d unused
	; e unused
	; f unused
	
	; buttons
	; L r24 0b00010000
	; R r24 0b00100000
	; S r24 0b01000000
	
	ldi r20, 0x10
	ldi r21, 0x00
	ldi r22, 0x10
	ldi r23, 0x11
	ldi r24, 0x00
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


loop:

	;game logic
	mov r16, r24
	andi r16, 0b00010000
	swap r16
	cbr r20, 0x0f
	or r20, r16
	
	mov r16, r24
	andi r16, 0b00100000
	lsr r16
	cbr r21, 0xf0
	or r21, r16
	
	mov r16, r24
	andi r16, 0b01000000
	swap r16
	lsr r16
	lsr r16
	cbr r22, 0x0f
	or r22, r16
	



	;button and LED loop
	
	cbr r24, 0b01110000 ;clear the button state bits

buttonL:
	ldi r16, 1<<PB2 ; set as output
	out DDRB, r16 ; data direction
	ldi r16, 0x00 ; sets all pins low
	out PORTB, r16
	
	rcall buttonDelay
	in r16, PINB; read the pins
	subi r16, 0
	brne buttonR ;if the button is not pressed (aka 1 because pull up resistor), skip setting the bit
	sbr r24, 0b00010000

buttonR:
	ldi r16, 1<<PB1 ; set as output
	out DDRB, r16 ; data direction
	ldi r16, 0x00 ; sets all pins low
	out PORTB, r16
	
	rcall buttonDelay
	in r16,PINB; read the pins
	subi r16, 0
	brne buttonS
	sbr r24, 0b00100000

buttonS:
	ldi r16, 1<<PB0 ; set as output
	out DDRB, r16 ; data direction
	ldi r16, 0x00 ; sets all pins low
	out PORTB, r16
	
	rcall buttonDelay
	in r16,PINB; read the pins
	subi r16, 0
	brne led00
	sbr r24, 0b01000000

led00:
	mov r16, r20
	andi r16, 0x0f
	subi r16, 0
	breq led01
	ldi r16, 1<<PB3 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB2
	out PORTB, r16
led01:	
	rcall ledDelay
	mov r16, r20
	andi r16, 0xf0
	subi r16, 0
	breq led02
	ldi r16, 1<<PB3 | 1<<PB1
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB1
	out PORTB, r16
led02:
	rcall ledDelay
	mov r16, r21
	andi r16, 0x0f
	subi r16, 0
	breq led10
	ldi r16, 1<<PB3 | 1<<PB0
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB0
	out PORTB, r16
	
led10:
	rcall ledDelay
	mov r16, r21
	andi r16, 0xf0
	subi r16, 0
	breq led11
	ldi r16, 1<<PB1 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB1
	out PORTB, r16
led11:
	rcall ledDelay
	mov r16, r22
	andi r16, 0x0f
	subi r16, 0
	breq led12
	ldi r16, 1<<PB1 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB2
	out PORTB, r16
led12:
	rcall ledDelay
	mov r16, r22
	andi r16, 0xf0
	subi r16, 0
	breq led20
	ldi r16, 1<<PB0 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB2
	out PORTB, r16
	
led20:
	rcall ledDelay
	mov r16, r23
	andi r16, 0x0f
	subi r16, 0
	breq led21
	ldi r16, 1<<PB0 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB0
	out PORTB, r16
led21:
	rcall ledDelay
	mov r16, r23
	andi r16, 0xf0
	subi r16, 0
	breq led22
	ldi r16, 1<<PB0 | 1<<PB1
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB0
	out PORTB, r16
led22:
	rcall ledDelay
	mov r16, r24
	andi r16, 0x0f
	subi r16, 0
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
	ldi r17, 0x0b ;lower starts to not work
delayLoop:
	subi r16, 1 ; subtract 1
	sbci r17, 0 ; if r16 was 0, subtract 1
	brne delayLoop ; while r17 is not 0, loop
	ret

ledDelay:	
	ldi r16, 0xff
	ldi r17, 0x07
	rjmp delayLoop



