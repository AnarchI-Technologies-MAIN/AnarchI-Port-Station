.section .rodata
message:
	.ascii "\n=== AWV1 NATIVE BOOT TEST PASSED ===\n"
	.ascii "Linux reached diagnostic PID 1 from the embedded initramfs.\n"
	.ascii "This PID 1 will not mount or write storage. Power off to end this test.\n\n"
.set message_len, . - message

.section .text
.global _start
.type _start, @function
_start:
	mov $1, %rdi
	lea message(%rip), %rsi
	mov $message_len, %rdx

write_message:
	mov $1, %rax
	syscall
	test %rax, %rax
	jle idle
	add %rax, %rsi
	sub %rax, %rdx
	jne write_message

idle:
	mov $34, %rax
	syscall
	jmp idle

.section .note.GNU-stack,"",@progbits
