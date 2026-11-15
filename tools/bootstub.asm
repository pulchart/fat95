; "Not bootable" x86 boot code for the FAT boot sectors that fat95 writes.
; Position independent: the same bytes sit after the BPB of FAT12/16 (0x3E)
; and FAT32 (0x5A). Print the message, wait for a key, reboot.
; Assemble and format with tools/bootstub.py.
        bits 16
        org 0
        cli
        xor     ax, ax
        mov     ss, ax
        mov     sp, 0x7c00
        sti
        push    cs
        pop     ds
        call    here
here:   pop     si
        add     si, msg - here
next:   lodsb
        test    al, al
        jz      key
        mov     ah, 0x0e
        mov     bx, 7
        int     0x10
        jmp     short next
key:    xor     ax, ax
        int     0x16
        int     0x19
%ifndef NOMSG
msg:    db 'Not a bootable disk', 13, 10, 'Press a key to reboot', 13, 10, 0
%else
msg:
%endif
