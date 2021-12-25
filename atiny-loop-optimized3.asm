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
	
	ldi r20, 0x10
	ldi r21, 0x00
	ldi r22, 0x10
	ldi r23, 0x23
	ldi r24, 0x00
	
	; r25 will be a loop counter (used for LED effect calculations)
	ldi r25, 0x00
	
	; buttons
	; L r24 0b00010000
	; R r24 0b00100000
	; S r24 0b01000000
	
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
	; 1 bright
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
	
	; ideas for the unused ones
	; blinking duty cycle (on 1/4, off 3/4 or reversed)
	; blinking/fading medium speed, in/out of phase
	; blinking dim
	
	; TODO
	; implement LED modes
	; sleep
	; pseudorandom generator
	; dice display
	; score display
	; game select
	; stacker game
	; race game
	; memory game
	; whack-a-mole game
	; dice roll "game"
	;
	; setPixel, getPixel, fillScreen methods?
	; button edge detection? (justPressed, justReleased)
	; button debouncing?
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
	
	;save the registers from game logic
	push r16
	push r17
	push r18
	push r19

	push r26
	push r27
	push r28
	push r29
	push r30
	push r31
	
	cbr r24, 0b01110000 ;clear the button state bits
	
	ldi r19, 0b00010000 ;bit mask for the first button (L), will be shifted left later
	ldi r18, 0b00000100 ;bit mask for PB2 (L button), will be shifted right later

buttonLoop:
	out DDRB, r18 ;set the current pin to output
	ldi r16, 0x00
	out PORTB, r16 ;set all pins low
	rcall buttonDelay
	
	sbis PINB, PB3 ;skip the next line if PB3 is 1
	or r24, r19 ;set the button's bit to 1

	lsl r19
	lsr r18
	subi r18, 0
	brne buttonLoop ;keep going until no pin is selected


	;;;ldi r16, 0x00
	;;;out PORTB, r16 ;set all pins low
	;;;out DDRB, r16 ;set all pins as inputs
	;;;rcall buttonDelay

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
	ldi r16, 0x00 ;set everything as inputs
	out DDRB, r16
	
	inc r25 ;increment the loop counter
	
	; restore the registers from game logic
	pop r16
	pop r17
	pop r18
	pop r19

	pop r26
	pop r27
	pop r28
	pop r29
	pop r30
	pop r31
	
	rjmp loop





led:
	out DDRB, r17 ;set the outputs
	ldi r17, 0x00
	out PORTB, r17 ;turn the LED off to start
	
	;r16 should be set up with the low word being the one to use, doing "swap" if needed
	andi r16, 0x0f
	
	subi r16, 0
	breq ledOff ;if the value is 0, leave the LED off
	dec r16
	breq ledOn ;if the value is 1, turn the LED on
	dec r16
	breq ledDim ;if the value is 2, make the LED dim
	dec r16
	breq ledVeryDim ;if the value is 3, make the LED very dim

ledOn:
	;r18 is which output to set to high
	out PORTB, r18 ;turn on the LED
ledOff:
	rcall ledDelay ;delay either way
	ret
ledDim:
	rcall ledDelay
	out PORTB, r18 ;turn on the LED
	ldi r16, 0x60
	rcall shortDelayLoop
	ret
ledVeryDim:
	rcall ledDelay
	out PORTB, r18 ;turn on the LED
	ldi r16, 0x20
	rcall shortDelayLoop
	ret


delay:
	ldi r16, 0xff
delayLoop:
	subi r16, 1 ; subtract 1
	sbci r17, 0 ; if r16 was 0, subtract 1
	brne delayLoop ; while r17 is not 0, loop
	ret

shortDelayLoop:
	subi r16, 1 ; subtract 1
	brne shortDelayLoop ; while r16 is not 0, loop
	ret
	

buttonDelay:
	ldi r17, 0x0b ;lower starts to not work
	rjmp delay

ledDelay:
	ldi r17, 0x08
	rjmp delay




