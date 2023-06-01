# Assembly-Print-Header
A small header file to aid printing strings and numbers to the console in assembly (using NASM, AMD64 instruction set).

## Description
This header contains 3 functions that aid printing to the console:-
* `push_string`: For strings
* `push_uint32_as_ASCII`: For uint32 values
* `clean_stack`: To clean stack after the previous two functions

## Sample Code
### The following tutorial provides code snippets and the final code to use the library
### (NASM syntax; AMD64 assembly; Compiled as ELF64)


Include the library like so:-
```
%include "print2.asm"
```

To push strings to the stack, we need to first declare a string. This we shall do in the read-only data segment
```
section .rodata
  string0 DB "Hello, World!"
```
We also need to define its length
```
section .rodata
  string0 DB "Hello, World!"
  .len EQU $ - string0
```

We can now write code in the text segment, inside our `_start` function.
We first clear the `R8` register.
```
section .text
_start:
  xor r8, r8
```

Now, finally we push a number using `push_uint32_as_ASCII` and the string using `push_string`.
(Remember to push in LIFO)
```
  mov rdi, 69
  call push_uint32_as_ASCII
```
And,
```
  mov rsi, string0
  mov rdx, string0.len
  call push_string
```

We're ready to print both on the console.
We do this by using the kernel's `sys_write` function.
```
mov rax, 1
mov rdi, 1
lea rsi, [rsp + rbx]
mov rdx, r8
syscall
```

Finally, let's clean the stack
```
call clean_stack
```


The whole code is as follows:-
```
global _start

%include "print2.asm"

section .rodata
  string0 DB "Hello, World!"
  .len EQU $ - string0
  
section .text
_start:
  push rbp
  
  xor r8, r8
  
  mov rdi, 69
  call push_uint32_as_ASCII
  
  mov rsi, string0
  mov rdx, string0.len
  call push_string
  
  mov rax, 1
  mov rdi, 1
  lea rsi, [rsp + rbx]
  mov rdx, r8
  syscall
  
  call clean_stack
  
  pop rbp
  mov rax, 60
  mov rdi, 0
  syscall
```
## Behind The Scenes
The two push functions pack data and start populating the stack from where the `RSP` is pointing till it runs out of bytes to populate.

The `RSP` decrements by 8 bytes (on 64-bit architecture), and a total of _ceil(total_length_of_string/8)_ push operations are performed.
Thus, it's possible for the `RSP` to point at memory filled with 0's (null characters) after return from the first two functions.
The `RBX` register is used for this reason to offset the `RSP` while accessing the string on the stack.

If during a function call to the two push functions, there's existing string on the stack, the functions automatically pack data on to the stack to avoid any null character in the middle of the string on the stack.

After `push_string` or `push_uint32_as_ASCII` has been called, the stack is ready and a `sys_write` function can be performed using `RSP + RBX` for the address of the string, with `R8` for the number of bytes to print.
Once a `sys_write` has been performed, the pushed string can be popped using `clean_stack` This function pops as many bytes as indicated by `R8`. Again since the `RSP` only moves by 8 bytes (64-bit architecture), it performs a total of _ceil(`R8`/8)_ pop operations.

It is important to note that these family of functions make alterations to global stack frame, and so leave a "Positive SP" or "Negative SP" after their function returns.
