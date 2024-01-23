; 新添加的 .skadi 节的RVA
skadi_section_rva equ 0x7000

; 私有数据的偏移地址
data_offset equ 0x1500
; 字符串自取基地址
strings_offset equ 0x1510

; KERNEL32.dll 距离 字符串基地址 偏移
szKERNEL32dll_offset equ 0xA
size_KERNEL32dll equ 0xD

; USER32.dll 距离 字符串基地址 偏移
szUSER32dll_offset equ size_KERNEL32dll + szKERNEL32dll_offset
size_USER32dll equ 0xB

; GetModuleHandleW 距离 字符串基地址 偏移
szGetModuleHandleW_offset equ size_USER32dll + szUSER32dll_offset
size_GetModuleHandleW equ 0x11

; GetProcAddress 距离 字符串基地址 偏移
szGetProcAddress_offset equ size_GetModuleHandleW + szGetModuleHandleW_offset
size_GetProcAddress equ 0xf

; LoadLibraryA 距离 字符串基地址 偏移
szLoadLibraryA_offset equ size_GetProcAddress + szGetProcAddress_offset
size_LoadLibraryA equ 0xd

; MessageBoxA 距离 字符串基地址 偏移
szMessageBoxA_offset equ size_LoadLibraryA + szLoadLibraryA_offset
size_MessageBoxA equ 0xc

; Magic Number
magic_number equ 0x10100101

optional_header_64_offset_at_sign equ 0x20
import_table_offset_at_opheader equ 0x70

SECTION .text
global _main
_main:

    ; 获取当前的 EIP
    call 0
    pop rbp
    ; 将该节被加载到内存中的位置 放入到 0x500 的位置 
    mov rax, rbp
    sub rax, 5
    mov rdx, rax
    ; push rdx
    add rdx, data_offset
    mov qword[rdx], rax
    add rdx, 8 ; 更新数据指针
    
    ; 获取当前模块的 _LDR_DATA_TABLE_ENTRY 结构体信息
    mov rcx, qword [gs:abs 60H]
    add rcx, 0x18
    mov rax, qword[rcx]

    ; push rax ; 存储当前模块的 _LDR_DATA_TABLE_ENTRY 结构体信息的地址

    add rax, 0x20
    ; 获取ImageBase，存储到 rsi 中 和 LoadAddress + 0x508
    mov rcx, qword[rax]
    add rcx, 0x20
    mov rsi, qword[rcx]
    mov qword[rdx], rsi     ; 存储到 data_offset + 8
    add rdx, 8

    ; 获取 e_lfanew
    mov rax, rsi
    add rax, 0x3C
    xor rcx, rcx
    mov ecx, dword[rax]
    
    ; ; 获取当前的 EIP
    ; call 0
    ; pop rbp
    ; ; 将该节被加载到内存中的位置 放入到 0x500 的位置 
    ; mov rax, rbp
    ; sub rax, 5
    ; mov rdx, rax
    ; ; push rdx
    ; add rdx, data_offset
    ; mov qword[rdx], rax
    ; add rdx, 8 ; 更新数据指针
    ; sub rax, skadi_section_rva
    ; mov qword[rdx], rax
    ; add rdx, 8
    
    ; ; 获取 e_lfanew
    ; mov rsi, rax
    ; add rax, 0x3C
    ; xor rcx, rcx
    ; mov ecx, dword[rax]

    ; 获取导入表的地址，存放在 r8 中
    mov rax, rsi
    add rcx, optional_header_64_offset_at_sign
    add rcx, import_table_offset_at_opheader
    add rax, rcx

    xor r9, r9
    mov r9d, dword[rax+4] ; ImportTableSize

    mov r8d, dword[rax]
    ; mov rax, 0xFFFFFFFF ; RAX = 0xFFFFFFFF
    ; and r8, rax ; R8 = R8 & 0xFFFFFFFF
    and r8, 0x7FFFFFFF  ; ImportOffset

    ; 查找 USER32dll 导入表的地址
    push rdx
    add rdx, szUSER32dll_offset
    mov rcx, rsi
    call get_dll_import_table
    pop rdx     ; 复原 rdx 

    mov r15, rax    ; r15 备份导入表的地址
    mov ecx, dword[r15]
    add rcx, rsi ; 得到导入表名称结构数组在内存中的地址

    push rdx

    add rdx, szMessageBoxA_offset
    mov r8, rsi
    call get_func_index
    ; 如果返回魔数，就出错
    mov rdx, rax
    cmp rdx, magic_number
    je end

    mov rbx, r15
    mov ecx, dword[rbx + 0x10]
    add rcx, rsi
    lea rbx, [rdx * 8 + rcx]
    pop rdx
    
    xor rcx, rcx
    xor rdx, rdx
    xor r8, r8
    xor r9, r9

    call qword[rbx]

    ; 跳转到程序正常的入口地址
    xor rbx, rbx
    mov rbx, 0x12D0
    add rbx, rsi
    jmp rbx

end:
    nop
    nop
    nop
    nop
    nop
    nop

; 接受三个参数
    ; r8 程序被加载到内存的基地址    
    ; const rdx 要寻找的函数的字符串地址
    ; rcx 指向 IMAGE_IMPORT_BY_NAME 的地址
; 返回找到的函数在导入表中的索引
get_func_index:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi
    xor rbx, rbx
    mov rbx, 0
    mov rsi, rcx
    _gfi_loop_start:
        ; 如果 rcx 值为空，则代表该表已经达到末尾，查找失败
        mov rcx, [rsi]
        test rcx, rcx
        jz _gfi_failure

        add rcx, r8
        add rcx, 2          ; 跳过Hint
        call compare_string
        cmp rax, 1
        je _gfi_successful
        add rsi, 8          ; 64 位 8字节
        inc rbx
        jmp _gfi_loop_start

    _gfi_successful:
        mov rax, rbx
        pop rdi
        pop rsi
        pop rbx
        pop rbp
        ret
    _gfi_failure:
        ; 返回模数
        mov rax, magic_number
        pop rdi
        pop rsi
        pop rbx
        pop rbp
        ret


; 接受 4 个参数 
    ; r9: ImportTableSize       导入表的大小
    ; r8: ImportTableOffset     导入表的RVA
    ; const rdx: szDllName            要查找的DLL模块名
    ; rcx: ImageBaseAddr        文件被加载到内存中的基地址
    ; 将 r8 更改为了导入表在内存中的地址
    ; 将 r9 更改为了导入表在内存中有效区域的最大地址
; 返回找到的导入表在内存中的地址
get_dll_import_table:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi



    xor rbx, rbx
    xor rsi, rsi

    mov rbx, rcx    ; rbx = ImageBaseAddr
    add r8, rbx     ; r8 存储导入表在内存中的位置
    add r9, r8     ; r9 存储导入表长度

    mov rsi, rbx    ; rsi ImageBaseAddr
    mov rbx, r8     ; rbx, r8 存储导入表在内存中的位置  
    xor rcx, rcx

    add rbx, 0xC
    loop_start:

        ; 如果导入表指针超出界限，跳出循环
        cmp rbx, r9
        jae loop_end

        ; 如果导入表为空，跳出循环
        mov ecx, dword[rbx]
        test rcx, rcx   
        jz loop_end

        add rcx, rsi    ; rcx 指向第一个导入表的导入的模块的字符串的位置
        call compare_string ; (rcx, rdx)

        add rbx, 0x14   ; 下一张导入表
        cmp rax, 1
        jne loop_start
        ; 找到了 目标导入表
        sub rbx, 0x20
        mov rax, rbx
        jmp loop_end

    loop_end:
        pop rdi
        pop rsi
        pop rbx
        pop rbp
        ret


; rcx 需要查询字符串的地址，const rdx 字符串地址
compare_string:
    push rbp
    mov rbp, rsp
    push rbx
    push rsi
    push rdi

    xor rbx, rbx
    xor rsi, rsi
    xor rdi, rdi
    xor rax, rax
    xor rbx, rbx

    mov rdi, rcx
    mov rsi, rdx

    compare_start:
        mov al, [rdi]
        mov bl, [rsi]
        cmp al, bl
        jne compare_failed
        cmp al, 0
        je compare_successful
        inc rdi
        inc rsi

        jmp compare_start

    compare_failure:
        mov rax, 0
        jmp compare_end

    compare_successful:
        mov rax, 1

compare_end:
    pop rdi
    pop rsi
    pop rbx
    pop rbp
    ret



times strings_offset - ($ - $$) db 0  
SECTION .data
db 'K', 'E', 'R', 'N', 'E', 'L', '3', '2', '.', 'd', 'l', 'l', 0
db 'U', 'S', 'E', 'R', '3', '2', '.', 'd', 'l', 'l', 0 
; db 'K', 0, 'E', 0, 'R', 0, 'N', 0, 'E', 0, 'L', 0, '3', 0, '2', 0, '.', 0, 'd', 0, 'l', 0, 'l', 0, 0, 0
; db 'U', 0, 'S', 0, 'E', 0, 'R', 0, '3', 0, '2', 0, '.', 0, 'd', 0, 'l', 0, 'l', 0, 0, 0

db 'G','e','t','M','o','d','u','l','e','H','a','n','d','l','e','W', 0
db 'G','e','t','P','r','o','c','A','d','d','r','e','s','s', 0
db 'L','o','a','d','L','i','b','r','a','r','y','A', 0
db 'M', 'e', 's', 's', 'a', 'g', 'e', 'B', 'o', 'x', 'A', 0