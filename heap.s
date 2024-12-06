	AREA Heap, CODE, READONLY
    THUMB

    EXPORT _kinit
    EXPORT _kalloc
    EXPORT _ralloc
    EXPORT _kfree
    EXPORT _rfree
    EXPORT _split_block

heap_init
    LDR R0, =0x20006800        ; Base address of Memory Control Block (MCB)
    MOV R1, #0x4000            ; Size of the entire heap (16KB)
    STR R1, [R0]               ; Mark first entry as free (0x4000)
    MOV R2, #0                 ; Prepare R2 with 0 to zero-out other entries

heap_init_loop
    ADD R0, #2                 ; Move to the next MCB entry (2 bytes per entry)
    LDR R3, =0x20006BFE        ; Load end address of MCB
    CMP R0, R3                 ; Check if we've reached the end of the MCB
    BHI heap_init_done         ; Exit loop if all entries are initialized
    STR R2, [R0]               ; Zero out the current MCB entry
    B heap_init_loop

heap_init_done
    BX LR                      ; Return from heap_init

_kinit
    LDR R0, =0x20006800        ; Base address of Memory Control Block (MCB)
    MOV R1, #0x4000            ; Size of entire heap (16KB)
    STR R1, [R0]               ; Mark first entry as 16KB available
    MOV R2, #0                 ; Prep R2 with 0 (zero out remaining MCB entries)

    ; Initialize all other MCB entries to 0
kinit_loop
    ADD R0, #2                 ; Move to the next MCB entry (2 bytes each)
    LDR R3, =0x20006BFE        ; Load end address of MCB
    CMP R0, R3                 ; Check if we've reached the end of MCB
    BHI kinit_done              ; Exit loop if all entries are initialized
    STR R2, [R0]               ; Zero out the current MCB entry
    B kinit_loop
kinit_done
    BX LR                      

_kalloc
    PUSH {R1, R2, LR}          ; Save registers and return address

    LDR R1, =0x20006800        ; Base address of MCB
    LDR R2, =0x20006BFE        ; End address of MCB
    BL _ralloc                 ; Call _ralloc with (R0, R1, R2)

    POP {R1, R2, PC}           ; Restore registers and return

_ralloc
    CMP R0, #0                 ; Check if requested size is valid
    BEQ ralloc_error           ; Return error if size is 0

    LDRH R3, [R1]              ; Load current MCB entry
    TST R3, #1                 ; Check if block is in use (LSB set)
    BNE ralloc_next            ; If in use, go to the next block

    LSR R4, R3, #4             ; Extract the block size (bits 15 to 4)
    CMP R4, R0                 ; Compare block size to requested size
    BLT ralloc_next            ; If too small, go to the next block

    ; If the block is large enough
    CMP R4, R0                 ; Check if block matches the size exactly
    BEQ ralloc_allocate        ; If yes, allocate it
    BL _split_block            ; If no, split the block

ralloc_allocate
    ORR R3, #1                 ; Mark block as 'in use'
    STRH R3, [R1]              ; Update MCB entry
    BX LR                      

ralloc_next
    ADD R1, #2                 ; Move to next MCB entry
    CMP R1, R2                 ; Check if reached the end
    BLT _ralloc                ; Continue searching
    BX LR                      ; Return if no suitable block is found

ralloc_error
    MOV R0, #0                 ; Return NULL
    BX LR

_kfree
    PUSH {R1, R2, LR}          ; Save registers and return address

    LDR R1, =0x20006800        ; Base address of MCB
    BL _rfree                  ; Call _rfree with (R0, R1)

    POP {R1, R2, PC}           ; Restore registers and return

_rfree
    LDRH R3, [R1]              ; Load current MCB entry
    BIC R3, #1                 ; Mark block as free (clear LSB)
    STRH R3, [R1]              ; Update MCB entry

    ; Calculate the buddy block address
    LSR R4, R3, #4             ; Extract the block size (bits 15:4)
    MOV R5, R4                 ; Save the block size (buddy offset)

    ; Add buddy offset to calculate buddy address
    ADD R4, R1, R5             ; R4 = buddy address (current address + size)

    ; Check if buddy block is free
    LDRH R5, [R4]              ; Load the buddy's MCB entry
    TST R5, #1                 ; Check if the buddy is in use
    BNE rfree_done             ; If buddy is in use, we're done

    ; Merge blocks
    ADD R3, R5                 ; Combine the sizes of current block and buddy
    STRH R3, [R1]              ; Update the merged block's MCB entry

    ; Move to the parent block
    AND R1, R1, R3             ; Align to parent block address

    ; Recursively free the parent block
    BL _rfree

rfree_done
    BX LR            

_split_block
    LSR R4, R4, #1             ; Divide the block size by 2 (size of each buddy)
    MOV R5, R4                 ; Store the size of the buddy block

    ; Update the current block size (R4 now has the size of the new smaller block)
    BIC R3, #1                 ; Mark current block as free (clear the 'in-use' bit)
    STRH R3, [R1]              ; Store updated entry in MCB

    ; update the MCB entry for the new buddy block
    ADD R1, #2                 ; Move to the next MCB entry (buddy block)
    MOV R3, R5                 ; Set size for the buddy block
    ORR R3, #1                 ; Mark the buddy block as "in-use"
    STRH R3, [R1]              ; Store the updated entry for the buddy block

    BX LR                      ; Return
    
    END