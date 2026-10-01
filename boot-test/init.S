.section .rodata
message:
	.ascii "\n=== AWV1 NATIVE BOOT TEST PASSED ===\n"
	.ascii "Linux reached PID 1 from the USB kernel.\n"
	.ascii "Internal storage has not been mounted. Power off to end this test.\n\n"
.set message_len, . - message

.section .text
.global _start
.type _start, @function
_start:
	mov $1, %rax
	mov $1, %rdi
	lea message(%rip), %rsi
	mov $message_len, %rdx
	syscall

1:
	mov $34, %rax
	syscall
	jmp 1b

.section .note.GNU-stack,"",@progbits
