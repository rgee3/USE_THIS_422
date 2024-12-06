    AREA Svc, CODE, READONLY
    THUMB
	EXPORT _systemcall_table_init
    EXPORT _systemcall_table_jump

    IMPORT _kalloc       ; malloc handler in heap.s
    IMPORT _kfree        ; free handler in heap.s
    IMPORT _signal_handler ; signal handler in timer.s
    IMPORT _timer_start  ; alarm handler in timer.s

_systemcall_table_init
    ; Initialize jump table with function addresses
    LDR R0, =0x20007B00  ; Base address of system call table
    LDR R1, =_timer_start
    STR R1, [R0, #4]     ; Store alarm handler at 0x20007B04
    LDR R1, =_signal_handler
    STR R1, [R0, #8]     ; Store signal handler at 0x20007B08
    LDR R1, =_kalloc
    STR R1, [R0, #12]    ; Store malloc handler at 0x20007B0C
    LDR R1, =_kfree
    STR R1, [R0, #16]    ; Store free handler at 0x20007B10
    BX LR                ; Return from _systemcall_table_init

_systemcall_table_jump
    ; Jump based on system call number in R7
    LDR R0, =0x20007B00  ; Base address of system call table
    LSL R7, R7, #2       ; Shift left (multiply R7 by 4 to get offset)
    LDR R1, [R0, R7]     ; Load address of handler
    BX R1                ; Branch to handler function
	
	END
