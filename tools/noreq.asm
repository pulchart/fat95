; noreq: pr_WindowPtr -1 for the calling process, so a missing volume is an
; error, not a requester that waits forever. Guest tool of the integration
; suite, not shipped.
;
; Build: make noreq

	move.l	4.w,a6
	sub.l	a1,a1
	jsr	-294(a6)		;FindTask(NULL)
	move.l	d0,a0
	moveq	#-1,d0
	move.l	d0,184(a0)		;pr_WindowPtr
	moveq	#0,d0
	rts
