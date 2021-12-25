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
	ldi r30, high(RAMEND)
	out SPH, r30
	ldi r30, low(RAMEND)
	out SPL, r30
	
	; set clock divider
	ldi r30, 0x00 ; clock divided by 1
	ldi r31, 0xD8 ; the key for CCP
	out CCP, r31 ; Configuration Change Protection, allows protected changes
	out CLKPSR, r30 ; sets the clock divider
	
	; nop for sync
	nop
	
	; REGISTERS
	; r16 gameSelect idx; transition/shortDelay/whackamoleWhileAnyPressed next state
	; r17 memory/whackamole/stacker score
	; r18 current state
	; r19 button just pressed edge detection
	; r20 LED(0,0); LED(0,1)
	; r21 LED(0,2); LED(1,0)
	; r22 LED(1,1); LED(1,2)
	; r23 LED(2,0); LED(2,1)
	; r24 LED(2,2); has RNG been seeded; LRS button states
	; r25 loop counter
	; r26 generalScore next state; memory saved RNG; stacker moving bar
	; r27 transition timer; memory sequence idx; whackamole timer; stacker delay
	; r28 randomLED bitmask; stacker direction of motion
	; r29 system tmp; unused in game logic (could use to save space?)
	; r30 system/game tmp; function arg/return; random value 0-5
	; r31 system/game tmp; function arg/return; random value 0-254
	;
	; MEMORY
	; 0x40 RNG
	; 0x41
	; 0x42
	; 0x43
	; 0x44
	; 0x45
	; 0x46
	; 0x47
	; 0x48
	; 0x49
	; 0x4a
	; 0x4b
	; 0x4c
	; 0x4d
	; 0x4e
	; 0x4f
	; 0x50
	; 0x51
	; 0x52
	; 0x53
	; 0x54
	; 0x55
	; 0x56
	; 0x57
	; 0x58
	; 0x59 stack furthest address (because no more than 3 rcalls are nested)
	; 0x5a
	; 0x5b
	; 0x5c
	; 0x5d
	; 0x5e
	; 0x5f stack starting address
	
	
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
	
	
	;;; TODO ;;;
	
	; FEATURES
	; +button edge detection
	; +dice/score display
	; +pseudorandom generator
	; +dice roll "game"
	; +stacker game
	; +game select
	; +screen transition state
	; +whack-a-mole game
	; +memory game
	; +reaction time game
	; racing game
	; tic-tac-toe
	; blackjack 13
	; maze game
	
	; MORE IDEAS
	; sleep to save battery?
	; vcc level monitoring for low battery detection?
	; implement LED fading?
	; graphics demo?
	; button just released?
	; button debouncing?
	; could vary the delay time for transition for free by ldi r25 instead of clr r25
	; +check for overflow when incrementing each game's score and cap at 128
	
	; CODE GOLFING TO DECREASE PROGRAM SIZE
	; +14 combine into 1 game select state
	; +2 combine static and moving bar
	; +3 combine delay states into 1 with a signal of what state to go to next
	; +13 fix the animation so it doesn't have to save and restore the screen
	; +6 always delay even if the animation is not needed
	; +6 change LED codes to be one-hot
	; +6 remove push/pop in functions if not needed (showScore, fallScreen, random)
	; +3 use slower and more compact mod6 algorithm
	; +2 rewrite random function to retrieve the value from memory multiple times
	; +0 generalize score state for all games
	; +4 don't need to push r30 and r31 between game logic
	; +1 don't need to rjmp statesEnd in the last state
	; +26 for the state machine, use "push r30" then "ret" to manually set the PC to the address of one of the many rjmp instructions in a row
	; +2 compact all the states to remove dead ones
	; +3 might not need stackerFreeze
	; +2 store the next state for generalScore in r26 instead of the stack
	; +2 use r30 and r31 as the tmp registers instead of r16 and r17, then replace the push/ret with an ijmp to Z, aka r16 and r17
	; +5 don't roll 5 times when seeding the RNG (it could loop back to 0 anyway)
	; +1 fillScreen function
	; +2 rearrange register so don't have to push/pop r18, r29 is a new tmp var
	; +1 rearrange stacker delay decrease logic
	; +2 random also does mod6
	; +1 jump directly from stackerInit to stackerMove
	; +1 jump directly from stackerMove to stackerFall
	; +1 optimize randomLED
	; +1 can skip a skip instead of skipping a jump in led
	; +9 used bst and bld to simplify fallScreen
	;TOTAL GOLFED: +118
	;
	; use more bst and bld (e.g. in stacker blinking animation)
	; find ways to use more RAM and decrease program size
	
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;; GAME LOGIC ;;;
	ldi r18, 6 ;current state starts at transition
	ldi r16, 0 ;then it will go to gameSelect
loop:
	;check the state
	
	ldi r30, PC+4 ;4 is the number of lines after this one to jump to for state 0
	add r30, r18 ;plus r18 (the current state)
	ldi r31, 0 ;high byte = 0 since we are (hopefully) in the first 256 instructions
	ijmp ;copy Z (r30 & r31) to PC, which jumps
	
	rjmp gameSelect ;state 0
	rjmp stackerInit ;state 1
	rjmp reactionInit ;state 2
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
	rjmp shortDelay ;state 14
	rjmp stackerFall2 ;state 15
	rjmp whackamoleWhileAnyPressed ;state 16
	rjmp memoryShowBetween ;state 17
	rjmp stackerFell ;state 18
	rjmp reactionWait ;state 19
	rjmp reactionPress ;state 20
	
gameSelect:
	mov r30, r16
	rcall showScore
	
	clr r27 ;clear the timer for the transition
	
	sbrc r19, 2 ;if L was just pressed
	dec r16 ;decrement the selected game
	subi r16, 0 ;if r16 == 0
	breq gameSelectInc ;if r16 == 0: r16++
	
	sbrc r19, 1 ;if R was just pressed
 gameSelectInc:
	inc r16 ;increment the selected game
	
	mov r30, r16
	subi r30, 6
	brne gameSelectNoDec ;if r16 == 6: r16--
	dec r16
 gameSelectNoDec:
	
	
	;limit to 7 maximum and loop around
;	andi r16, 0b111
;	subi r16, 0 ;if r16 == 0
;	breq gameSelectInc ;r16++
	
	sbrc r19, 0 ;if S was just pressed
	ldi r18, 6 ;change state to transition
	;it will go to the selected game next
	
	rjmp statesEnd
	
transition:
	;show dim lights
	ldi r20, 0x22
	rcall fillScreen
	sbr r24, 0x20 ;avoid messing up the seeding and buttons
	
	inc r27 ;increment the timer
	sbrs r27, 5 ;if bit 5 in the timer is 1 (it has been 1/2 second)
	rjmp statesEnd
	
	mov r18, r16 ;move to whatever next state was specified in r16
	ldi r16, 1 ;set r16 to 1 in case we are going back to gameSelect
	rcall clearScreen ;clear the screen to prepare for the next state
	
	rjmp statesEnd
	
reactionInit:
	rcall random
	mov r25, r31
	ldi r18, 19 ;change state to reactionWait
	rjmp statesEnd
	
reactionWait:
	subi r25, 0 ;if the random timer is up
	brne reactionWaitEnd
	
	sbr r22, 0x10 ;turn on LED(1,1)
	
	ldi r17, 65 ;allow 1 second to press it
	ldi r18, 20 ;change state to reactionPress
 reactionWaitEnd:
	rjmp statesEnd
	
reactionPress:
	dec r17 ;decrease the score
	breq reactionPressGameOver ;if the score is 0 (4 sec has passed), end the game
	sbrs r19, 0 ;if S pressed
	rjmp statesEnd

 reactionPressGameOver:
	
	lsr r17 ;divide score by 2
	lsr r17 ;divide score by 2
	clr r27 ;clear the timer for the transition
	ldi r18, 6 ;change state to transition
	ldi r16, 12 ;after that, change state to generalScore
	ldi r26, 2 ;finally, it will be memoryInit
	
	rjmp statesEnd
	
memoryInit:
	rcall random ;make sure the RNG is seeded, now we can use r25 after
	mov r26, r31 ;store the first number in the sequence so it can be recreated
	
	ldi r17, 1 ;the score (length of the memory sequence)
	;it is 1 higher than the actual number of presses
	ldi r27, 1 ;the number of items left in the current sequence
	
	clr r25 ;reset the timer
	ldi r18, 14 ;change state to shortDelay
	ldi r16, 7 ;then change state to memoryShow
	rjmp statesEnd
	
memoryShow:
	rcall randomLED
	clr r25 ;reset the timer
	ldi r18, 14 ;change state to shortDelay
	ldi r16, 17 ;then change state to memoryShowBetween
	rjmp statesEnd

memoryShowBetween:
	clr r25 ;reset the timer
	ldi r18, 14 ;change state to shortDelay
	ldi r16, 7 ;then change state to memoryShow
	
	rcall clearScreen
	
	dec r27 ;decrement sequence index
	brne memoryShowBetweenEnd ;if the sequence is done showing
	
	sts RNG, r26 ;store the original random value back to the RNG to start over
	mov r27, r17 ;reset the sequence index to the sequence length (score)
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
		
	dec r27 ;decrement sequence index
	brne memoryPressEnd ;if the sequence is done being entered
	
	sts RNG, r26 ;store the original random value back to the RNG to start over
	clr r25 ;reset the timer
	ldi r18, 14 ;change state to shortDelay
	ldi r16, 7 ;then change state to memoryShow
	rcall incScore ;increase the score by 1 (the sequence length will also increase)
	mov r27, r17 ;reset the sequence index to the sequence length (score)

 memoryPressEnd:
	rjmp statesEnd
	
 memoryPressGameOver:
 	;exhaust the rest of the RNG sequence
	rcall random
 	dec r27
 	brne memoryPressGameOver
 	
;	dec r17 ;decrease the score by 1 to account for the extra one at the start
	lsr r17 ;divide score by 2
	clr r27 ;clear the timer for the transition
	ldi r18, 6 ;change state to transition
	ldi r16, 12 ;after that, change state to generalScore
	ldi r26, 3 ;finally, it will be memoryInit
	rjmp statesEnd
	
whackamoleInit:
	clr r27 ;clear the loop counter, when it reaches 255 (4 sec) the game is over
	ldi r17, 0 ;score (number of moles hit)

	ldi r18, 9 ;change state to whackamoleMole
	rjmp statesEnd
	
whackamoleMole:
	ldi r18, 10 ;change state to whackamoleWait
	rcall randomLED
	
whackamoleWait:
	inc r27 ;increment the timer
	breq whackamoleTimeUp
	
 whackamoleWaitTimeLeft:
	subi r19, 0
	breq whackamoleWaitingStill ;if any button was just pressed:
	mov r30, r28 ;copy the bitmask
	and r30, r19 ;see if the correct button was just pressed
	breq whackamoleWaitWrongButton
	rcall incScore ;add 1 to the score
	rcall clearScreen
	ldi r18, 16 ;change state to whackamoleWhileAnyPressed
	ldi r16, 9 ;after that, change state to whackamoleMole
	rjmp statesEnd
	
 whackamoleWaitWrongButton:
	subi r17, 0 ;if score is already 0
	breq whackamoleWaitingStill ;don't decrement
	
	dec r17 ;decrease the score because the wrong button was pressed
	
 whackamoleWaitingStill:
	rjmp statesEnd
	
 whackamoleTimeUp:
;	lsr r17 ;divide score by 2
	;timer is already cleared for the transition
	ldi r18, 6 ;change state to transition
	ldi r16, 12 ;after that, change state to generalScore
	ldi r26, 4 ;finally, it will be whackamoleInit
	rjmp statesEnd
	
whackamoleWhileAnyPressed:
	inc r27 ;increment the timer
	breq whackamoleTimeUp
	
;whileAnyPressed:
	mov r30, r24
	cbr r30, 0b1111_1000
	subi r30, 0 ;if any button is pressed
	brne statesEnd2 ;do nothing
	;otherwise:
	mov r18, r16 ;move to whatever next state was specified in r16
	rjmp statesEnd
	
diceRoller:
	;sbrc r19, 0 ;if S just pressed
	;rcall clearScreen ;clear the screen
	
	sbrc r19, 2 ;if L was just pressed, run the next line
	ldi r18, 6 ;change state to transition
	ldi r16, 0 ;after that the state will be gameSelect
	clr r27	;clear the timer for the transition state
	
	rcall random ;get a random number from 0 to 254
;	rcall mod6 ;take the remainder when dividing by 6, so 0 to 5
	inc r30 ;add 1, so 1 to 6
	
	sbrc r19, 1 ;if R just pressed, skip next line
	rcall showScore ;display it as a dice number on the LEDs
	
	rjmp statesEnd
	
stackerInit:
	;turn on the bottom 2 rows of LEDs, and the top left LED
	ldi r20, 0x11
	ldi r21, 0x10
	rcall helpFillScreen
	sbr r24, 0x10 ;avoid messing up the seeding and buttons
	
	clr r25             ;clear the loop counter for consistent movement
	ldi r26, 0b01110000 ;the moving top row
	ldi r28, 1          ;the direction of motion (1 = >>, 0 = <<)
	ldi r27, 13         ;the delay between movements (next: 13-2)
	ldi r17, 0          ;the score (number of times the button was pressed, minus 1)
	
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
	
	;fall thru to the next state on purpose
;	rjmp statesEnd

stackerMove:
	sbrc r19, 0 ;if S was just pressed, run the next line
	rjmp stackerFall
	
	mov r30, r25
	sub r30, r27 ;check if the delay has elapsed yet
	brne statesEnd2
	clr r25
	
	
	sbrc r28, 0 ;if r28 = 1 (moving right)
	lsr r26
	
	sbrs r28, 0 ;if r28 = 0 (moving left)
	lsl r26
	
	;bits 4, 3, and 2 of r26 are the top row
	rcall clearTopRow
		
	sbrc r26, 4   ;if bit 4 is set
	sbr r20, 0x10 ;light up LED 0,0
	sbrc r26, 3   ;if bit 4 is set
	sbr r21, 0x01 ;light up LED 1,0
	sbrc r26, 2   ;if bit 4 is set
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
	ldi r18, 13 ;make sure to change state to stackerFall since it jumped here
	;save the screen for later so it isn't ruined by the animations
	;push r20
	;push r21
	;push r22
	;push r23
	;push r24
	
	;ldi r30, 0 ;keep track of if any are blinking
	
	;whichever ones should fall, make them blink
	sbrc r20, 0   ;if LED(0,1)==0
	rjmp stackerFallCol1Done
	sbrs r20, 4   ;and LED(0,0)==1
	rjmp stackerFallCol1Done
	cbr r20, 0xf0 ;clear LED(0,0)
	sbr r20, 0x40 ;set LED(0,0) to blink
	;ldi r30, 1    ;mark that at least 1 is blinking
 stackerFallCol1Done:
	
	sbrc r22, 4   ;if LED(1,1)==0
	rjmp stackerFallCol2Done
	sbrs r21, 0   ;and LED(1,0)==1
	rjmp stackerFallCol2Done
	cbr r21, 0x0f ;clear LED(1,0)
	sbr r21, 0x04 ;set LED(1,0) to blink
	;ldi r30, 1    ;mark that at least 1 is blinking
 stackerFallCol2Done:
	
	sbrc r23, 0   ;if LED(2,1)==0
	rjmp stackerFallCol3Done
	sbrs r23, 4   ;and LED(2,0)==1
	rjmp stackerFallCol3Done
	cbr r23, 0xf0 ;clear LED(2,0)
	sbr r23, 0x40 ;set LED(2,0) to blink
	;ldi r30, 1    ;mark that at least 1 is blinking
 stackerFallCol3Done:
	
	clr r25 ;clear the counter to start the next state's timer at 0
	ldi r18, 14 ;change state to shortDelay
	ldi r16, 15 ;change state to stackerFall2 after that
	
	;if none are blinking, skip the entire rest of the animation
	;sbrs r30, 0 ;if r30 == 0
	;ldi r18, 18 ;change state to stackerFell
	
	rjmp statesEnd
	
shortDelay:
	sbrc r25, 5 ;if bit 5 in the counter is 1, it has been 1/2 second so:
	mov r18, r16 ;move to whatever next state was specified in r16
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
	
	ldi r18, 14 ;change state to shortDelay
	ldi r16, 18 ;change state to stackerFell next
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
	cbr r20, 0b0000_0100 ;clear LED(0,1)'s "blinking" bit
	cbr r22, 0b0100_0000 ;clear LED(1,1)'s "blinking" bit
	cbr r23, 0b0000_0100 ;clear LED(2,1)'s "blinking" bit
	
	clr r26 ;reset the moving bar
	
	;recalculate the width of the moving bar
	sbrc r20, 4   ;if LED(0,0)==1
	sbr r26, 0b100
	
	sbrc r21, 0   ;if LED(1,0)==1
	sbr r26, 0b010
	
	sbrc r23, 4   ;if LED(2,0)==1
	sbr r26, 0b001
	
	;r26 can be 000, 001, 011, 111, 110, 100
	;for the last 2, it needs to be shifted over
	sbrs r26, 0 ;if the final bit is 0
	lsr r26     ;shift right
	sbrs r26, 0 ;if the final bit is 0
	lsr r26     ;shift right
	
	;if the game is over
	subi r26, 0
	brne stackerFellGameContinue
	
;	ldi r18, 12 ;could go directly to generalScore and remove the next 3 lines
	
	clr r27 ;clear the timer for the transition
	ldi r18, 6 ;change state to transition
	ldi r16, 12 ;after that, change state to generalScore
	ldi r26, 1 ;finally, it will be stackerInit
	
	rjmp statesEnd
	
 stackerFellGameContinue:
	rcall fallScreen
	
	;on every other one, go backwards
	sbrs r17, 0   ;if bit 0 of the score is 1
	rjmp stackerFellBackwards
	sbr r20, 0x10 ;set the top left LED to be on
	swap r26      ;move the row to the left side
	ldi r28, 1    ;set the motion direction to be >>
	rjmp stackerFellBackwardsAfter
	
 stackerFellBackwards:
	ldi r28, 0    ;set the motion direction to be <<
	sbr r23, 0x10 ;set the top right LED to be on
	;shift the 111, 011, or 001 to be 111, 110, or 100
	sbrs r26, 2 ;if the 2nd bit is 0
	lsl r26     ;shift left
	sbrs r26, 2 ;if the 2nd bit is 0
	lsl r26     ;shift left
	
 stackerFellBackwardsAfter:
	
	clr r25 ;clear the loop counter for consistent movement
	rcall incScore ;increment the score
	
	ldi r18, 11 ;change state to stackerMove
	
	mov r30, r17
	subi r30, 3 ;if score < 3
	brsh stackerFellAfterExtraDelay
	dec r27 ;decrease the delay
 stackerFellAfterExtraDelay:
	mov r30, r17
	subi r30, 9 ;if score < 9
	brsh stackerFellAfterExtraDelay2
	dec r27 ;decrease the delay
 stackerFellAfterExtraDelay2:
	subi r30, 2 ;if score-9 == 2 (aka score == 11)
	brne stackerFellAfterExtraDelay3
	dec r27 ;decrease the delay
 stackerFellAfterExtraDelay3:
	subi r30, 3 ;if score-9-2 == 3 (aka score == 14)
	brne statesEnd
	dec r27 ;decrease the delay
	
	rjmp statesEnd
	
generalScore:
	mov r30, r17
	rcall showScore
	cbr r19, 0b0000_0001 ;disregard S
	subi r19, 0 ;if any button was pressed
	breq statesEnd
	
	;either L or R was pressed
	clr r27	;clear the timer for the transition state
	ldi r18, 6 ;change state to transition
	mov r16, r26 ;after that the state will be whatever was given unless
	sbrc r19, 2 ;if L was just pressed
	ldi r16, 0 ;after that the state will be gameSelect
	
	
statesEnd:
	;;; UPDATE IO ;;;
	
	
	mov r19, r24 ;copy current button values to know prev for edge detection
	cbr r24, 0b0000_0111 ;clear the button state bits
	ldi r29, 0b0000_0100 ;bit mask for PB2 (L button) and r24 button states
	;will be shifted right to get PB1, then PB0, and to write to a different r24 bit

buttonLoop:
	out DDRB, r29 ;set the current pin to output
	ldi r30, 0x00
	out PORTB, r30 ;set all pins low
	rcall buttonDelay
	sbis PINB, PB3 ;skip the next line if PB3 is 1
	or r24, r29 ;set the button's bit to 1

	lsr r29 ;shift the bitmask to set a different pin as an output
	subi r29, 0 ;check if the shift fell off the end, which means we are done
	brne buttonLoop ;keep going until no pin is selected
	
	;button edge detection (just pressed)
	;just = !prev && curr
	;r19 = !r19 & r24L
	
	com r19 ;invert all bits to create !prev instead of prev
	and r19, r24 ;preform the "and" to get "just pressed"
	cbr r19, 0b1111_1000 ;clear the unused bits in r19 for predictability
	
	;0,0
	mov r30, r20 ;copy the LED's register to r30
	swap r30 ;swap the low and high nybble
	ldi r31, 1<<PB3 | 1<<PB2 ;indicate the outputs
	ldi r29, 1<<PB2 ;indicate which outputs should be high
	rcall led

	;0,1
	mov r30, r20 ;copy the LED's register to r30
	ldi r31, 1<<PB3 | 1<<PB1 ;indicate the outputs
	ldi r29, 1<<PB1 ;indicate which output should be high
	rcall led

	;0,2
	mov r30, r21 ;copy the LED's register to r30
	swap r30 ;swap the low and high nybble
	ldi r31, 1<<PB3 | 1<<PB0 ;indicate the outputs
	ldi r29, 1<<PB0 ;indicate which outputs should be high
	rcall led

	;1,0
	mov r30, r21 ;copy the LED's register to r30
	ldi r31, 1<<PB1 | 1<<PB2 ;indicate the outputs
	ldi r29, 1<<PB1 ;indicate which output should be high
	rcall led

	;1,1
	mov r30, r22 ;copy the LED's register to r30
	swap r30 ;swap the low and high nybble
	ldi r31, 1<<PB1 | 1<<PB2 ;indicate the outputs
	ldi r29, 1<<PB2 ;indicate which outputs should be high
	rcall led

	;1,2
	mov r30, r22 ;copy the LED's register to r30
	ldi r31, 1<<PB0 | 1<<PB2 ;indicate the outputs
	ldi r29, 1<<PB2 ;indicate which output should be high
	rcall led

	;2,0
	mov r30, r23 ;copy the LED's register to r30
	swap r30 ;swap the low and high nybble
	ldi r31, 1<<PB0 | 1<<PB2 ;indicate the outputs
	ldi r29, 1<<PB0 ;indicate which outputs should be high
	rcall led

	;2,1
	mov r30, r23 ;copy the LED's register to r30
	ldi r31, 1<<PB0 | 1<<PB1 ;indicate the outputs
	ldi r29, 1<<PB0 ;indicate which output should be high
	rcall led

	;2,2
	mov r30, r24 ;copy the LED's register to r30
	swap r30 ;swap the low and high nybble
	ldi r31, 1<<PB0 | 1<<PB1 ;indicate the outputs
	ldi r29, 1<<PB1 ;indicate which outputs should be high
	rcall led
	
	
	ldi r30, 0x00 ;set everything as inputs
	out DDRB, r30
	
	inc r25 ;increment the loop counter
	rjmp loop
	
	
	;;; FUNCTIONS ;;;
	
led:
	out DDRB, r31 ;set the outputs
	ldi r31, 0x00
	out PORTB, r31 ;turn the LED off to start
	
	;r30 should be set up with the low nybble being the one to use, doing "swap" if needed
	;if bit 0 is set, turn it on solid
	sbrc r30, 0
	rjmp ledOn
	;if bit 1 is set, turn it dim
	sbrc r30, 1
	rjmp ledDim
	;if bit 2 is set, make it blink (otherwise turn it off
	sbrc r30, 2 ;this is skipping the next skip, therefore going to ledOff
ledBlink:
	sbrc r25, 2 ;skip if a bit in the loop counter is cleared
	rjmp ledOff
	
	; bit   blinking speed
	;  0 => 1/32 second cycle
	;  1 => 1/16 second cycle
	;  2 => 1/8 second cycle
	;  3 => 1/4 second cycle
	;  4 => 1/2 second cycle
	;  5 => 1 second cycle
	;  6 => 2 second cycle
	;  7 => 4 second cycle
ledOn:
	;r29 is which output to set to high
	out PORTB, r29 ;turn on the LED
ledOff:
	rcall ledDelay ;delay either way
	ret
ledDim:
	rcall ledDelay
	out PORTB, r29 ;turn on the LED
	ldi r30, 0x40
	ldi r31, 0x00
	rcall delayLoop
	ret


	
	
	
buttonDelay:
	ldi r31, 0x0b ;lower starts to not work
	rjmp delay

ledDelay:
	ldi r31, 0x08
;;;	rjmp delay

delay:
	ldi r30, 0xff
delayLoop:
	subi r30, 1 ; subtract 1
	sbci r31, 0 ; if r30 was 0, subtract 1
	brne delayLoop ; while r31 is not 0, loop
	ret

;;; x=0x40 (r30)
;;; y=0x00 (r31)
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


fillScreen:
	mov r21, r20
helpFillScreen:
	mov r22, r20
	mov r23, r21
	swap r23
	cbr r24, 0xf0 ;clear high nybble without disrupting low nybble (buttons)
	ret
	
clearScreen:
	clr r20
	rcall fillScreen
	ret
	
;maskLowAndSwap:
;	andi r30, 0x0f ;get only the low nybble
;	swap ;move the low nybble to the high one
;	ret
	
fallScreen:
	;shift all pixels on the screen down by 1, replacing the top row with blank
	;NOTE: only works for solidly on pixels, not blinking or dim
	
	;copy the middle row to the bottom (preserving the top, but not the middle)
	;r21H <- r20L   0,2 <- 0,1
;	cbr r21, 0xf0  ;clear r21H (the destination)
;	mov r30, r20   ;copy r20 so we can modify it
;	andi r30, 0x0f ;get only r20L
;	swap r30       ;move r20L to r30H
;	or r21, r30    ;copy what was r20L to r21H
	bst r20, 0 ;copy from LED(0,1) into T
	bld r21, 4 ;copy T into LED(0,2) 
	
	;r22L <- r22H   1,2 <- 1,1
	swap r22       ;just swap the nybbles (messing up the middle, but it's OK)
	
	;r24H <- r23L   2,2 <- 2,1
;	cbr r24, 0xf0  ;clear r24H (the destination)
;	mov r30, r23   ;copy r23 so we can modify it
;	andi r30, 0x0f ;get only r23L
;	swap r30       ;move r23L to r30H
;	or r24, r30    ;copy what was r23L to r24H
	bst r23, 0 ;copy from LED(2,1) into T
	bld r24, 4 ;copy T into LED(2,2) 
	
	
	;copy the top row to the middle (preserving the bottom, but not the top)
	;r20L <- r20H   0,1 <- 0,0
	swap r20       ;just swap the nybbles (messing up the top, but it's OK)
	
	;r22H <- r21L   1,1 <- 1,0
;	cbr r22, 0xf0  ;clear r22H (the destination)
;	mov r30, r21   ;copy r21 so we can modify it
;	andi r30, 0x0f ;get only r21L
;	swap r30       ;move r21L to r30H
;	or r22, r30    ;copy what was r21L to r22H
	bst r21, 0 ;copy from LED(1,0) into T
	bld r22, 4 ;copy T into LED(1,1) 
	
	;r23L <- r23H   2,1 <- 2,0
	swap r23       ;just swap the nybbles (messing up the top, but it's OK)
	
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
	
	;r30 is the score
	;push r30
	subi r30, 10 ;if score >= 10
	brsh scoreMore ;holy BRSH! go to the higher number scores
	subi r30, -10 ;add the 10 back
	
	sbrc r30, 0 ;if bit 0 in the score is 1
	sbr r22, 0x10 ;led(1,1) = 1
	
	subi r30, 2
	brlo scoreDone
	; if score >= 2
	sbr r20, 0x10 ;led(0,0) = 1
	sbr r24, 0x10 ;led(2,2) = 1
	
	subi r30, 2
	brlo scoreDone
	; if score >= 4
	sbr r21, 0x10 ;led(0,2) = 1
	sbr r23, 0x10 ;led(2,0) = 1
	
	subi r30, 2
	brlo scoreDone
	; if score >= 6
	sbr r20, 0x01 ;led(0,1) = 1
	sbr r23, 0x01 ;led(2,1) = 1
	
	subi r30, 2
	brlo scoreDone
	; if score >= 8
	sbr r21, 0x01 ;led(1,0) = 1
	sbr r22, 0x01 ;led(1,2) = 1
	
	rjmp scoreDone
	
scoreMore:
	;r30 starts as score-10
	subi r30, 15 ;if score-10 < 15 aka if score < 25
	brlo score24
	sbr r22, 0x10 ;led(1,1) = 1
	ldi r30, -1 ;set score-25 to -1, aka score = 24
	
score24:
	;r30 starts as score-25
	subi r30, -16 ;r30 is now score-9
	
	sbrc r30, 0 ;if bit 0 is set
	sbr r21, 0x01 ;led(1,0) = 1
	
	sbrc r30, 1 ;if bit 1 is set
	sbr r20, 0x01 ;led(0,1) = 1
	
	sbrc r30, 2 ;if bit 2 is set
	sbr r22, 0x01 ;led(1,2) = 1
	
	sbrc r30, 3 ;if bit 3 is set
	sbr r23, 0x01 ;led(2,1) = 1
	
scoreDone:
	;pop r30
	ret
	
	
incScore:
	sbrs r17, 7 ;if the score is already 128, no need to increase
	inc r17
	ret
	
randomSeed:
	;this will be called automatically the first time "random" is called
	sbr r24, 0b0000_1000 ;mark that it has been seeded
	
;	ldi r25, 255 ;testing
;	ldi r25, 0 ;testing
	
	inc r25 ;if r25 was 255 (now 0)
	brne randomSeedNot255
	inc r25 ;add 1 (now 1)
 randomSeedNot255:
	dec r25 ;(now 0 to 254)
	
;	ldi r25, 255 ;testing
;	ldi r25, 0 ;testing
	sts RNG, r25 ;copy the loop counter to the RNG memory location
	
random:
	;generates a random number from 0 to 254 into r30
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
	
	lds r30, RNG ;load the RNG value from memory
	mov r31, r30 ;r30 and r31 are both RNG
	lsl r30
	lsl r30 ;bit 7 of r30 is bit 5 of RNG
	eor r31, r30 ;xor bits 7^5 of RNG into bit 7 of r31
	lsl r30 ;bit 7 of r30 is bit 4 of RNG
	eor r31, r30 ;xor bits 7^5^4 of RNG into bit 7 of r31
	lsl r30 ;bit 7 of r30 is bit 3 of RNG
	eor r31, r30 ;xor bits 7^5^4^3 of RNG into bit 7 of r31
	com r31 ;invert to get the XNOR instead of XOR effect
	
	lds r30, RNG ;load the RNG value from memory
	rol r31 ;put bit 7 of r30 into the carry flag
	rol r30 ;put the carry flag into bit 0 of r30 and shift the rest left
	sts RNG, r30 ;store the new value back to memory
	
	mov r31, r30 ;copy the full value to r31, r30 will be the mod6 value
	;falling thru to the next function is intentional
mod6:
	subi r30, 6
	brsh mod6
	subi r30, -6
	ret
	
	
randomLED:
	rcall clearScreen
	rcall random ;get a random number from 0 to 254
;	rcall mod6 ;take the remainder when dividing by 6, so 0 to 5
;	lsr r30 ;divide by 2, so 0 to 2
	
	; 0  1  2  3  4  5
	subi r30, 2
	;-2 -1  0  1  2  3
	brlo randomLED1
	subi r30, 2
	;      -2 -1  0  1
	brlo randomLED2
	
;	dec r30
;	breq randomLED1
;	dec r30
;	breq randomLED2
	
 randomLED0:
	sbr r20, 0x10 ;turn on LED(0,0)
	ldi r28, 0b100 ;the bitmask for L
	ret
	
 randomLED1:
	sbr r23, 0x10 ;turn on LED(2,0)
	ldi r28, 0b010 ;the bitmask for R
	ret
	
 randomLED2:
	sbr r24, 0x10 ;turn on LED(2,2) sbr to not override button states
	ldi r28, 0b001 ;the bitmask for S
	ret
	
	
	
