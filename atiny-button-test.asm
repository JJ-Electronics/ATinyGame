;
; tinyblink
; Blinks an LED on pin 4 (PB2)
;

.include "/usr/share/avra/tn9def.inc"
;.DEVICE ATtiny10

; variables
.EQU delayMult1 = 0xff ; the delay is delay3*delaymult2*delaymult1 
.EQU delayMult2 = 0x0f
.EQU delayMult3 = 0x01

.CSEG ; code section
.ORG $0000 ; the starting address
main:
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

loop:
button0:
	;S button
	ldi r16, 1<<PB0 ; set as output
	out DDRB, r16 ; data direction
	ldi r16, 0x00 ; sets all pins low
	out PORTB, r16
	
	rcall delay
	in r16,PINB; read the pins
	subi r16, 0
	brne button1 ; set as output
	rjmp led00
	
led00:
	; 0,0
	ldi r16, 1<<PB3 | 1<<PB2
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB2
	out PORTB, r16
	rcall delay
	ldi r16, 0x00
	out DDRB, r16 ; data direction
	rjmp button1
	
button1:
	;R button
	ldi r16, 1<<PB1 ; set as output
	out DDRB, r16 ; data direction
	ldi r16, 0x00 ; sets all pins low
	out PORTB, r16
	
	rcall delay
	in r16,PINB; read the pins
	subi r16, 0
	brne button2
	rjmp led01

led01:
	; 0,1
	ldi r16, 1<<PB3 | 1<<PB1
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB1
	out PORTB, r16
	rcall delay
	ldi r16, 0x00
	out DDRB, r16 ; data direction
	rjmp button2
	
button2:
	;L button
	ldi r16, 1<<PB2 ; set as output
	out DDRB, r16 ; data direction
	ldi r16, 0x00 ; sets all pins low
	out PORTB, r16
	
	rcall delay
	in r16,PINB; read the pins
	subi r16, 0
	brne loop
	rjmp led02

led02:
	; 0,2
	ldi r16, 1<<PB3 | 1<<PB0
	out DDRB, r16 ; data direction
	ldi r16, 1<<PB0
	out PORTB, r16
	rcall delay
	ldi r16, 0x00
	out DDRB, r16 ; data direction
	rjmp loop


delay:
	; not really needed, but keep r16-r18
	push r16
	push r17
	push r18
	
	ldi r16, delayMult1
	ldi r17, delayMult2
	ldi r18, delayMult3

	; start delay loop
delayLoop:
	subi r16, 1 ; subtract 1
	;sbci r17, 0 ; if r16 was 0, subtract 1
	;sbci r18, 0 ; if r17 was 0, subtract 1
	brne delayLoop ; while r18 is not 0, loop
	; end delay loop

	pop r18
	pop r17
	pop r16
	ret



