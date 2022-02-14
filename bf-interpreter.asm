BITS 64

segment .data
    fail_msg: db "[ERROR]: "
    fail_msg_len: EQU $ - fail_msg

segment .bss
    filepath_ptr: resq 1
    fd: resq 1

    mem: resb 30000
    mem_end:
    data_pointer: resq 1

    stat: resb 144
    
    text_ptr: resq 1
    text_idx: resq 1
    text_char: resb 1

    brackets_open: resq 1

segment .text

dump:
    mov     r9, -3689348814741910323
    sub     rsp, 40
    mov     BYTE [rsp+31], 10
    lea     rcx, [rsp+30]
.L1:
    mov     rax, rdi
    lea     r8, [rsp+32]
    mul     r9
    mov     rax, rdi
    sub     r8, rcx
    shr     rdx, 3
    lea     rsi, [rdx+rdx*4]
    add     rsi, rsi
    sub     rax, rsi
    add     eax, 48
    mov     BYTE [rcx], al
    mov     rax, rdi
    mov     rdi, rdx
    mov     rdx, rcx
    sub     rcx, 1
    cmp     rax, 9
    ja      .L1
    lea     rax, [rsp+32]
    mov     edi, 1
    sub     rdx, rax
    xor     eax, eax
    lea     rsi, [rsp+32+rdx]
    mov     rdx, r8
    mov     rax, 1
    syscall
    add     rsp, 40
    ret

map_file:
    ;
    mov rax, 5
    mov rdi, [fd]
    mov rsi, stat
    syscall
    ;
    mov rax, 9 ; mmap
    mov rdi, 0 ; addr=0
    mov rsi, [stat+48] ; length=filesize
    mov rdx, 1 ; prot=PROT_READ
    mov r10, 2 ; flags=MAP_PRIVATE
    mov r8, [fd]
    mov r9, 0 ; offset=0
    syscall
    ; error if map failed
    mov r15, 2
    cmp rax, 0
    jl fail
    ;
    mov [text_ptr], rax
    ;
    ret

advance:
    add [text_idx], rax
    mov rax, [text_idx]
    mov r15, 3
    cmp rax, [stat+48]
    jge fail
    mov r15, 4
    cmp rax, 0
    jl fail

    add rax, [text_ptr]
    mov bl, [rax]
    mov [text_char], bl

    ret

global _start
_start:
    ; check that there are 2 arguments given
    pop rdi
    mov r15, 0
    cmp rdi, 2
    jne fail
    ; save filepath
    mov rax, [rsp+8]
    mov [filepath_ptr], rax
    ; open file
    mov rax, 0x2
    mov rdi, [filepath_ptr]
    mov rsi, 0
    mov rdx, 0
    syscall
    ; check that fd isn't an error code
    mov r15, 1
    cmp rax, 0
    jl fail
    ; save fd
    mov [fd], rax

    call map_file

    mov QWORD [data_pointer], mem

    mov QWORD [text_idx], -1

parse_loop:
    add QWORD [text_idx], 1
    mov rax, [text_idx]
    cmp rax, [stat+48]
    jge exit

    add rax, [text_ptr]
    xor rbx, rbx
    mov bl, [rax]
    mov [text_char], bl

parse_inc_dp:
    cmp BYTE [text_char], '>'
    jne parse_dec_dp

    inc QWORD [data_pointer]

    mov rax, [data_pointer]
    mov r15, 6
    cmp rax, mem_end
    jge fail

    jmp parse_loop
parse_dec_dp:
    cmp BYTE [text_char], '<'
    jne parse_inc

    dec QWORD [data_pointer]

    mov rax, [data_pointer]
    mov r15, 5
    cmp rax, mem
    jl fail

    jmp parse_loop
parse_inc:
    cmp BYTE [text_char], '+'
    jne parse_dec

    mov rax, [data_pointer]
    inc BYTE [rax]

    jmp parse_loop
parse_dec:
    cmp BYTE [text_char], '-'
    jne parse_out

    mov rax, [data_pointer]
    dec BYTE [rax]

    jmp parse_loop
parse_out:
    cmp BYTE [text_char], '.'
    jne parse_in

    mov rax, [data_pointer]
    mov bl, [rax]
    mov [text_char], bl

    mov rax, 1
    mov rdi, 1
    mov rsi, text_char
    mov rdx, 1
    syscall

    mov rax, [text_idx]
    add rax, [text_ptr]
    mov bl, [rax]
    mov [text_char], bl

    jmp parse_loop
parse_in:
    cmp BYTE [text_char], ','
    jne parse_open

    mov rax, 0
    mov rdi, 0
    mov rsi, text_char
    mov rdx, 1
    syscall

    mov bl, [text_char]
    mov rax, [data_pointer]
    mov [rax], bl

    mov rax, [text_idx]
    add rax, [text_ptr]
    mov bl, [rax]
    mov [text_char], bl

    jmp parse_loop
parse_open:
    cmp BYTE [text_char], '['
    jne parse_close

    mov rax, [data_pointer]
    mov bl, [rax]
    cmp bl, 0
    jne parse_loop

    mov QWORD [brackets_open], 0
.loop:
    mov rax, 1
    call advance

    cmp BYTE [text_char], '['
    jne .L1
    inc QWORD [brackets_open]
.L1:
    cmp BYTE [text_char], ']'
    jne .loop

    cmp QWORD [brackets_open], 0
    je parse_loop

    dec QWORD [brackets_open]
    jmp .loop

    jmp parse_loop
parse_close:
    cmp BYTE [text_char], ']'
    jne parse_loop

    mov rax, [data_pointer]
    mov bl, [rax]
    cmp bl, 0
    je parse_loop

    mov QWORD [brackets_open], 0
.loop:
    mov rax, -1
    call advance

    cmp BYTE [text_char], ']'
    jne .L1
    inc QWORD [brackets_open]
.L1:
    cmp BYTE [text_char], '['
    jne .loop

    cmp BYTE [brackets_open], 0
    je parse_loop

    dec QWORD [brackets_open]
    jmp .loop

    jmp parse_loop


exit:
    mov rax, 60
    mov rdi, 0
    syscall
fail:
    mov rax, 1
    mov rdi, 2
    mov rsi, fail_msg
    mov rdx, fail_msg_len
    syscall
    mov rdi, r15
    call dump
    mov rax, 60
    mov rdi, 1
    syscall