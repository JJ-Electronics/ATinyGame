;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; written by Johan Vandegriff  ;
; https://johanv.xyz/ATinyGame ;
; ATTINY9             Dec 2021 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include "tn9def.inc"

.CSEG ; code section
.ORG $0000 ; the starting address

	;;; MEMORY LOCATIONS ;;;
	
.equ RNG = 0x40
;.equ ??? = 0x41
;.equ ??? = 0x42
	
	;;; SETUP ;;;
	
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
	
	
	; buttons
	;   r24 0b!!!!_NLRS
	;         7654_3210
	;
	; 0 = S 0b0000_0001 is pressed
	; 1 = R 0b0000_0010 is pressed
	; 2 = L 0b0000_0100 is pressed
	; 3 = N 0b0000_1000 has random number generator been initialized
	; note that the high nybble is used for an LED
	
	;set the buttons to "pressed" so if you start it while holding a button
	;you have to release it and press it again, which might help the RNG seeding?
	ldi r24, 0b0000_0111
	
	
	; button edge detection
	;   r19 0b0000_0LRS
	;         7654_3210
	;
	; 0 = S 0b0000_0001 just pressed
	; 1 = R 0b0000_0010 just pressed
	; 2 = L 0b0000_0100 just pressed
	
	clr r19 ;clear the just pressed states
	
	
	; LED grid (L = low nybble, H = high nybble):
	; note that r24L is reserved for buttons
	;
	; r20H r21L r23H   0,0 1,0 2,0
	; r20L r22H r23L   0,1 1,1 2,1
	; r21H r22L r24H   0,2 1,2 2,2
	
	rcall clearScreen
	
	; r25 will be a loop counter used for:
	;   LED effect calculations
	;   random number seeding
	;   timing events (under 4 seconds)
	clr r25 ;one cycle through the 256 values = 4 seconds, so 64 frames/sec
	
	; each LED has 4 bits, which are used for a one-hot code
	; val  state
	; 0    off
	; 1    on
	; 2    dim
	; 3    unused
	; 4    blinking
	; 5-f  unused
	
	; OLD CODES: 
	; 0 off
	; 1 bright
	; 2 dim
	; 3 unused
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
	; sparkle
	; blinking between dim and bright
	;   possibly implement fading as this but fast and with many levels?
	
	; TODO
	; +button edge detection
	; +dice/score display
	; +pseudorandom generator
	; +dice roll "game"
	; +stacker game
	; +game select
	; +transition
	; +whack-a-mole game
	; +memory game
	; racing game
	; can vary the delay time for transition for free by ldi r25 instead of clr r25
	
	; graphics demo?
	; sleep to save battery?
	; button just released?
	; button debouncing?
	; implement LED fading?
	
	; TODO to make the program smaller
	; +14 combine into 1 game select state
	; +2 combine static and moving bar
	; +3 combine delay states into 1 with a signal of what state to go to next
	; +13 fix the animation so it doesn't have to save and restore the screen
	; +6 always delay even if the animation is not needed
	; +6 change LED codes to be one-hot
	; +6 remove push and pop of things in functions where not needed
	;      (showScore, fallScreen, random)
	; +3 use slower and more compact mod6 algorithm
	; +2 rewrite random function to retrieve the value from memory multiple times
	; +0 generalize score state for all games
	; +4 don't need to push r16 and r17 between game logic
	; +1 don't need to rjmp statesEnd in the last state
	; +26 for the state machine, use "push r16" then "ret" to manually set the PC to the address of one of the many rjmp instructions in a row
	; +2 compact all the states to remove dead ones
	; +3 might not need stackerFreeze
	; +2 store the next state for generalScore in r26 instead of the stack
	;
	; probably too much work for not much shorter (maybe +2)
	; use r30 and r31 as the tmp registers instead of r16 and r17
	; move "score" from r31 to r16, move "next state" from r30 to r17
	; replace the push/ret with an ijmp to Z, aka r30 and r31


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;; GAME LOGIC ;;;
	ldi r30, 1 ;gameSelect index
	ldi r18, 0 ;current state starts at gameSelect
loop:
	;check the state
	
	;use a fake "ret" to set the PC (basically ijmp without using the Z register)
	;see gameSelect for a demo that is commented out
	ldi r16, PC+6 ;6 is the number of lines after this one to jump to for state 0
	add r16, r18 ;plus r18 (the current state)
	push r16 ;push the low byte of the future PC to the stack
	clr r16 ;high byte = 0 since we are (hopefully) in the first 256 instructions
	push r16 ;push the high byte of the future PC to the stack
	ret ;fake "return" to pop the PC from the stack, which jumps
	
	rjmp gameSelect ;state 0
	rjmp stackerInit ;state 1
	rjmp racingInit ;state 2
	rjmp memoryInit ;state 3
	rjmp whackamoleInit ;state 4
	rjmp diceRoller ;state 5
	rjmp transition ;state 6
	rjmp memoryShow ;state 7
	rjmp memoryPress ;state 8
	rjmp whackamoleMole ;state 9
	rjmp whackamoleWait ;state 10
	rjmp stackerMove ;state 11
	rjmp generalScore ;state 12
	rjmp stackerFall ;state 13
	rjmp shortDelayState ;state 14
	rjmp stackerFall2 ;state 15
	rjmp whackamoleWhileAnyPressed ;state 16
	rjmp whileAnyPressed ;state 17
	rjmp stackerFell ;state 18
	rjmp memoryShowBetween ;state 19
;	rjmp statesEnd ;state 20
;	rjmp statesEnd ;state 21
;	rjmp statesEnd ;state 22
;	rjmp statesEnd ;state 23
;	rjmp statesEnd ;state 24
;	rjmp statesEnd ;state 25
	
	
gameSelect:
;	;fake "ret" demo
;	;ends up with r18=1 because the r18=5 was skipped by ret. cool!
;	ldi r18, 1 ;r18=1
;	ldi r16, PC+6 ;get ready to jump to the line that is 6 after this
;	push r16 ;push the low byte of the PC to the stack
;	ldi r16, 0
;	push r16 ;push 0 (the high byte) to the stack
;	ret ;fake "return" to pop the PC from the stack, which jumps
;	ldi r18, 5 ;this line is skipped by the ret and the setup beforehand
;	rjmp statesEnd ;the line that is 6 after "ldi r16, PC+6"
	
	
	mov r16, r30
	rcall showScore
	
	clr r29 ;clear the timer for the transition
	
	sbrc r19, 2 ;if L was just pressed
	dec r30 ;decrement the selected game
	subi r30, 0 ;if r30 == 0
	breq gameSelectInc ;r30++
	
	sbrc r19, 1 ;if R was just pressed
 gameSelectInc:
	inc r30 ;increment the selected game
	
	;TODO check if r30 == 6 and set it to 5
	
	sbrc r19, 0 ;if S was just pressed
	ldi r18, 6 ;change state to transition
	;it will go to the selected game next
	
	rjmp statesEnd
	
transition:
	;show dim lights
	ldi r20, 0x22
	ldi r21, 0x22
	ldi r22, 0x22
	ldi r23, 0x22
	cbr r24, 0xf0 ;cbr and sbr to avoid messing up the seeding and buttons
	sbr r24, 0x20
	
	inc r29 ;increment the timer
	sbrs r29, 5 ;if bit 5 in the timer is 1 (it has been 1/2 second)
	rjmp statesEnd
	
	mov r18, r30 ;move to whatever next state was specified in r30
	ldi r30, 1 ;set r30 to 1 in case we are going back to gameSelect
	rcall clearScreen ;clear the screen to prepare for the next state
	
	rjmp statesEnd
	
racingInit:
	rjmp statesEnd
	
memoryInit:
	rcall random ;make sure the RNG is seeded, now we can use r25 after
;	ldi r26 ;unused
	mov r27, r16 ;store the first number in the sequence so it can be recreated
;	ldi r28 ;reserved for button bitmask
	ldi r29, 0 ;the position in the current sequence

	ldi r31, 1 ;the score (length of the memory sequence)
	;it is 1 higher than what the actual score will be at the end
	
	;TODO check for overflow on the scores for each game and cap at 255
	
	clr r25 ;reset the timer
	ldi r18, 14 ;change state to shortDelayState
	ldi r30, 7 ;then change state to memoryShow
	rjmp statesEnd
	
memoryShow:
	rcall randomLED
	clr r25 ;reset the timer
	ldi r18, 14 ;change state to shortDelayState
	ldi r30, 19 ;then change state to memoryShowBetween
	rjmp statesEnd

memoryShowBetween:
	clr r25 ;reset the timer
	ldi r18, 14 ;change state to shortDelayState
	ldi r30, 7 ;then change state to memoryShow
	
	rcall clearScreen
	
	inc r29 ;increment sequence index
	mov r16, r29
	sub r16, r31 ;if the sequence is done showing
	brne memoryShowBetweenEnd
	
	sts RNG, r27 ;store the original random value back to the RNG to start over
	ldi r29, 0 ;reset the sequence index
	ldi r18, 8 ;change state to memoryPress
	
memoryShowBetweenEnd:
	rjmp statesEnd
	
memoryPress:
	subi r19, 0
	breq memoryPressEnd ;if any button was just pressed:
	
	rcall randomLED ;puts the button mask into r28
	rcall clearScreen
	
	and r28, r19 ;see if the correct button was just pressed
	breq memoryPressGameOver
		
	inc r29 ;increment sequence index
	mov r16, r29
	sub r16, r31 ;if the sequence is done being entered
	brne memoryPressEnd
	
	sts RNG, r27 ;store the original random value back to the RNG to start over
	ldi r29, 0 ;reset the sequence index
	clr r25 ;reset the timer
	ldi r18, 14 ;change state to shortDelayState
	ldi r30, 7 ;then change state to memoryShow
	inc r31 ;increase the score by 1 (the sequence length will also increase)

 memoryPressEnd:
	rjmp statesEnd
	
 memoryPressGameOver:
	dec r31 ;decrease the score by 1 to account for the extra one at the start
	clr r29 ;clear the timer for the transition
	ldi r18, 6 ;change state to transition
	ldi r30, 12 ;after that, change state to generalScore
	ldi r26, 3 ;finally, it will be memoryInit
	rjmp statesEnd
	
whackamoleInit:
	clr r29 ;clear the loop counter, when it reaches 255 (4 sec) the game is over
	ldi r31, 0 ;score (number of moles hit)

	ldi r18, 9 ;change state to whackamoleMole
	rjmp statesEnd
	
whackamoleMole:
	ldi r18, 10 ;change state to whackamoleWait
	rcall randomLED
	
whackamoleWait:
	inc r29 ;increment the timer
	breq whackamoleTimeUp
	
 whackamoleWaitTimeLeft:
	mov r16, r28 ;copy the bitmask
	eor r16, r24 ;see if the specified button (and no other) is pressed
	;TODO subtract from the score if the wrong one is pressed
	;TODO avoid subtracting when it is already 0
	cbr r16, 0b1111_1000 ;only care about the button bits
	subi r16, 0
	brne whackamoleWaitingStill
	
	inc r31 ;add 1 to the score
	rcall clearScreen
	ldi r18, 16 ;change state to whackamoleWhileAnyPressed
	ldi r30, 9 ;after that, change state to whackamoleMole
 whackamoleWaitingStill:
	rjmp statesEnd
	
 whackamoleTimeUp:
;	lsr r31 ;divide score by 2
	;timer is already cleared for the transition
	ldi r18, 6 ;change state to transition
	ldi r30, 12 ;after that, change state to generalScore
	ldi r26, 4 ;finally, it will be whackamoleInit
	rjmp statesEnd
	
whackamoleWhileAnyPressed:
	inc r29 ;increment the timer
	breq whackamoleTimeUp
	
whileAnyPressed:
	mov r16, r24
	cbr r16, 0b1111_1000
	subi r16, 0 ;if any button is pressed
	brne statesEnd2 ;do nothing
	;otherwise:
	mov r18, r30 ;move to whatever next state was specified in r30
	rjmp statesEnd
	
diceRoller:
	;sbrc r19, 0 ;if S just pressed
	;rcall clearScreen ;clear the screen
	
	;sbrc r19, 2 ;if L was just pressed, run the next line
	clr r29	;clear the timer for the transition state
	sbrc r19, 2 ;if L was just pressed, run the next line
	ldi r18, 6 ;change state to transition
	ldi r30, 0 ;after that the state will be gameSelect
	
	rcall random ;get a random number from 0 to 255
	rcall mod6 ;take the remainder when dividing by 6, so 0 to 5
	inc r16 ;add 1, so 1 to 6
	
	sbrc r19, 1 ;if R just pressed, skip next line
	rcall showScore ;display it as a dice number on the LEDs
	
	rjmp statesEnd
	
stackerInit: ;1
	;turn on the bottom 2 rows of LEDs, and the top left LED
	ldi r20, 0x11
	ldi r21, 0x10
	ldi r22, 0x11
	ldi r23, 0x01
	sbr r24, 0x10
	
	clr r25             ;clear the loop counter for consistent movement
	ldi r27, 0b01110000 ;the moving top row
	ldi r28, 1          ;the direction of motion (1 = >>, 0 = <<)
	ldi r29, 13         ;the delay between movements (next: 13-2)
	ldi r31, 0          ;the score (number of times the button was pressed, minus 1)
	
	;score   1  2 3 4 5 6 7 8 9 a b c d e f
	;delay 13,11,9,8,7,6,5,4,3,3,3,2,2,2,1,1,1,1,1,1,...
	;delta   2  2 1 1 1 1 1 1 0 0 1 0 0 1 0
	;x=200 #x starts at 200ms and decreases by 15% every time
	;for i in range(25): print(int(x/15.625+0.5)*15.625); x *= .85
	;for i in range(25): print(int(x/15.625+0.5)); x *= .85
	
	;       top row
	;         |||
	; 3  1 01110000
	; 3  2 00111000
	; 3  3 00011100
	; 3  4 00001110
	; 3  5 00000111
	;         |||
	; 2  1 00110000
	; 2  2 00011000
	; 2  3 00001100
	; 2  4 00000110
	;         |||
	; 1  1 00010000
	; 1  2 00001000
	; 1  3 00000100
	;         |||
	
	ldi r18, 11 ;change state to stackerMove
	
	rjmp statesEnd

stackerMove:
	sbrc r19, 0 ;if S was just pressed, run the next line
	ldi r18, 13 ;change state to stackerFall TODO maybe whileAnyPressed
	sbrc r19, 0 ;if S was just pressed, run the next line
	rjmp statesEnd
	
	;if the timer is 
	mov r16, r25
	sub r16, r29 ;check if the delay has elapsed yet
	brne statesEnd2
	clr r25
	
	
	sbrc r28, 0 ;if r28 = 1 (moving right)
	lsr r27
	
	sbrs r28, 0 ;if r28 = 0 (moving left)
	lsl r27
	
	;bits 4, 3, and 2 of r27 are the top row
	rcall clearTopRow
		
	sbrc r27, 4   ;if bit 4 is set
	sbr r20, 0x10 ;light up LED 0,0
	sbrc r27, 3   ;if bit 4 is set
	sbr r21, 0x01 ;light up LED 1,0
	sbrc r27, 2   ;if bit 4 is set
	sbr r23, 0x10 ;light up LED 2,0
	
	;reverse direction when it reaches the edge
	sbrc r21, 0 ;if LED 1,0 is on
	rjmp statesEnd ;jump to end
	
	;if r28 == 1 and !LED(1,0) and LED(2,0): r28 = 0
	;if r28 == 0 and !LED(1,0) and LED(0,0): r28 = 1
	;since LED(1,0) has already been checked this becomes:
	;if r28 == 1 and r23H: r28 = 0
	;if r28 == 0 and r20H: r28 = 1
	
	sbrs r28, 0 ;if r28 = 0
	rjmp stackerMover28is0
	
	;r28 == 1
	sbrc r23, 4 ;if r23H
	ldi r28, 0
	
 stackerMover28is0:
	sbrc r20, 4 ;if r20H
	ldi r28, 1
	
 statesEnd2:
	rjmp statesEnd
	
	
stackerFall:
	;save the screen for later so it isn't ruined by the animations
	;push r20
	;push r21
	;push r22
	;push r23
	;push r24
	
	;ldi r16, 0 ;keep track of if any are blinking
	
	;whichever ones should fall, make them blink
	sbrc r20, 0   ;if LED(0,1)==0
	rjmp stackerFallCol1Done
	sbrs r20, 4   ;and LED(0,0)==1
	rjmp stackerFallCol1Done
	cbr r20, 0xf0 ;clear LED(0,0)
	sbr r20, 0x40 ;set LED(0,0) to blink
	;ldi r16, 1    ;mark that at least 1 is blinking
 stackerFallCol1Done:
	
	sbrc r22, 4   ;if LED(1,1)==0
	rjmp stackerFallCol2Done
	sbrs r21, 0   ;and LED(1,0)==1
	rjmp stackerFallCol2Done
	cbr r21, 0x0f ;clear LED(1,0)
	sbr r21, 0x04 ;set LED(1,0) to blink
	;ldi r16, 1    ;mark that at least 1 is blinking
 stackerFallCol2Done:
	
	sbrc r23, 0   ;if LED(2,1)==0
	rjmp stackerFallCol3Done
	sbrs r23, 4   ;and LED(2,0)==1
	rjmp stackerFallCol3Done
	cbr r23, 0xf0 ;clear LED(2,0)
	sbr r23, 0x40 ;set LED(2,0) to blink
	;ldi r16, 1    ;mark that at least 1 is blinking
 stackerFallCol3Done:
	
	clr r25 ;clear the counter to start the next state's timer at 0
	ldi r18, 14 ;change state to shortDelayState
	ldi r30, 15 ;change state to stackerFall2 after that
	
	;if none are blinking, skip the entire rest of the animation
	;sbrs r16, 0 ;if r16 == 0
	;ldi r18, 18 ;change state to stackerFell
	
	rjmp statesEnd
	
shortDelayState:
	sbrc r25, 5 ;if bit 5 in the counter is 1, it has been 1/2 second so:
	mov r18, r30 ;move to whatever next state was specified in r30
	rjmp statesEnd
	
stackerFall2:
	;make the blinking ones fall from the top row to the middle
	
	sbrs r20, 6   ;if LED(0,0)==4 (blinking)
	rjmp stackerFall2Col1Done
	cbr r20, 0xff ;turn off LED(0,0) and LED(0,1)
	sbr r20, 0x04 ;set LED(0,1)=4 (blinking)
 stackerFall2Col1Done:
	
	sbrs r21, 2   ;if LED(1,0)==4 (blinking)
	rjmp stackerFall2Col2Done
	cbr r21, 0x0f ;turn off LED(1,0)
	cbr r22, 0xf0 ;turn off LED(1,1)
	sbr r22, 0x40 ;set LED(1,1)=4 (blinking)
 stackerFall2Col2Done:
	
	sbrs r23, 6   ;if LED(2,0)==4 (blinking)
	rjmp stackerFall2Col3Done
	cbr r23, 0xff ;turn off LED(2,0) and LED(2,1)
	sbr r23, 0x04 ;set LED(2,1)=4 (blinking)
 stackerFall2Col3Done:
	
	clr r25 ;clear the counter to start the next state's timer at 0
	
	ldi r18, 14 ;change state to shortDelayState
	ldi r30, 18 ;change state to stackerFell next
	rjmp statesEnd
	
;stackerFall3:
;	;make the blinking ones fall from the middle to the bottom
;	
;	sbrs r20, 2   ;if LED(0,1)==4 (blinking)
;	rjmp stackerFall3Col1Done
;	cbr r20, 0x0f ;turn off LED(0,1)
;	cbr r21, 0xf0 ;turn off LED(0,2)
;	sbr r21, 0x40 ;set LED(0,2)=4 (blinking)
; stackerFall3Col1Done:
;	
;	sbrs r22, 6   ;if LED(1,1)==4 (blinking)
;	rjmp stackerFall3Col2Done
;	cbr r22, 0xff ;turn off LED(1,1) and LED(1,2)
;	sbr r22, 0x04 ;set LED(1,2)=4 (blinking)
; stackerFall3Col2Done:
;	
;	sbrs r23, 2   ;if LED(2,1)==4 (blinking)
;	rjmp stackerFall3Col3Done
;	cbr r23, 0x0f ;turn off LED(2,1)
;	cbr r24, 0xf0 ;turn off LED(2,2)
;	sbr r24, 0x40 ;set LED(2,2)=4 (blinking)
; stackerFall3Col3Done:
;	
;	clr r25 ;clear the counter to start the next state's timer at 0
;	ldi r18, 18 ;change state to stackerFall6
;	rjmp statesEnd
	
stackerFell:
	;restore the screen from before the animations
	;pop r24
	;pop r23
	;pop r22
	;pop r21
	;pop r20
	
	
	;sbrs r20, 0   ;if LED(0,1)==0
	;cbr r20, 0xf0 ;clear LED(0,0)
	
	;sbrs r22, 4   ;if LED(1,1)==0
	;cbr r21, 0x0f ;clear LED(1,0)
	
	;sbrs r23, 0   ;if LED(2,1)==0
	;cbr r23, 0xf0 ;clear LED(2,0)
	
	
	;get rid of the blinking on the 2nd row from the falling animation
	cbr r20, 0b0000_0100 ;clear LED(0,1)'s "blinking bit"
	cbr r22, 0b0100_0000 ;clear LED(1,1)'s "blinking bit"
	cbr r23, 0b0000_0100 ;clear LED(2,1)'s "blinking bit"
	
	clr r27 ;reset the moving bar
	
	;recalculate the width of the moving bar
	sbrc r20, 4   ;if LED(0,0)==1
	sbr r27, 0b100
	
	sbrc r21, 0   ;if LED(1,0)==1
	sbr r27, 0b010
	
	sbrc r23, 4   ;if LED(2,0)==1
	sbr r27, 0b001
	
	;r27 can be 000, 001, 011, 111, 110, 100
	;for the last 2, it needs to be shifted over
	sbrs r27, 0 ;if the final bit is 0
	lsr r27     ;shift right
	sbrs r27, 0 ;if the final bit is 0
	lsr r27     ;shift right
	
	;if the game is over
	subi r27, 0
	brne stackerFellGameContinue
	
;	ldi r18, 12 ;could go directly to generalScore and remove the next 3 lines
	
	clr r29 ;clear the timer for the transition
	ldi r18, 6 ;change state to transition
	ldi r30, 12 ;after that, change state to generalScore
	ldi r26, 1 ;finally, it will be stackerInit
	
	rjmp statesEnd
	
 stackerFellGameContinue:
	rcall fallScreen
	
	;on every other one, go backwards
	sbrs r31, 0   ;if bit 0 of the score is 1
	rjmp stackerFellBackwards
	sbr r20, 0x10 ;set the top left LED to be on
	swap r27      ;move the row to the left side
	ldi r28, 1    ;set the motion direction to be >>
	rjmp stackerFellBackwardsAfter
	
 stackerFellBackwards:
	ldi r28, 0    ;set the motion direction to be <<
	sbr r23, 0x10 ;set the top right LED to be on
	;shift the 111, 011, or 001 to be 111, 110, or 100
	sbrs r27, 2 ;if the 2nd bit is 0
	lsl r27     ;shift left
	sbrs r27, 2 ;if the 2nd bit is 0
	lsl r27     ;shift left
	
 stackerFellBackwardsAfter:
	
	clr r25       ;clear the loop counter for consistent movement
	inc r31       ;increment the score
	
	ldi r18, 11 ;change state to stackerMove
	
	mov r16, r31
	subi r16, 11 ;if score == 11
	brne stackerFellAfterExtraDelay
	dec r29 ;decrease the delay
 stackerFellAfterExtraDelay:

	subi r16, 3 ;if score == 11+3 = 14
	brne stackerFellAfterExtraDelay2
	dec r29 ;decrease the delay
 stackerFellAfterExtraDelay2:
	
	mov r16, r31
	subi r16, 3 ;if score < 3
	brsh stackerFellAfterExtraDelay3
	dec r29 ;decrease the delay
 stackerFellAfterExtraDelay3:
	
	mov r16, r31
	subi r16, 9 ;if score < 9
	brsh statesEnd
	dec r29 ;decrease the delay
	
	
	rjmp statesEnd
	
generalScore:
	mov r16, r31
	rcall showScore
	sbrc r19, 1 ;if R was just pressed
	mov r18, r26 ;change state to whatever was given
	sbrc r19, 2 ;if L was just pressed
	ldi r18, 6 ;change state to transition
	ldi r30, 0 ;after that the state will be gameSelect
	clr r29	;clear the timer for the transition state 
;	rjmp statesEnd
	
	
	
	

	
statesEnd:
	;;; UPDATE IO ;;;
	
	;save the registers from game logic
	;push r16 ;r16 and r17 are always tmp and don't need to be saved
	;push r17
	push r18 ;r18 is the current state and needs to be saved

	;push r26 ;r26-r31 are not touched by the code after this so they will 
	;push r27 ;be preserved without being saved
	;push r28
	;push r29
	;push r30
	;push r31
	
	mov r19, r24 ;copy current button values to know prev for edge detection
	cbr r24, 0b0000_0111 ;clear the button state bits
	ldi r18, 0b0000_0100 ;bit mask for PB2 (L button) and r24 button states
	;will be shifted right to get PB1, then PB0, and to write to a different r24 bit

buttonLoop:
	out DDRB, r18 ;set the current pin to output
	ldi r16, 0x00
	out PORTB, r16 ;set all pins low
	rcall buttonDelay
	sbis PINB, PB3 ;skip the next line if PB3 is 1
	or r24, r18 ;set the button's bit to 1

	lsr r18 ;shift the bitmask to set a different pin as an output
	subi r18, 0 ;check if the shift fell off the end, which means we are done
	brne buttonLoop ;keep going until no pin is selected
	
	;button edge detection (just pressed)
	;just = !prev && curr
	;r19 = !r19 & r24L
	
	com r19 ;invert all bits to create !prev instead of prev
	and r19, r24 ;preform the "and" to get "just pressed"
	cbr r19, 0b1111_1000 ;clear the unused bits in r19 for predictability
	
	;0,0
	mov r16, r20 ;copy the LED's register to r16
	swap r16 ;swap the low and high nybble
	ldi r17, 1<<PB3 | 1<<PB2 ;indicate the outputs
	ldi r18, 1<<PB2 ;indicate which outputs should be high
	rcall led

	;0,1
	mov r16, r20 ;copy the LED's register to r16
	ldi r17, 1<<PB3 | 1<<PB1 ;indicate the outputs
	ldi r18, 1<<PB1 ;indicate which output should be high
	rcall led

	;0,2
	mov r16, r21 ;copy the LED's register to r16
	swap r16 ;swap the low and high nybble
	ldi r17, 1<<PB3 | 1<<PB0 ;indicate the outputs
	ldi r18, 1<<PB0 ;indicate which outputs should be high
	rcall led

	;1,0
	mov r16, r21 ;copy the LED's register to r16
	ldi r17, 1<<PB1 | 1<<PB2 ;indicate the outputs
	ldi r18, 1<<PB1 ;indicate which output should be high
	rcall led

	;1,1
	mov r16, r22 ;copy the LED's register to r16
	swap r16 ;swap the low and high nybble
	ldi r17, 1<<PB1 | 1<<PB2 ;indicate the outputs
	ldi r18, 1<<PB2 ;indicate which outputs should be high
	rcall led

	;1,2
	mov r16, r22 ;copy the LED's register to r16
	ldi r17, 1<<PB0 | 1<<PB2 ;indicate the outputs
	ldi r18, 1<<PB2 ;indicate which output should be high
	rcall led

	;2,0
	mov r16, r23 ;copy the LED's register to r16
	swap r16 ;swap the low and high nybble
	ldi r17, 1<<PB0 | 1<<PB2 ;indicate the outputs
	ldi r18, 1<<PB0 ;indicate which outputs should be high
	rcall led

	;2,1
	mov r16, r23 ;copy the LED's register to r16
	ldi r17, 1<<PB0 | 1<<PB1 ;indicate the outputs
	ldi r18, 1<<PB0 ;indicate which output should be high
	rcall led

	;2,2
	mov r16, r24 ;copy the LED's register to r16
	swap r16 ;swap the low and high nybble
	ldi r17, 1<<PB0 | 1<<PB1 ;indicate the outputs
	ldi r18, 1<<PB1 ;indicate which outputs should be high
	rcall led
	
	
	ldi r16, 0x00 ;set everything as inputs
	out DDRB, r16
	
	inc r25 ;increment the loop counter
	
	; restore the registers from game logic
	;pop r31
	;pop r30
	;pop r29
	;pop r28
	;pop r27
	;pop r26
	
	pop r18
	;pop r17
	;pop r16
	
	rjmp loop



	;;; FUNCTIONS ;;;

led:
	out DDRB, r17 ;set the outputs
	ldi r17, 0x00
	out PORTB, r17 ;turn the LED off to start
	
	;r16 should be set up with the low nybble being the one to use, doing "swap" if needed
	;if bit 0 is set, turn it on solid
	sbrc r16, 0
	rjmp ledOn
	;if bit 1 is set, turn it dim
	sbrc r16, 1
	rjmp ledDim
	;if bit 2 is set, make it blink
	sbrs r16, 2
	rjmp ledOff
	
	; blinking speeds
	; 0 => 1/32 second cycle
	; 1 => 1/16 second cycle
	; 2 => 1/8 second cycle
	; 3 => 1/4 second cycle
	; 4 => 1/2 second cycle
	; 5 => 1 second cycle
	; 6 => 2 second cycle
	; 7 => 4 second cycle
ledBlink:
	sbrc r25, 2 ;skip if a bit in the loop counter is cleared
	rjmp ledOff
ledOn:
	;r18 is which output to set to high
	out PORTB, r18 ;turn on the LED
ledOff:
	rcall ledDelay ;delay either way
	ret
ledDim:
	rcall ledDelay
	out PORTB, r18 ;turn on the LED
	ldi r16, 0x40
	ldi r17, 0x00
	rcall delayLoop
	ret


	
	
	
buttonDelay:
	ldi r17, 0x0b ;lower starts to not work
	rjmp delay

ledDelay:
	ldi r17, 0x08
;;;	rjmp delay

delay:
	ldi r16, 0xff
delayLoop:
	subi r16, 1 ; subtract 1
	sbci r17, 0 ; if r16 was 0, subtract 1
	brne delayLoop ; while r17 is not 0, loop
	ret

;;; x=0x40 (r16)
;;; y=0x00 (r17)
;;; 
;;; while (true) {
;;;   x--
;;;   if (x == 0xff) {
;;;     y--
;;;     if (y == 0xff) {
;;;       break;
;;;     }
;;;   }
;;; }


clearScreen:
	clr r20
	clr r21
	clr r22
	clr r23
	cbr r24, 0xf0 ;clear high nybble without disrupting low nybble (buttons)
	ret
	
	
fallScreen:
	;shift all pixels on the screen down by 1, replacing the top row with blank
	;push r16
	
	;copy the middle row to the bottom (preserving the top, but not the middle)
	;r21H <- r20L   0,2 <- 0,1
	cbr r21, 0xf0  ;clear r21H (the destination)
	mov r16, r20   ;copy r20 so we can modify it
	andi r16, 0x0f ;get only r20L
	swap r16       ;move r20L to r16H
	or r21, r16    ;copy what was r20L to r21H
	
	;r22L <- r22H   1,2 <- 1,1
	swap r22       ;just swap the nybbles (messing up the middle, but it's OK)
	
	;r24H <- r23L   2,2 <- 2,1
	cbr r24, 0xf0  ;clear r24H (the destination)
	mov r16, r23   ;copy r23 so we can modify it
	andi r16, 0x0f ;get only r23L
	swap r16       ;move r23L to r16H
	or r24, r16    ;copy what was r23L to r24H
	
	
	;copy the top row to the middle (preserving the bottom, but not the top)
	;r20L <- r20H   0,1 <- 0,0
	swap r20       ;just swap the nybbles (messing up the top, but it's OK)
	
	;r22H <- r21L   1,1 <- 1,0
	cbr r22, 0xf0  ;clear r22H (the destination)
	mov r16, r21   ;copy r21 so we can modify it
	andi r16, 0x0f ;get only r21L
	swap r16       ;move r21L to r16H
	or r22, r16    ;copy what was r21L to r22H
	
	;r23L <- r23H   2,1 <- 2,0
	swap r23       ;just swap the nybbles (messing up the top, but it's OK)
	
	;pop r16
	;falling thru to the next function is intentional
clearTopRow:
	;clear the top row
	cbr r20, 0xf0  ;clear 0,0
	cbr r21, 0x0f  ;clear 1,0
	cbr r23, 0xf0  ;clear 2,0
	
	ret
	
	
	; dice/score display
	;
	; A    B    C    D    E    F    G    H    I
	; r20H r20L r21H r21L r22H r22L r23H r23L r24H
	;
	;           0xABC_DEF_GHI
	; 0 0b00000 0x000_000_000
	; 1 0b00001 0x000_010_000
	; 2 0b00010 0x100_000_001
	; 3 0b00011 0x100_010_001
	; 4 0b00100 0x101_000_101
	; 5 0b00101 0x101_010_101
	; 6 0b00110 0x111_000_111
	; 7 0b00111 0x111_010_111
	; 8 0b01000 0x111_101_111
	; 9 0b01001 0x111_111_111
	;
	;A = bit 0 of score
	;B = score >= 2
	;C = score >= 4
	;D = score >= 6
	;E = score >= 8
	;
	;           0xBDC_EAE_CDB
	;
	;10 0b01010 0x000_100_000
	;11 0b01011 0x010_000_000
	;12 0b01100 0x010_100_000
	;13 0b01101 0x000_001_000
	;14 0b01110 0x000_101_000
	;15 0b01111 0x010_001_000
	;16 0b10000 0x010_101_000
	;17 0b10001 0x000_000_010
	;18 0b10010 0x000_100_010
	;19 0b10011 0x010_000_010
	;20 0b10100 0x010_100_010
	;21 0b10101 0x000_001_010
	;22 0b10110 0x000_101_010
	;23 0b10111 0x010_001_010
	;24 0b11000 0x010_101_010
	;25+        0x010_111_010
	;
	;if score > 25, set score to 25
	;0bDCBA = bits of (score-9)
	;E = score >= 25 (aka score-9 >= 16)
	;
	;           0x0A0_BEC_0D0

showScore:
	rcall clearScreen
	
	;r16 is the score
	;push r16
	subi r16, 10 ;if score >= 10
	brsh scoreMore ;holy BRSH! go to the higher number scores
	subi r16, -10 ;add the 10 back
	
	sbrc r16, 0 ;if bit 0 in the score is 1
	sbr r22, 0x10 ;led(1,1) = 1
	
	subi r16, 2
	brlo scoreDone
	; if score >= 2
	sbr r20, 0x10 ;led(0,0) = 1
	sbr r24, 0x10 ;led(2,2) = 1
	
	subi r16, 2
	brlo scoreDone
	; if score >= 4
	sbr r21, 0x10 ;led(0,2) = 1
	sbr r23, 0x10 ;led(2,0) = 1
	
	subi r16, 2
	brlo scoreDone
	; if score >= 6
	sbr r20, 0x01 ;led(0,1) = 1
	sbr r23, 0x01 ;led(2,1) = 1
	
	subi r16, 2
	brlo scoreDone
	; if score >= 8
	sbr r21, 0x01 ;led(1,0) = 1
	sbr r22, 0x01 ;led(1,2) = 1
	
	rjmp scoreDone
	
scoreMore:
	;r16 starts as score-10
	subi r16, 15 ;if score-10 < 15 aka if score < 25
	brlo score24
	sbr r22, 0x10 ;led(1,1) = 1
	ldi r16, -1 ;set score-25 to -1, aka score = 24
	
score24:
	;r16 starts as score-25
	subi r16, -16 ;r16 is now score-9
	
	sbrc r16, 0 ;if bit 0 is set
	sbr r21, 0x01 ;led(1,0) = 1
	
	sbrc r16, 1 ;if bit 1 is set
	sbr r20, 0x01 ;led(0,1) = 1
	
	sbrc r16, 2 ;if bit 2 is set
	sbr r22, 0x01 ;led(1,2) = 1
	
	sbrc r16, 3 ;if bit 3 is set
	sbr r23, 0x01 ;led(2,1) = 1
	
scoreDone:
	;pop r16
	ret
	
randomSeed:
	;this will be called automatically the first time "random" is called
	sbr r24, 0b0000_1000 ;mark that it has been seeded
	sts RNG, r25 ;copy the loop counter to the RNG memory location
	
	;roll 5 times? TODO
	rcall random
	rcall random
	rcall random
	rcall random
	rcall random
	
random:
	;generates a random number into r16
	;when called for the first time, seeds the generator with r25 (loop counter)
	
	sbrs r24, 3 ;if the generator has not been seeded yet
	rjmp randomSeed ;seed the generator
	
	;use a linear feedback shift register (LFSR) algorithm to scramble it
	
	;https://aloriumtech.com/project/random-number-generator/
	;https://aloriumtech.com/wp-content/uploads/2019/09/lfsr-768x322.jpg
	;
	; [7]-[6]-[5]-[4]-[3]-[2]-[1]-[0]<--
	;  |       |   |   |   ___         |
	;  |       |   |   ---)   \        |
	;  |       |   -------)XNOR\.______|
	;  |       -----------)    /
	;  -------------------)___/
	
	lds r16, RNG ;load the RNG value from memory
	mov r17, r16 ;r16 and r17 are both RNG
	lsl r16
	lsl r16 ;bit 7 of r16 is bit 5 of RNG
	eor r17, r16 ;xor bits 7^5 of RNG into bit 7 of r17
	lsl r16 ;bit 7 of r16 is bit 4 of RNG
	eor r17, r16 ;xor bits 7^5^4 of RNG into bit 7 of r17
	lsl r16 ;bit 7 of r16 is bit 3 of RNG
	eor r17, r16 ;xor bits 7^5^4^3 of RNG into bit 7 of r17
	com r17 ;invert to get the XNOR instead of XOR effect
	
	lds r16, RNG ;load the RNG value from memory
	rol r17 ;put bit 7 of r16 into the carry flag
	rol r16 ;put the carry flag into bit 0 of r16 and shift the rest left
	sts RNG, r16 ;store the new value back to memory
	
	ret
	
mod6:
	subi r16, 6
	brsh mod6
	subi r16, -6
	ret
	
	
randomLED:
	rcall clearScreen
	rcall random ;get a random number from 0 to 255
	rcall mod6 ;take the remainder when dividing by 6, so 0 to 5
	lsr r16 ;divide by 2, so 0 to 2
;	mov r17, r16 ;save the result for whoever called this function
	
	subi r16, 0
	breq randomLED0
	dec r16
	breq randomLED1
	
 randomLED2:
	sbr r24, 0x10 ;turn on LED(2,2) sbr to not override button states
	ldi r28, 0b001 ;the bitmask for S
	ret
	
 randomLED1:
	sbr r23, 0x10 ;turn on LED(2,0)
	ldi r28, 0b010 ;the bitmask for R
	ret
	
 randomLED0:
	sbr r20, 0x10 ;turn on LED(0,0)
	ldi r28, 0b100 ;the bitmask for L
	ret
	
	
	
