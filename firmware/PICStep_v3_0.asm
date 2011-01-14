; PICStep v3.0 Firmware - PIC based microstepping motor controller
; Copyright (C) 2004-2011 Alan Garfield <alan@fromorbit.com>

; This program is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License
; as published by the Free Software Foundation; either version 2
; of the License, or (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

 title "PICStep V3.0"

  LIST R=DEC
  #define __16F628a
  #include p16f628a.inc

; MODE PINS
; RA4 - Selects between the two micro-stepping modes below
; RA5 - Turns timeout function on/off

; ========== FIRMWARE SETTINGS ==========

; === TIMEOUT TIME ===
; Uncomment only ONE!

;  #define TIMEOUT_TIME 1	; ~3 mins
;  #define TIMEOUT_TIME 2	; ~6 mins
;  #define TIMEOUT_TIME 3	; ~12 mins
  #define TIMEOUT_TIME 4	; ~24 mins
;  #define TIMEOUT_TIME 5	; ~48 mins
;  #define TIMEOUT_TIME 6	; ~1 hour 36 mins
;  #define TIMEOUT_TIME 7	; ~3 hours 12 mins

; === CURRENT REDUCE 50% MODE ===
; Uncomment if you want a 50% reduction or
; leave commented for a full reduction

  #define FIFTY_PERCENT

; === MICRO-STEPPING MODES ===
; Uncomment only TWO!

  #define MICRO_16 ; 1/16
  #define MICRO_8 ; 1/8
;  #define MICRO_4 ; 1/4
;  #define MICRO_2 ; 1/2
;  #define MICRO_1 ; Full

; ========== NO CHANGES REQUIRED BELOW ==========

; Registers
  UDATA 0x020
step            RES 1
portA_shadow    RES 1
mode            RES 1
lookup          RES 1
temp            RES 1
timeout_reg     RES 1
timeout         RES 2

_w              RES 1
_status         RES 1
_fsr            RES 1
_pclath         RES 1

 __CONFIG _CP_OFF & _WDT_ON & _HS_OSC & _PWRTE_ON & _LVP_OFF & _MCLRE_OFF
  org       0
  goto      Mainline        ; Main line vector

  org 4
  goto      Interupt        ; Interupt vector

  CODE
Interupt
; Save Current Context
    movwf       _w
    movf        STATUS, w
    bcf         STATUS, RP1
    bcf         STATUS, RP0
    movwf       _status
    movf        FSR, w
    movwf       _fsr
    movf        PCLATH, w
    movwf       _pclath
    clrf        PCLATH

; Interrupt service routine
    btfsc       INTCON, INTF
      call INTB0                ; Call INTBO interrupt handler

    btfsc       PIR1, TMR2IF
      call TIMEOUT              ; Call TIMEOUT interrupt handler

; Reset Current Context
    movf        _pclath, w
    movwf       PCLATH
    movf        _fsr, w
    movwf       FSR
    movf        _status, w
    movwf       STATUS
    swapf       _w, f
    swapf       _w, w
    retfie

INTB0
; Handle interupt on RB0

    clrf        timeout         ; Reset timeout timer and register
    clrf        timeout + 1
    clrf        timeout_reg

; Advance the index position
    movlw       HIGH MODE_TABLE
    movwf       PCLATH
    movf        mode, w         ; Load the current mode
    call        MODE_TABLE      ; Get the advance value for this mode
    movwf       lookup          ; Store it for later

    btfss       PORTB, 1        ; Check on the direction pin (RB1)
      goto      $ + 4           ; Jump over step addition

    addwf       step, w         ; Add the current mode to the current position value
    movwf       step            ; Update step
    goto        $ + 3           ; Jump over step subtraction

    subwf       step, w         ; Subtract the current mode from the current position value
    movwf       step            ; Update step

; Bounds check the table
    movlw       0x040           ; Check if step has overflowed the edge of the table
    subwf       step, w
    btfsc       STATUS, Z
      clrf      step

    movf        lookup, w       ; Check if step has underflowed the edge of the table
    sublw       0x040
    subwf       step, w
    btfsc       STATUS, C
      subwf     step, f

; Process DAC A
    movlw       HIGH STEP_TABLE_A
    movwf       PCLATH
    movf        step, w         ; Reload step into w
    call        STEP_TABLE_A    ; Get the result from the table
    movwf       lookup          ; Store the fetched results for later

    btfss       PORTB, 1        ; Check on the direction pin (RB1)
      rlf       lookup, w       ; Rotate to the alternate direction bit to fix a bug in LMD

    xorwf       PORTB, w        ; Prepare the direction bit for DAC A
    andlw       B'10000000'     ; Mask out the direction bit
    xorwf       PORTB, f        ; Output the direction bit

    movf        lookup, w       ; Reload the fetched table results

    andlw       B'00001111'     ; Mask out the upper nibble
    movwf       PORTA           ; Output the DAC results for A

; Process DAC B
    movlw       HIGH STEP_TABLE_B
    movwf       PCLATH
    movf        step, w         ; Reload step into w
    call        STEP_TABLE_B    ; Get the result from the table
    movwf       lookup          ; Store the fetched results for later

    btfss       PORTB, 1        ; Check on the direction pin (RB1)
      rlf       lookup, w       ; Rotate to the alternate direction bit to fix a bug in LMD

    xorwf       PORTB, w        ; Prepare the direction bit for DAC B
    andlw       B'01000000'     ; Mask out the direction bit
    xorwf       PORTB, f        ; Output the direction bit

    rlf         lookup, f       ; Rotate lookup left in place
    rlf         lookup, w       ; Rotate again but into WREG

    xorwf       PORTB, w
    andlw       B'00111100'     ; Mask out the not needed bits
    xorwf       PORTB, f        ; Output the DAC results for B

    bcf         INTCON, INTF    ; Clear RB0 Interrupt flag
    return

TIMEOUT
; Handle motor timeout TMR2 interrupt and return ASAP

    bsf         timeout_reg, 7  ; Set the timeout bit so the count can increment
    bcf         PIR1, TMR2IF    ; Clear TMR2 Interrupt flag
    return

Mainline

; Initialize Variables

    clrf        step
    clrf        mode
    clrf        lookup
    clrf        timeout
    clrf        timeout + 1
    clrf        timeout_reg

; Setup I/O ports / Timers

    clrf        PORTA           ;Initialize PORTA
    clrf        PORTB           ;Initialize PORTB

    movlw       (1 << CM0) | (1 << CM1) | (1 << CM2)    ;Turn comparators off and
    movwf       CMCON                                   ;enable pins for I/O

    bcf         STATUS, RP1
    bsf         STATUS, RP0     ;Select Bank1

    movlw       B'11110000'     ;Set RA<0:3> as outputs
    movwf       TRISA ^ 0x080

    movlw       B'00000011'     ;Set RB<2:7> as outputs
    movwf       TRISB ^ 0x080

    movlw       (1 << INTEDG)   ;Setup Interupt Edge
    movwf       OPTION_REG ^ 0x080

    movlw       (1 << TMR2IE)   ; Enable TMR2 Interupt
    movwf       PIE1 ^ 0x080

    bcf         STATUS, RP0     ;Select Bank0

    movlw       B'01111111'     ; Turn on TMR2 with 1/16 pre and post scaler
    movwf       T2CON ^ 0x080

    movlw       (1 << GIE) | (1 << INTE) | (1 << PEIE) ; Enable global interupts, perph and RB0 Interupts
    movwf       INTCON ^ 0x080

Loop

; Clear the watchdog timer (maximum loop for entire code is ~0.18ms watchdog is 18ms plenty of time!)
    clrwdt

; Monitor the mode switch
	movlw		0x00
	btfss		PORTA, 4
	  movlw		0x01
    movwf       mode

; Motor timeout counter
	btfss		PORTA, 5
	  goto		Loop				; Timeout disabled by mode switches so ignore interupt

    btfss       timeout_reg, 7      ; Check to see if a timeout interrupt has occured
      goto      Loop

; Timeout interrupt occured updated counter
    bcf         timeout_reg, 7      ; Reset the Interrupt flag

    incfsz      timeout, w          ; increment the 16 bit timeout value
    decf        timeout + 1, f
    incf        timeout + 1, f
    movwf       timeout
    iorwf       timeout + 1, w

    movwf       timeout             ; test if the timeout value has overflowed
    btfss       STATUS, Z
      goto      Loop
    movwf       timeout + 1
    btfss       STATUS, Z
      goto      Loop

    incf        timeout_reg, f      ; increase the timeout reg value

    btfss       timeout_reg, TIMEOUT_TIME
      goto      Loop

; Timeout! - Divide the current level by 50%
	clrf		timeout_reg			; Clear the timeout because we've timed out

#ifdef FIFTY_PERCENT
    movf        PORTA, w			; Load current DAC A value
    movwf       temp				; Rotate right once to divide by 2
    rrf         temp, w
#else
	movlw		0x00				; Load zero to turn off motor
#endif
    andlw       B'00001111'     	; Mask out the upper nibble
    movwf       PORTA           	; Output the DAC results for A

#ifdef FIFTY_PERCENT
	movf		PORTB, w			; Load current DAB B value
	movwf		temp				; Roate right once to divide by 2
	rrf			temp, w
#else
	movlw		0x00
#endif
    xorwf       PORTB, w
    andlw       B'00111100'     	; Mask out the not needed bits
    xorwf       PORTB, f        	; Output the DAC results for B

    goto        Loop

  ORG 0x100

; 1/16 Step DAC A Table
STEP_TABLE_A
  addwf     PCL, 1              ;Deg            DAC A
  retlw     B'01000000'         ;0        0.00    0     ---
  retlw     B'00000001'         ;5        0.10    1
  retlw     B'00000010'         ;11       0.20    2
  retlw     B'00000100'         ;16       0.29    4
  retlw     B'00000101'         ;22       0.38    5
  retlw     B'00000111'         ;28       0.47    7
  retlw     B'00001000'         ;33       0.56    8
  retlw     B'00001001'         ;39       0.63    9
  retlw     B'00001010'         ;45       0.71    10
  retlw     B'00001011'         ;50       0.77    11
  retlw     B'00001100'         ;56       0.83    12
  retlw     B'00001101'         ;61       0.88    13
  retlw     B'00001101'         ;67       0.92    13
  retlw     B'00001110'         ;73       0.96    14
  retlw     B'00001110'         ;78       0.98    14
  retlw     B'00001110'         ;84       1.00    14
  retlw     B'00001111'         ;90       1.00    15    ---
  retlw     B'00001110'         ;95       1.00    14
  retlw     B'00001110'         ;101      0.98    14
  retlw     B'00001110'         ;106      0.96    14
  retlw     B'00001101'         ;112      0.92    13
  retlw     B'00001101'         ;118      0.88    13
  retlw     B'00001100'         ;123      0.83    12
  retlw     B'00001011'         ;129      0.77    11
  retlw     B'00001010'         ;135      0.71    10
  retlw     B'00001001'         ;140      0.63    9
  retlw     B'00001000'         ;146      0.56    8
  retlw     B'00000111'         ;151      0.47    7
  retlw     B'00000101'         ;157      0.38    5
  retlw     B'00000100'         ;163      0.29    4
  retlw     B'00000010'         ;168      0.20    2
  retlw     B'00000001'         ;174      0.10    1
  retlw     B'10000000'         ;180      0.00    0     ---
  retlw     B'11000001'         ;185     -0.10   -1
  retlw     B'11000010'         ;191     -0.20   -2
  retlw     B'11000100'         ;196     -0.29   -4
  retlw     B'11000101'         ;202     -0.38   -5
  retlw     B'11000111'         ;208     -0.47   -7
  retlw     B'11001000'         ;213     -0.56   -8
  retlw     B'11001001'         ;219     -0.63   -9
  retlw     B'11001010'         ;225     -0.71   -10
  retlw     B'11001011'         ;230     -0.77   -11
  retlw     B'11001100'         ;236     -0.83   -12
  retlw     B'11001101'         ;241     -0.88   -13
  retlw     B'11001101'         ;247     -0.92   -13
  retlw     B'11001110'         ;253     -0.96   -14
  retlw     B'11001110'         ;258     -0.98   -14
  retlw     B'11001110'         ;264     -1.00   -14
  retlw     B'11001111'         ;270     -1.00   -15
  retlw     B'11001110'         ;275     -1.00   -14    ---
  retlw     B'11001110'         ;281     -0.98   -14
  retlw     B'11001110'         ;286     -0.96   -14
  retlw     B'11001101'         ;292     -0.92   -13
  retlw     B'11001101'         ;298     -0.88   -13
  retlw     B'11001100'         ;303     -0.83   -12
  retlw     B'11001011'         ;309     -0.77   -11
  retlw     B'11001010'         ;315     -0.71   -10
  retlw     B'11001001'         ;320     -0.63   -9
  retlw     B'11001000'         ;326     -0.56   -8
  retlw     B'11000111'         ;331     -0.47   -7
  retlw     B'11000101'         ;337     -0.38   -5
  retlw     B'11000100'         ;343     -0.29   -4
  retlw     B'11000010'         ;348     -0.20   -2
  retlw     B'11000001'         ;354     -0.10   -1

; 1/16 Step DAC B Table
STEP_TABLE_B
  addwf     PCL, 1              ;Deg    DAC B
  retlw     B'01101111'         ;0      -1.00   -15     ---
  retlw     B'01101110'         ;5      -1.00   -14
  retlw     B'01101110'         ;11     -0.98   -14
  retlw     B'01101110'         ;16     -0.96   -14
  retlw     B'01101101'         ;22     -0.92   -13
  retlw     B'01101101'         ;28     -0.88   -13
  retlw     B'01101100'         ;33     -0.83   -12
  retlw     B'01101011'         ;39     -0.77   -11
  retlw     B'01101010'         ;45     -0.71   -10
  retlw     B'01101001'         ;50     -0.63   -9
  retlw     B'01101000'         ;56     -0.56   -8
  retlw     B'01100111'         ;61     -0.47   -7
  retlw     B'01100101'         ;67     -0.38   -5
  retlw     B'01100100'         ;73     -0.29   -4
  retlw     B'01100010'         ;78     -0.20   -2
  retlw     B'01100001'         ;84     -0.10   -1
  retlw     B'00100000'         ;90      0.00    0      ---
  retlw     B'00000001'         ;95      0.10    1
  retlw     B'00000010'         ;101     0.20    2
  retlw     B'00000100'         ;106     0.29    4
  retlw     B'00000101'         ;112     0.38    5
  retlw     B'00000111'         ;118     0.47    7
  retlw     B'00001000'         ;123     0.56    8
  retlw     B'00001001'         ;129     0.63    9
  retlw     B'00001010'         ;135     0.71    10
  retlw     B'00001011'         ;140     0.77    11
  retlw     B'00001100'         ;146     0.83    12
  retlw     B'00001101'         ;151     0.88    13
  retlw     B'00001101'         ;157     0.92    13
  retlw     B'00001110'         ;163     0.96    14
  retlw     B'00001110'         ;168     0.98    14
  retlw     B'00001110'         ;174     1.00    14
  retlw     B'00001111'         ;180     1.00    15     ---
  retlw     B'00001110'         ;185     1.00    14
  retlw     B'00001110'         ;191     0.98    14
  retlw     B'00001110'         ;196     0.96    14
  retlw     B'00001101'         ;202     0.92    13
  retlw     B'00001101'         ;208     0.88    13
  retlw     B'00001100'         ;213     0.83    12
  retlw     B'00001011'         ;219     0.77    11
  retlw     B'00001010'         ;225     0.71    10
  retlw     B'00001001'         ;230     0.63    9
  retlw     B'00001000'         ;236     0.56    8
  retlw     B'00000111'         ;241     0.47    7
  retlw     B'00000101'         ;247     0.38    5
  retlw     B'00000100'         ;253     0.29    4
  retlw     B'00000010'         ;258     0.20    2
  retlw     B'00000001'         ;264     0.10    1
  retlw     B'01000000'         ;270     0.00    0      ---
  retlw     B'01100001'         ;275    -0.10   -1
  retlw     B'01100010'         ;281    -0.20   -2
  retlw     B'01100100'         ;286    -0.29   -4
  retlw     B'01100101'         ;292    -0.38   -5
  retlw     B'01100111'         ;298    -0.47   -7
  retlw     B'01101000'         ;303    -0.56   -8
  retlw     B'01101001'         ;309    -0.63   -9
  retlw     B'01101010'         ;315    -0.71   -10
  retlw     B'01101011'         ;320    -0.77   -11
  retlw     B'01101100'         ;326    -0.83   -12
  retlw     B'01101101'         ;331    -0.88   -13
  retlw     B'01101101'         ;337    -0.92   -13
  retlw     B'01101110'         ;343    -0.96   -14
  retlw     B'01101110'         ;348    -0.98   -14
  retlw     B'01101110'         ;354    -1.00   -14

MODE_TABLE
  addwf     PCL, 1
#ifdef MICRO_16
  retlw     0x001   ; 1/16
#endif
#ifdef MICRO_8
  retlw     0x002   ; 1/8
#endif
#ifdef MICRO_4
  retlw     0x004   ; 1/4
#endif
#ifdef MICRO_2
  retlw     0x008   ; 1/2
#endif
#ifdef MICRO_1
  retlw     0x010   ; 1
#ifdef

 end
