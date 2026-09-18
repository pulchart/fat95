; Paged console output. The includer provides the CALLDOS macro, the
; Read/Write/WaitForChar/IsInteractive/SetMode LVOs, the ESC/CR/fh_Type
; equates, and the frame vars ConsoleI, ConsoleO, KeyBuf, PageLines, PageLeft,
; with ConsoleI/ConsoleO already holding Input()/Output().
; PageLines = 0 means everything scrolls.

PageBegin:
	movem.l	d0-d2/a0-a1/a6,-(sp)
	clr.l	PageLines(a4)
	clr.l	PageLeft(a4)
	move.l	ConsoleI(a4),d0
	beq.w	pgb_end			;no input stream: cannot wait
	move.l	ConsoleO(a4),d1
	beq.w	pgb_end
	CALLDOS	IsInteractive
	tst.l	d0
	beq.w	pgb_end			;output redirected
	move.l	ConsoleI(a4),d1
	CALLDOS	IsInteractive
	tst.l	d0
	beq.w	pgb_end			;input redirected

;-- the query is written to the output and answered on the input, so both
;   must be the same handler; a redirected ">SER:" gets neither --
	move.l	ConsoleI(a4),d0
	lsl.l	#2,d0
	move.l	d0,a0
	move.l	ConsoleO(a4),d0
	lsl.l	#2,d0
	move.l	d0,a1
	move.l	fh_Type(a0),d0
	cmp.l	fh_Type(a1),d0
	bne.w	pgb_end

	move.l	ConsoleI(a4),d1
	moveq.l	#1,d2
	CALLDOS	SetMode			;RAW for the query and every keypress
	bsr.w	PageRows
	tst.l	d0
	beq.s	pgb_plain
	move.l	PageLines(a4),d0
	subq.l	#1,d0			;the prompt needs a line of its own
	cmp.l	#4,d0
	blt.s	pgb_plain
	cmp.l	#200,d0
	bgt.s	pgb_plain		;implausible height, do not guess
	move.l	d0,PageLines(a4)
	move.l	d0,PageLeft(a4)
	bra.s	pgb_end
pgb_plain:
	clr.l	PageLines(a4)
	move.l	ConsoleI(a4),d1
	moveq.l	#0,d2
	CALLDOS	SetMode
pgb_end:
	movem.l	(sp)+,d0-d2/a0-a1/a6
	rts

PageEnd:
	movem.l	d0-d2/a0-a1/a6,-(sp)
	tst.l	PageLines(a4)
	beq.s	pge_end
	clr.l	PageLines(a4)
	move.l	ConsoleI(a4),d1
	moveq.l	#0,d2
	CALLDOS	SetMode			;always hand the shell back cooked
pge_end:
	movem.l	(sp)+,d0-d2/a0-a1/a6
	rts

; Call after writing one line. -> d0 = 0 when the reader asked to stop
PageLine:
	movem.l	d1-d3/a0-a1/a6,-(sp)
	tst.l	PageLines(a4)
	beq.w	pgl_go
	subq.l	#1,PageLeft(a4)
	bgt.w	pgl_go
	move.l	ConsoleO(a4),d1
	lea	MorePrompt(pc),a0
	move.l	a0,d2
	moveq.l	#MorePromptEnd-MorePrompt,d3
	CALLDOS	Write
	move.b	#CR,KeyBuf(a4)		;stands if the read fails
	move.l	ConsoleI(a4),d1
	lea	KeyBuf(a4),a0
	move.l	a0,d2
	moveq.l	#1,d3
	CALLDOS	Read
	move.l	ConsoleO(a4),d1
	lea	MoreErase(pc),a0
	move.l	a0,d2
	moveq.l	#MoreEraseEnd-MoreErase,d3
	CALLDOS	Write
	move.l	PageLines(a4),d0
	move.l	d0,PageLeft(a4)
	move.b	KeyBuf(a4),d0
	and.b	#$df,d0
	cmp.b	#'Q',d0
	beq.s	pgl_stop
pgl_go:
	moveq.l	#-1,d0
	bra.s	pgl_ret
pgl_stop:
	moveq.l	#0,d0
pgl_ret:
	movem.l	(sp)+,d1-d3/a0-a1/a6
	rts

; Console must already be in RAW mode. WINDOW STATUS REQUEST is answered by
; CSI <p1>;<p2>;<p3>;<p4> SP r, whose third field is the height.
; -> d0 = -1 when the console answered, 0 otherwise
PageRows:
	movem.l	d1-d4/d6-d7/a0-a1/a6,-(sp)
	move.l	ConsoleO(a4),d1
	lea	WinStatReq(pc),a0
	move.l	a0,d2
	moveq.l	#WinStatEnd-WinStatReq,d3
	CALLDOS	Write
	moveq.l	#0,d4			;fields finished
	moveq.l	#0,d6			;number being read
	moveq.l	#40,d7			;give up after this many bytes
pgr_next:
	tst.l	d7
	beq.w	pgr_fail
	subq.l	#1,d7
	move.l	ConsoleI(a4),d1
	move.l	#200000,d2		;0.2 s is plenty for a local console
	CALLDOS	WaitForChar
	tst.l	d0
	beq.w	pgr_fail
	move.l	ConsoleI(a4),d1
	lea	KeyBuf(a4),a0
	move.l	a0,d2
	moveq.l	#1,d3
	CALLDOS	Read
	cmp.l	#1,d0
	bne.w	pgr_fail
	move.b	KeyBuf(a4),d0
	cmp.b	#'r',d0
	beq.s	pgr_end
	cmp.b	#';',d0
	beq.s	pgr_field
	sub.b	#'0',d0
	bcs.w	pgr_next
	cmp.b	#9,d0
	bhi.w	pgr_next
	cmp.l	#1000,d6
	bcc.w	pgr_next		;absurd number: stop adding to it
	lsl.l	#1,d6
	move.l	d6,d1
	lsl.l	#2,d6
	add.l	d1,d6			;*10
	and.l	#$ff,d0
	add.l	d0,d6
	bra.w	pgr_next
pgr_field:
	addq.l	#1,d4
	cmp.l	#3,d4
	bne.s	pgr_clear
	move.l	d6,PageLines(a4)	;third field is the height
pgr_clear:
	moveq.l	#0,d6
	bra.w	pgr_next
pgr_end:
	cmp.l	#3,d4
	bcs.s	pgr_fail		;report was too short to trust
	moveq.l	#-1,d0
	bra.s	pgr_ret
pgr_fail:
	moveq.l	#0,d0
pgr_ret:
	movem.l	(sp)+,d1-d4/d6-d7/a0-a1/a6
	rts

WinStatReq:	dc.b	ESC,'[',' ','q'
WinStatEnd:
MorePrompt:	dc.b	'-- more -- (any key, Q quits)'
MorePromptEnd:
MoreErase:	dc.b	CR
		dcb.b	MorePromptEnd-MorePrompt,' '
		dc.b	CR
MoreEraseEnd:
		even
