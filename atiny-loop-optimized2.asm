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
	;   bit 0 => speed
	;   bit 1 => phase
	; mode 10 => fading
	;   bit 0 => speed
	;   bit 1 => phase
	; mode 11 => unused
	;   bits 0 & 1 => unused
	; 
	; 0 off
	; 1 full brightness
	; 2 dim
	; 3 very dim
	; 4 blinking fast
	; 5 blinking slow
	; 6 blinking fast, out of phase
	; 7 blinking slow, out of phase
	; 8 fading fast
	; 9 fading slow
	; a fading fast, out of phase
	; b fading slow, out of phase
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
	
	; r25 will be a loop counter (used for LED effect calculations)
	ldi r25, 0x00
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
	;0,0
	mov r16, r20 ;copy the LED's register to r16
	ldi r17, 1<<PB3 | 1<<PB2 ;indicate the outputs
	ldi r18, 1<<PB2 ;indicate which outputs should be high
	rcall led

	;0,1
	mov r16, r20 ;copy the LED's register to r16
	swap r16 ;swap the low and high word
	ldi r17, 1<<PB3 | 1<<PB1 ;indicate the outputs
	ldi r18, 1<<PB1 ;indicate which output should be high
	rcall led

	;0,2
	mov r16, r21 ;copy the LED's register to r16
	ldi r17, 1<<PB3 | 1<<PB0 ;indicate the outputs
	ldi r18, 1<<PB0 ;indicate which outputs should be high
	rcall led

	;1,0
	mov r16, r21 ;copy the LED's register to r16
	swap r16 ;swap the low and high word
	ldi r17, 1<<PB1 | 1<<PB2 ;indicate the outputs
	ldi r18, 1<<PB1 ;indicate which output should be high
	rcall led

	;1,1
	mov r16, r22 ;copy the LED's register to r16
	ldi r17, 1<<PB1 | 1<<PB2 ;indicate the outputs
	ldi r18, 1<<PB2 ;indicate which outputs should be high
	rcall led

	;1,2
	mov r16, r22 ;copy the LED's register to r16
	swap r16 ;swap the low and high word
	ldi r17, 1<<PB0 | 1<<PB2 ;indicate the outputs
	ldi r18, 1<<PB2 ;indicate which output should be high
	rcall led

	;2,0
	mov r16, r23 ;copy the LED's register to r16
	ldi r17, 1<<PB0 | 1<<PB2 ;indicate the outputs
	ldi r18, 1<<PB0 ;indicate which outputs should be high
	rcall led

	;2,1
	mov r16, r23 ;copy the LED's register to r16
	swap r16 ;swap the low and high word
	ldi r17, 1<<PB0 | 1<<PB1 ;indicate the outputs
	ldi r18, 1<<PB0 ;indicate which output should be high
	rcall led

	;2,2
	mov r16, r24 ;copy the LED's register to r16
	ldi r17, 1<<PB0 | 1<<PB1 ;indicate the outputs
	ldi r18, 1<<PB1 ;indicate which outputs should be high
	rcall led
	
loopEnd:
	rcall ledDelay
	ldi r16, 0x00
	out DDRB, r16 ; data direction
	inc r25 ;increment the loop counter
	rjmp loop

	



led:
	out DDRB, r17 ; data direction
	ldi r17, 0x00
	out PORTB, r17 ;turn the LED off to start
	
	;r16 should be set up with the low word being the one to use, doing "swap" if needed
	andi r16, 0x0f
	subi r16, 0
	breq ledRet ;skip turning on the LED if the register value was 0
	
	;r18 should be set up with the output to use
	out PORTB, r18 ;turn on the LED
	
ledRet:
	rcall ledDelay ;delay either way
	ret



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



