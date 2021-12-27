;Compile & link command
;nasm -f win64 -o b1_w.obj b1_w.asm 
;.\GoLink /files /console b1_w.obj kernel32.dll user32.dll

bits 64
default rel
segment .data
format db "%d ", 0
crlf db 13,10
segment .text
	extern ExitProcess
	extern GetStdHandle
	extern ReadConsoleA
	extern WriteConsoleA
	extern wsprintfA
	extern HeapAlloc
	extern HeapReAlloc
	extern GetProcessHeap
global Start




Start:
    push    rbp 			
    mov     rbp, rsp		
	sub		rsp, 88							;Allocate 88 bytes in stack
	;x64 calling convention : left->right RCX, RDX, R8, R9
	;Local variable:
	;offset -88  : int64 flag
	;offset -80  : HANDLE hHeap
	;offset -72  : char* out[100]
	;offset -64  : char* c[12]  //Include \r\n when read from console
	;offset -56  : char* s[102] //Include \r\n when read from console
	;offset -48	 : int64 count
	;offset -40  : int64 writtenlen
	;offset -32	 : int64 clen
	;offset -24  : int64 slen
	;offset -16	 : HANDLE hStdout
	;offset -8   : HANDLE hStdin
	
	;hStdin = GetStdHandle(STD_INPUT_HANDLE);
	mov 	ecx, -10							;STD_INPUT_HANDLE 
	call 	GetStdHandle 						;hStdin = GetStdHandle(STD_INPUT_HANDLE);
	mov 	[rbp-8], rax						
		
	;hStdout = GetStdHandle(STD_OUTPUT_HANDLE)	
	mov 	ecx, -11							;STD_OUTPUT_HANDLE
	call 	GetStdHandle						;hStdout = GetStdHandle(STD_OUTPUT_HANDLE)
	mov 	[rbp-16], rax	
	
	;hHeap = GetProcessHeap()
	sub 	rsp, 32								;Shadow store
	call 	GetProcessHeap
	mov 	[rbp-80], rax						;hHeap = GetProcessHeap()
	add 	rsp, 32								;Shadow store
	
	;s = HeapAlloc(hHeap,8,102)
	sub 	rsp, 32								;Shadow store
	mov 	rcx, [rbp-80]						;hHeap
	mov 	edx, 8								;HEAP_ZERO_MEMORY 0x00000008
	mov 	r8d, 102							;number of byte allocated
	call	HeapAlloc							;s = HeapAlloc(hHeap,8,102)
	mov 	[rbp-56], rax	
	add 	rsp, 32								;Shadow store	
	
	;ReadConsoleA(hStdin, s, 102, &slen,0)
	sub 	rsp, 32								;Shadow store
	mov		rcx, [rbp-8]						;hStdin
	mov 	rdx, [rbp-56]						;s
	mov 	r8d, dword 102						;102
	lea 	r9, [rbp-24]						;&slen
	push 	0									;0
	call 	ReadConsoleA						;ReadConsoleA(hStdin, s, 102, &slen,0);
	add		rsp, 40								;Shadow store + clean up paramenter	
	
	;slen -= 2
	mov		rax, [rbp-24]
	sub 	rax, 2								;slen -= 2 - cut away \r\n
	mov 	[rbp-24], rax
	
	;s = HeapReAlloc(hHeap, 0, s, slen)
	sub 	rsp, 32								;Shadow store
	mov 	rcx, [rbp-80]						;hHeap
	xor 	rdx, rdx							;0 - no flag
	mov 	r8, [rbp-56]						;ptr s
	mov 	r9d, [rbp-24]						;slen
	call	HeapReAlloc							;s = HeapAlloc(hHeap, 0, s, slen)
	mov 	[rbp-56], rax
	add 	rsp, 32
	
	;c = HeapAlloc(hHeap,8,102)
	sub 	rsp, 32								;Shadow store
	mov 	rcx, [rbp-80]						;hHeap
	mov 	edx, 8								;HEAP_ZERO_MEMORY 0x00000008
	mov 	r8d, 12								;number of byte allocated
	call	HeapAlloc							;c = HeapAlloc(hHeap,8,102)
	mov 	[rbp-64], rax		
	add 	rsp, 32								;Shadow store
	
	;ReadConsoleA(hStdin, c, 12, &clen, 0);
	sub 	rsp, 32								;Shadow store
	mov		rcx, [rbp-8]						;hStdin
	mov 	rdx, [rbp-64]						;c
	mov 	r8d, dword 12						;12
	lea 	r9, [rbp-32]						;&clen
	push 	0									;0
	call 	ReadConsoleA						;ReadConsoleA(hStdin, c, 12, &clen, 0);
	add		rsp, 40								;Shadow store + clean up paramenter											
	
	;clen -= 2
	mov 	rax, [rbp-32]
	sub 	rax, 2								;clen -= 2 - cut away \r\n	
	mov 	[rbp-32], rax
	
	;c = HeapReAlloc(hHeap, 0, c, clen)
	sub 	rsp, 32								;Shadow store
	mov 	rcx, [rbp-80]						;hHeap
	xor 	rdx, rdx							;0 - no flag
	mov 	r8, [rbp-64]						;ptr c
	mov 	r9d, [rbp-32]						;clen
	call	HeapReAlloc							;c = HeapAlloc(hHeap, 0, c, clen)
	mov 	[rbp-64], rax
	add 	rsp, 32
	
	sub 	rsp, 32								;Shadow store
	mov 	rcx, [rbp-80]						;hHeap
	mov 	edx, 8								;HEAP_ZERO_MEMORY 0x00000008
	mov 	r8d, 100							;number of byte allocated
	call	HeapAlloc							;out = HeapAlloc(hHeap,8,102)
	mov 	[rbp-72], rax		
	add 	rsp, 32								;Shadow store
	
	
	lea		rax, [rbp-48]
	mov 	rax, 0 								;count = 0
	
	lea 	rax, [rbp-88]						
	mov 	rax, 0								;flag = 0
	jmp 	printposition
	
printposition:
	mov 	rax, [rbp-24]						;slen
	mov 	rbx, [rbp-32]						;clen
	cmp 	rax, rbx							;if (slen < clen) then skip compair
	jl		Quitloop
	;											;for(int i=0;i<slen;i++) {
initialization_1:	
	xor 	rdi, rdi							;register for loop index (int i)
												;i = 0
Comparison_1:
	mov 	rax, [rbp-24]						;slen
	cmp 	rdi, rax							
	jl		Loop_1								;if (i<slen)
	jmp		Quitloop
Loop_1:
	mov 	r9, [rbp-56]						;s address
	movzx 	rax, byte [r9+rdi]					;s[i]
	mov 	r9, [rbp-64]						;c address
	movzx 	rbx, byte [r9]						;c[0]
	cmp 	al, bl
	jne 	Increment_1							;if (s[i] == c[0]) call match(s+i,c,clen)
	mov 	rcx, [rbp-56]						;s
	add 	rcx, rdi							;s+1
	mov 	rdx, [rbp-64]						;c
	mov		r8, [rbp-32]						;clen
	sub 	rsp, 32 							;shadow saving
	call	match								;match(s+i,c,clen)
	add 	rsp, 32								;remove shadow saving
	cmp 	rax, 0
	je 		Increment_1							;if return value of match == 0, skip
	
	mov 	rax, [rbp-88] 						;flag
	cmp 	rax, 0								;if flag == 0 then skip
	je 		L1									
	mov 	rcx, rdi							;else PrintInt(rdi)
	call 	PrintInt
L1:
	mov 	rax, [rbp-48]							
	add		rax, 1								;else count++
	mov 	[rbp-48], rax
	jmp 	Increment_1
Increment_1:
	add 	rdi, 1
	jmp 	Comparison_1
	
	
match: 										;fast_call int64 match(char* a <rcx>, char* b <rdx>, int limit <r8>). 
											;Ret 1 means string equal, ret 0 means not equal
	push    rbp 			
    mov     rbp, rsp	
	;Parameter
	;rcx 		 : a
	;rdx 		 : b
	;r8 		 : limit
	;Local variable
	;offset -8   : int64 i
	
	;for(int i = 0; i < limit ; i++)
Initialization_2:
	xor 	r9, r9								;r9 is reverse for i

Comparison_2:
	cmp 	r9, r8								
	jl		Loop_2								;if i <r9>  <  limit <r8> then go to Loop_2
	jmp 	R1									;exit loop	
Loop_2:
	movzx	rax, byte [rcx + r9]				;a[i]
	movzx 	rbx, byte [rdx + r9]				;b[i]
	cmp 	al, bl								;if a[i] == b[i] then move to the next loop
	je		Increment_2							;else return 0
	jmp 	R0									;return 0
Increment_2:
	inc 	r9 									;i++
	jmp 	Comparison_2
R0: ;return 0
	xor 	rax, rax
	leave
	ret
R1: ;return 1
	mov 	rax, 1
	leave
	ret
;end of match()
Quitloop:

	mov 	rax, [rbp-88]						;flag						
	cmp 	qword [rbp-88], 1								;if flag == 1 then end
	je 		End
	
	mov 	rcx, [rbp-48]						;count
	call 	PrintInt							;PrintInt(count)
	
	;print carriage return & line feed
	sub 	rsp, 32								;Shadow store
	mov		rcx, [rbp-16]						;hStdout
	mov 	rdx, crlf							;"\r\n"
	mov 	r8d, 2								;2
	mov		r9, [rbp-40]
	push 	0
	call 	WriteConsoleA						;WriteConsoleA(hStdout, crlf, 2, &writtenlen, 0);
	add		rsp, 40								;Shadow store + clean up paramenter
	
	;flag = 1
	mov 	qword [rbp-88], 1
	
	call 	printposition

End:
	mov 	rsp,rbp
	;0123456789
    xor     rcx, rcx
    call    ExitProcess
	
PrintInt: ;PrintInt(int i[rcx])
	mov 	r10, rcx
	mov 	rcx, [rbp-72]						;ptr out
	lea		rdx, [format]						;"%d "
	mov 	r8d, r10d							;i
	sub 	rsp, 32								;Shadow store
	call 	wsprintfA 							;[rax]outlen = wsprintfA(out, "%d ", i);
	add 	rsp, 32								;Shadow store	
	
	sub 	rsp, 32								;Shadow store
	mov		rcx, [rbp-16]						;hStdout
	mov 	rdx, [rbp-72]						;out
	mov 	r8d, eax							;outlen
	mov		r9, [rbp-40]
	push 	0
	call 	WriteConsoleA						;WriteConsoleA(hStdout, out, outlen, &writtenlen, 0);
	add		rsp, 40								;Shadow store + clean up paramenter
	
	ret
	
