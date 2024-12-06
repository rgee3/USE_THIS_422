    AREA Timer, CODE, READONLY, ALIGN=2
    THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Timer Definition
STCTRL		EQU		0xE000E010		; SysTick Control and Status Register
STRELOAD	EQU		0xE000E014		; SysTick Reload Value Register
STCURRENT	EQU		0xE000E018		; SysTick Current Value Register
	
STCTRL_STOP	EQU		0x00000004		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 0, Bit 0 (ENABLE) = 0
STCTRL_GO	EQU		0x00000007		; Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 1, Bit 0 (ENABLE) = 1
STRELOAD_MX	EQU		0x00FFFFFF		; MAX Value = 1/16MHz * 16M = 1 second
STCURR_CLR	EQU		0x00000000		; Clear STCURRENT and STCTRL.COUNT	
SIGALRM		EQU		14			; sig alarm

; System Variables
SECOND_LEFT	EQU		0x20007B80		; Secounds left for alarm( )
USR_HANDLER     EQU		0x20007B84		; Address of a user-given signal handler function	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer initialization
; void timer_init( )
		EXPORT		_timer_init
_timer_init
		; disable systick
		LDR     R0, =STCTRL
		LDR     R1, =STCTRL_STOP
		STR     R1, [R0] ; stop sistick

		; set reload value to 1 second
		LDR     R0, =STRELOAD
		LDR     R1, =STRELOAD_MX
		STR     R1, [R0] ; set max reload value (1 second)

		; clear the current value register
		LDR     R0, =STCURRENT
		LDR     R1, =STCURR_CLR
		STR     R1, [R0] ; clear current value register

		MOV     pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer start
; int timer_start( int seconds )
		EXPORT		_timer_start
_timer_start
		; get the previous seconds value from SECOND_LEFT (0x20007B80)
		LDR     R0, =SECOND_LEFT
		LDR     R0, [R0] ; load the previous seconds value

		; save the new seconds value (from R1) to SECOND_LEFT (0x20007B80)
		LDR     R2, =SECOND_LEFT
		STR     R1, [R2] ; store new seconds value

		; set reload value based on the new seconds (R1) to STRELOAD
		LDR     R2, =STRELOAD
		LSL     R1, R1, #24 ; adjust the value for the 16 MHz clock
		STR     R1, [R2] ; store adjusted seconds value to STRELOAD (0xE000E014)

		; enable systick: Set Bit 2 (CLK_SRC) = 1, Bit 1 (INT_EN) = 1, Bit 0 (ENABLE) = 1
		LDR     R2, =STCTRL
		LDR     R1, =STCTRL_GO
		STR     R1, [R2] ; write to STCTRL to start SysTick with interrupt

		MOV     pc, lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		EXPORT		_timer_update
_timer_update
		; decrement seconds left
		LDR     R0, =SECOND_LEFT
		LDR     R1, [R0] ; load current seconds left
		SUBS    R1, R1, #1 ; subtract 1 from the seconds left
		STR     R1, [R0]  ; store updated value back to SECOND_LEFT

		; if seconds have reached 0, trigger the alarm
		BEQ     alarm_triggered

		; if not, return to SysTick_Handler
		MOV     pc, lr

alarm_triggered
		; stop systick (Set STCTRL to STCTRL_STOP)
		LDR     R0, =STCTRL
		LDR     R1, =STCTRL_STOP
		STR     R1, [R0] ; stop timer

		; clear STCURRENT register to reset the current value
		LDR     R0, =STCURRENT
		LDR     R1, =STCURR_CLR
		STR     R1, [R0] ; clear the current value register

		; check if a user-defined signal handler is set
		LDR     R0, =USR_HANDLER
		LDR     R1, [R0] ; load user-defined handler address
		CMP     R1, #0 ; check if handler is null
		BNE     signal_call ; if handler is not null, call it

		MOV     pc, lr

signal_call
		; call the user-defined signal handler function
		BLX     R1 ; branch to the user-defined handler

		; reset the seconds for the next alarm
		LDR     R0, =SECOND_LEFT
		LDR     R1, =0 ; reset seconds left to 0
		STR     R1, [R0] ; store 0 in SECOND_LEFT

		MOV     pc, lr



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Timer update
; void* signal_handler( int signum, void* handler )
		EXPORT		_signal_handler
_signal_handler
		; save the current signal handler address in R0
		LDR     R1, =USR_HANDLER
		LDR     R0, [R1] ; load the current handler address (previous value)
		
		; store the new handler address in memory at 0x20007B84
		STR     R0, [R1] ; save previous handler address back to 0x20007B84
		STR     R1, [R1] ; store the new handler address (R0)

		MOV     pc, lr
		
		END		
