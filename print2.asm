;
; +===============================================================================+
; | Authored by ghost (https://github.com/ghost-1608)                             |
; |                                                                               |
; |-------------------------------------------------------------------------------|
; | This header contains 3 functions that aid printing to the console:-           |
; |      > push_string: For strings                                               |
; |      > push_int32_as_ASCII: For int32 values                                  |
; |      > clean_stack: To clean stack after the previous two functions           |
; |                                                                               |
; |                                                                               |
; | The two push functions pack data and start populating the stack from where    |
; | the RSP is pointing till it runs out of bytes to populate.                    |
; |                                                                               |
; | The RSP decrements by 8 bytes (on 64-bit architecture), and a total of        |
; | ceil(total_length_of_string/8) push operations are performed.                 |
; |                                                                               |
; | Thus, it's possible for the RSP to point at memory filled with 0's (null      |
; | characters) after return from the first two functions.                        |
; |                                                                               |
; | The RBX register is used for this reason to offset the RSP while accessing    |
; | the string on the stack.                                                      |
; |                                                                               |
; | If during a function call to the two push functions, there's existing string  |
; | on the stack, the functions automatically pack data on to the stack to avoid  |
; | any null character in the middle of the string on the stack.                  |
; |                                                                               |
; |                                                                               |
; | After push_string or push_int32_as_ASCII has been called, the stack is ready  |
; | and a sys_write function can be performed using (RSP + RBX) for the           |
; | address of the string, with R8 for the number of bytes to print.              |
; |                                                                               |
; |                                                                               |
; | Once a sys_write has been performed, the pushed string can be popped using    |
; | clean_stack. This function pops as many bytes as indicated by R8.             |
; | Again since the RSP only moves by 8 bytes (64-bit architecture), it performs  |
; | a total of ceil(R8/8) pop operations.                                         |
; |                                                                               |
; |                                                                               |
; | It is important to note that these family of functions make alterations to    |
; | global stack frame, and so leave a "positive SP" or "negative SP" after their |
; | function returns.                                                             |
; |                                                                               |
; +===============================================================================+
;
    
section .text

; =================================================================================
; PUSH_STRING
; ---------------------------------------------------------------------------------
; Function to push existing string (ASCII) to the stack
;
; Input:-
;       > RSI holding address to string to be pushed
;       > RDX holding length of string
;       > R8 holding the length of the string on the stack so far
; Output:-
;       > (RSP + RBX) points to the beginning of the string on the stack
;       > R8 holds the length of the string on the stack so far
;
; (Uses RAX, RBX, RCX, R9, and R10 registers internally)
; ---------------------------------------------------------------------------------
;
push_string:
    pop r9                              ; Since the stack is altered, the return address is saved
    
    lea rbx, [rsi + rdx - 1]            ; Load address of the last char into RBX

    mov rcx, r8                         ; Load existing length of string
    add r8, rdx                         ; Update value of R8 with current string length

    and rcx, 7                          ; Perform modulo operation on RCX with 8
    test rcx, rcx                       
    jz .b0                              ; Jump to .b0 if RCX is a multiple of 8

    pop rax                             ; Pop previous stack push as it contains null characters
    neg rcx                             
    add rcx, 8                          ; Find number of null characters
    mov r10, rcx                        

; Loop to right shift RAX to eliminate all null characters
.l0:
    shr rax, 8
    dec rcx
    test rcx, rcx
    jnz .l0
; end loop

    mov rcx, r10
    jmp .l1
    
.b0:
    xor rax, rax
    mov rcx, 8

; Loop to get each character of string backwards and put in RAX; then push to stack
.l1:
    shl rax, 8
    mov r10b, [rbx]
    add al, r10b

    dec rcx
    test rcx, rcx
    jnz .b1

    push rax
    xor rax, rax
    mov rcx, 8

.b1:
    dec rbx
    mov r10, rsi
    dec r10
    cmp rbx, r10
    jnz .l1
; end loop

; Calculate value for RBX; Check if RAX still has to be pushed
    and rcx, 7
    mov rbx, rcx
    test rcx, rcx
    jz .b2

; Loop to "left-adjust" RAX
.l2:
    shl rax, 8
    dec rcx
    test rcx, rcx
    jnz .l2
; end loop

; If RAX is not empty, push to stack
.b2:
    test rax, rax
    jz .b3
    
    push rax

.b3:
    jmp r9                              ; Jump to previously stored return address
;
; =================================================================================


; =================================================================================
; PUSH_INT32_AS_ASCII
; ---------------------------------------------------------------------------------
; Function to push a 32-bit integer to the stack as an ASCII string
;
; Input:-   
;       > RDI holding the number
;       > R8 holding the length of the string on the stack so far
; Output:-
;       > (RSP + RBX) points to the beginning of the string on the stack
;       > R8 holds the length of the string on the stack so far
;
; (Uses RAX, RBX, RCX, RDI, R9, R10, and R11 internally)
; ---------------------------------------------------------------------------------
;
push_int32_as_ASCII:   
    pop r9                              ; Store return address

    mov eax, edi                        ; Copy recieved 32-bit number
    mov ebx, 0xCCCCCCCD                 ; Agner Fog's magic number

    mov rcx, r8

    and rcx, 7                          ; Perform modulo operation on RCX with 8
    test rcx, rcx
    jz .b0                              ; Jump to .b0 if RCX is divisible by 8

    pop r10                             ; Pop previous stack push as it contains null characters
    neg rcx
    add rcx, 8                          ; Calculate number of null character
    mov r11, rcx

; Loop to right shift R10 to eliminate all null characters
.l0:
    shr r10, 8
    dec rcx
    test rcx, rcx
    jnz .l0
; end loop

    mov rcx, r11
    jmp .l1

.b0:
    xor r10, r10
    mov rcx, 8

; If number is negative, negate it
.b1:
    mov r11, rdi

    test r11, r11
    jns .l1

    neg eax

; Loop to convert decimal number to ASCII; push to stack
.l1:
    shl r10, 8
    mov edi, eax                        ; save original number

    mul ebx                             ; divide by 10 using agner fog's 'magic number'
    shr edx, 3                          ;

    mov eax, edx                        ; store quotient for next loop

    lea edx, [edx*4 + edx]              ; multiply by 10
    lea edx, [edx*2 - '0']              ; finish *10 and convert to ascii
    sub edi, edx                        ; subtract from original number to get remainder

    inc r8                              ; Update R8
    lea r10, [r10 + rdi]                ; Store current digit (in ASCII)

    dec rcx
    test rcx, rcx
    jnz .b1

    push r10
    xor r10, r10
    mov rcx, 8

.b1:
    test eax, eax
    jnz .l1
; end loop

; If given number was negative, add '-' sign
    test r11, r11
    jns .b3

    shl r10, 8
    lea r10, [r10 + '-']
    dec rcx
    inc r8

; Calculate value for RBX; Check if R10 still has to be pushed
.b3:
    and rcx, 7
    mov rbx, rcx
    test rcx, rcx
    jz .b4

; Loop to "left-adjust" R10
.l2:
    shl r10, 8
    dec rcx
    test rcx, rcx
    jnz .l2
; end loop      

; Push R10 if not empty
.b4:
    test r10, r10
    jz .b5

    push r10

.b5:
    jmp r9                              ; Return to previously stored return address
;
; =================================================================================



; =================================================================================
; CLEAN_STACK
; ---------------------------------------------------------------------------------
; Function to "clean" the stack after push_string or push_uint32_as_ASCII calls
; Input:-
;       > R8 holding the length of string pushed to the stack so far
; Output:-
;       Nil
;
; (Uses RAX, RCX, and R9 internally)
; ---------------------------------------------------------------------------------
;
clean_stack:
    pop r9                              ; Store return address

    test r8, r8                         ; Check if R8 is 0 for early exit
    jz .b0

; Calculate number of pop operations ( ceil(R8/8) )
    mov rcx, r8

    shr rcx, 3                          ; Divide RCX (holds same value as R8) by 8

    mov rax, r8
    and rax, 7
    test rax, rax
    jz .l0

    inc rcx

; Loop to pop stack    
.l0:
    pop rax

    dec rcx
    test rcx, rcx
    jnz .l0
; end loop

.b0:
    jmp r9                              ; Return to previously-stored return address
;
; =================================================================================
