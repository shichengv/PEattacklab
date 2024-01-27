# PE attack lab

PE文件攻击实验

update#0:

修改PE可选头，设置入口地址为`.skadi`节，修改shellcode代码，使用shellcode得到系统API函数的地址，存放在预先设定好的位置。shellcode修改`call main`代码的指令码。计算main函数的地址，备份。然后修改该指令码的操作数为恶意代码的地址，在恶意代码的最后使用jmp指令回到main函数。**失败**

为test.exe 文件新增添一个 `.skadi` 节(属性：可读可写可执行，包含代码，RVA：0x7000，大小：0x4000)，将恶意代码写入到该节。~~设置程序的入口地址为新增添的节的起始地址~~。IDA反汇编`test.exe`程序，寻找`call main`指令的偏移，计算shellcode与当前指令的偏移值，写入到 `E8` 指令码后，修改shellcode，在shellcode末尾添加jmp指令跳转到 main 函数的位置。(有意思的是，只要你敢更改 `call main` 这条指令，Windows Defender直接给你杀了)

现代C++编译器增加了很多保护机制，直接修改PE的入口地址调用API会触发异常。Windows执行API的过程中会做一些安全检查，设置一些内存属性。

源码：
- `test.cpp` 实验的PE文件的源代码，由最新版本的 MSVC 编译器构建成为 `test.exe` 程序。
- `shellcode.asm` 是由NASM汇编语言编写的恶意代码，仅仅调用 `MessageBoxA` 函数
- `write.rs` 读取shellcode.obj 文件中的节的内容(从.text节内容的开始一直到文件末尾)，将其写入到为test.exe 新增添的 `.skadi` 节中(属性：可读可写可执行，包含代码)

构建：
以下命令将得到 shellcode.obj 文件
```
nasm -f win64 .\shellcode.asm
```

build:

- `test_backup.exe` 用最新版本的 msvc编译器编译好的 test.cpp，只增添了 .skadi 节，并没有更改程序的入口地址，可以正常运行。 
- `test.exe` 已经注入好了 shellcode 代码，更改了程序的入口地址，但在调用api 的时候会触发异常

shellcode:

利用程序的PEB找到当前模块被加载到内存的基地址，通过解析PE头，获取导入表，从导入表找到`USER32.dll`的导入表，然后获取 `USER32!MessageBoxA` 系统API的真正地址，接着调用`MessageBoxA(0, 0, 0, 0)`。