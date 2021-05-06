; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 440 Hz square wave at pin P3.7 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'BOOT' pushbutton connected to P3.7 is pressed.
$NOLIST
$MODEFM8LB1
$LIST

CLK           EQU 24000000 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 2000*2    ; The tone we want out is A mayor.  Interrupt rate must be twice as fast.
TIMER0_RELOAD EQU ((65536-(CLK/(TIMER0_RATE))))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/(TIMER2_RATE))))

BOOT_BUTTON   equ P3.7
SOUND_OUT     equ P2.1
UPDOWN        equ P0.0
alarm_button  equ P0.3
pause_button  equ P3.2
hour_button equ P2.6
min_button equ P2.4
sec_button equ P2.2

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed
BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
hours:   ds 1 
mins:    ds 1 
secs:    ds 1 
asecond: ds 1 
amins:   ds 1
ahours:  ds 1 
temp1:   ds 1
temp2:   ds 1 

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed
minutes_flag: dbit 1 
hours_flag: dbit 1
pm_am_flag: dbit 1
alarm_pa_flag: dbit 1
temp1_flag: dbit 1
temp2_flag: dbit 1
alarm_flag: dbit 1 
check_signal: dbit 1 
cseg
; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P2.0
LCD_RW equ P1.7
LCD_E  equ P1.6
LCD_D4 equ P1.1
LCD_D5 equ P1.0
LCD_D6 equ P0.7
LCD_D7 equ P0.6
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db ' xx:xx:xx AM WED ', 0
Alarm_Message:    db 'ALARM XX:XX:XXAM  ', 0 
AM_message:       db 'AM  ', 0
PM_message:       db 'PM ' , 0         
;-----------------------------------;
; Routine to initialize the timer 0 ;
;-----------------------------------;
Timer0_Init:
	orl CKCON0, #00000100B ; Timer 0 uses the system clock
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	
	mov a, secs
	anl a, asecond    ; and asecond and seconds 
	mov check_signal,a
	jnb  check_signal, done3
check_mins:
	mov a, mins 
	anl a, amins
	mov check_signal, a 
	jnb check_signal, done3
check_hours: 
   mov a, hours 
   anl a, ahours 
   mov check_signal, a 
   jnb check_signal, done3

   mov c, alarm_pa_flag
   orl c, pm_am_flag 
   mov check_signal, a 
   jb  check_signal, sound_alarm
   mov c, alarm_pa_flag
   orl c, pm_am_flag
   mov check_signal, c
   jnb check_signal, sound_alarm
   sjmp done3
 sound_alarm:
 done3:
 ret 


;---------------------------------;
; ISR for timer 0.                ;
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	; Timer 0 can not autoreload so we need to reload it in the ISR:
	clr TR0
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	setb TR0
	cpl SOUND_OUT ; Toggle the pin connected to the speaker
	reti

;---------------------------------;
; Routine to initialize timer 2   ;
;---------------------------------;
Timer2_Init:
	orl CKCON0, #0b00010000 ; Timer 2 uses the system clock
	mov TMR2CN0, #0 ; Stop timer/counter.  Autoreload mode.
	mov TMR2H, #high(TIMER2_RELOAD)
	mov TMR2L, #low(TIMER2_RELOAD)
	; Set the reload value
	mov TMR2RLH, #high(TIMER2_RELOAD)
	mov TMR2RLL, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2H  ; Timer 2 doesn't clear TF2H automatically. Do it in ISR
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if half second has passed
	mov a, Count1ms+0
	cjne a, #low(500), mid_jump ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(500), mid_jump
	
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb seconds_flag ; Let the main program know half second had passed
	cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	setb SOUND_OUT
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Increment the BCD counter
	mov a, secs
	cjne a , #0x59, not_minute
	setb minutes_flag;
	clr a
	mov secs, a
	mov a, mins 
	
	cjne a, #0x59, not_hour 
	setb hours_flag 
	clr a
	mov mins,  a
	mov a, hours 
	cjne a, #0x11, no_switch_ampm
	cpl pm_am_flag

no_switch_ampm:
  cjne a, #0x12, no_hour_reset
  mov a, #0x00 
no_hour_reset:
 add a, #0x01
 da a 
 mov hours,a 
 sjmp finish 
mid_jump:
sjmp Timer2_ISR_done

not_minute:

jnb UPDOWN, Timer2_ISR_decrement
add a, #0x01
	da a
	mov secs, a
	sjmp finish

not_hour:
mov a, mins
	add a, #0x01
	da a
	mov mins, a
finish:
 sjmp Timer2_ISR_da


Timer2_ISR_decrement:
	mov a, secs
	subb a, #0x01
	da a
	mov secs, a
Timer2_ISR_da:
	clr a
	
Timer2_ISR_done:
	pop psw
	pop acc
	reti
add_hour:
   mov a, hours 
   cjne a, #0x11, no_change_ampm
   cpl pm_am_flag

no_change_ampm:
   cjne a, #0x12, no_hour_reset2
   mov a, #00H

no_hour_reset2:
  add a, #0x01
  da a 
  mov hours, a 
  ret 

add_minute :
  mov a, mins 
  cjne a, #0x59, no_reset_minute
  mov a , #0x00
  sjmp doneminutes

 no_reset_minute:
  add a, #0x01

doneminutes:
  da a 
  mov mins, a
  ret

add_second:
  mov a , secs 
  cjne a, #0x59, no_reset_second
  mov a , #0x00
  sjmp donesecond

no_reset_second:
 add a, #0x01 

donesecond:
 da a 
 mov secs, a
 ret

 aadd_hour:
  mov a ,hours
  cjne a, #0x11, anot_change_ampm
  cpl alarm_pa_flag

anot_change_ampm:
cjne a, #0x12, ano_hour_reset2
mov a, #0x00

ano_hour_reset2:
  add a, #0x01
  da a
   mov ahours, a
   ret 

aadd_minute:
 mov a, amins
 cjne a, #0x59, anot_reset_minute 
 mov a, #0x00
 sjmp adonem

anot_reset_minute:
 add a, #0x01

 adonem:
  da a
  mov amins, a
  ret
aadd_second:
   mov a, asecond 
   cjne a , #0x59, anot_reset_second
   mov a ,#0x00 
   sjmp adones 
anot_reset_second:
 add a, #0x01

 adones:
   da a 
   mov asecond, a 
   ret 

  display:
      clr seconds_flag
	  clr minutes_flag
	  clr hours_flag 
	  mov BCD_counter, secs 
	  Set_Cursor(1,8)
	 Display_BCD(BCD_counter) ; This macro is also in 'LCD_4bit.inc'
	mov BCD_counter, mins
	Set_Cursor(1, 5)
	Display_BCD(BCD_counter)
	mov BCD_counter, hours
	Set_Cursor(1, 2)
	Display_BCD(BCD_counter)
	jnb pm_am_flag, print_AM
    Set_Cursor(1,11)
    Display_char(#'P')
	sjmp alarm_display
	
print_AM:
    Set_Cursor(1,11)
    Display_char(#'A')
alarm_display:
	mov BCD_counter, asecond
	Set_Cursor(2, 13)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(BCD_counter) ; This macro is also in 'LCD_4bit.inc'
	mov BCD_counter, amins
	Set_Cursor(2, 10)
	Display_BCD(BCD_counter)
	mov BCD_counter, ahours
	Set_Cursor(2, 7)
	Display_BCD(BCD_counter)
	jnb alarm_pa_flag, print_AM2
    Set_Cursor(2, 15)
    Display_char(#'P')
	sjmp done_display
print_AM2:
    Set_Cursor(2, 15)
    Display_char(#'A')
done_display:
	ret




;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    ; DISABLE WDT: provide Watchdog disable keys
	mov	WDTCN,#0xDE ; First key
	mov	WDTCN,#0xAD ; Second key

    ; Enable crossbar and weak pull-ups
	mov	XBR0,#0x00
	mov	XBR1,#0x00
	mov	XBR2,#0x40

	mov	P2MDOUT,#0x02 ; make sound output pin (P2.1) push-pull
	
	; Switch clock to 24 MHz
	mov	CLKSEL, #0x00 ; 
	mov	CLKSEL, #0x00 ; Second write to CLKSEL is required according to the user manual (page 77)
	
	; Wait for 24 MHz clock to stabilze by checking bit DIVRDY in CLKSEL
waitclockstable:
	mov a, CLKSEL
	jnb acc.7, waitclockstable 

	; Initialize the two timers used in this program
    lcall Timer0_Init
    lcall Timer2_Init

    lcall LCD_4BIT ; Initialize LCD
    
    setb EA   ; Enable Global interrupts

	ret

;---------------------------------;
; Main program.                   ;
;---------------------------------;
main:
	; Setup the stack start to the begining of memory only accesible with pointers
    mov SP, #7FH
    
	lcall Initialize_All
	
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
     Set_Cursor(2, 1)
    Send_Constant_String(#Alarm_Message)
	  clr alarm_flag
    setb pm_am_flag
    setb seconds_flag
    setb minutes_flag
    setb hours_flag
	mov BCD_counter, #0x000
	; After initialization the program stays in this 'forever' loop


loop:
   jb pause_button, alarm_loop  ; if the 'BOOT' button is not pressed skip
  Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
  jb pause_button, alarm_loop  ; if the 'BOOT' button is not pressed skip
	jnb pause_button, $
	cpl TR2

alarm_loop:
	jb alarm_button, alarm_set   ; if the 'BOOT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb alarm_button, alarm_set  ; if the 'BOOT' button is not pressed skip
	jnb alarm_button, $
	cpl alarm_flag

recheck:
	jb alarm_button, acheck_hours   ; if the 'BOOT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb alarm_button, acheck_hours  ; if the 'BOOT' button is not pressed skip
	jnb alarm_button, $
	cpl alarm_flag

acheck_hours:
	jb hour_button, ano_hour  ; 
	Wait_Milli_Seconds(#50)	; 
	jb hour_button, ano_hour ; 
	jnb hour_button, $
	lcall aadd_hour
	lcall display

ano_hour:
	jb min_button, ano_minute ; if the 'BOOT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb min_button, ano_minute ; if the 'BOOT' button is not pressed skip
	jnb min_button, $
	lcall aadd_minute
	lcall display

ano_minute:
	jb sec_button, loop_alarm  ; 
	Wait_Milli_Seconds(#50)	; 
	jb sec_button, loop_alarm  ; 
	jnb sec_button, $
	lcall aadd_second
	lcall display
loop_alarm:
	jb alarm_flag, recheck

alarm_set:
	jb hour_button, no_hour_changed  ; 
	Wait_Milli_Seconds(#50)	; Debounce delay.  
	jb hour_button, no_hour_changed  ;
	jnb hour_button, $
	lcall add_hour
	lcall display

no_hour_changed:
	jb min_button, no_minute_changed 
	Wait_Milli_Seconds(#50)	
	jb min_button, no_minute_changed  
	jnb min_button, $
	lcall add_minute
	lcall display

no_minute_changed:
	jb sec_button, return_clock  
	Wait_Milli_Seconds(#50)	; Debounce delay. 
	jb sec_button, return_clock 
	jnb sec_button, $
	lcall add_second
	lcall display



return_clock: 
	jb BOOT_BUTTON, pause_loop  ; if the 'BOOT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb BOOT_BUTTON, pause_loop  ; if the 'BOOT' button is not pressed skip
	jnb BOOT_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
	; A valid press of the 'BOOT' button has been detected, reset the BCD counter.
	; But first stop timer 2 and reset the milli-seconds counter, to resync everything.
	clr TR2                 ; Stop timer 2
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Now clear the BCD counter
	mov BCD_counter, #0x00
	mov secs, #0x00
	mov mins, #0x00
	mov hours, #0x11
	mov asecond, #0x00
	mov amins, #0x00
	mov ahours, #0x00
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    Set_Cursor(2, 1)
    Send_Constant_String(#Alarm_Message)
    clr pm_am_flag
	clr alarm_pa_flag
	clr alarm_flag
	setb TR2                ; Start timer 2
	lcall display
pause_loop:
	lcall display
    ljmp loop
END