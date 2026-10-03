; Paged console output. The includer provides the CALLDOS macro, the
; Read/Write/WaitForChar/IsInteractive/SetMode LVOs, the ESC/CR/fh_Type
; equates, and the frame vars ExecBase, ConsoleI, ConsoleO, KeyBuf, PageLines,
; PageLeft, PageCols, PagePos, PagePtr and PageBuf (PAGEBUF bytes), with
; ConsoleI/ConsoleO already holding Input()/Output().
; PageLines = 0 means everything scrolls.

PageBegin:
	movem.l	d0-d2/a0-a1/a6,-(sp)
	clr.l	PageLines(a4)
	clr.l	PageLeft(a4)
	clr.l	PageCols(a4)
	clr.l	PagePos(a4)
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
	move.l	PageCols(a4),d0
	beq.s	pgb_rows		;width unknown: trust the height alone
	cmp.l	#MoreTextEnd-MoreText+1,d0
	blt.s	pgb_plain		;the prompt would wrap: do not pause
pgb_rows:
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

; d0 = visible characters of a line -> d1 = screen rows it fills once a line
; wider than the window wraps. Clobbers d0/d2.
PageRowsOf:
	moveq.l	#1,d1
	tst.l	d0
	ble.s	pro_end
	move.l	PageCols(a4),d2
	beq.s	pro_end			;width unknown: one row
	cmp.l	d2,d0
	bls.s	pro_end
	add.l	d2,d0
	subq.l	#1,d0
	divu.w	d2,d0			;rounded up
	bvs.s	pro_full		;absurd length: it fills the page
	moveq.l	#0,d1
	move.w	d0,d1
	rts
pro_full:
	move.l	PageLines(a4),d1
pro_end:
	rts

; Show the prompt, wait for a key, start a fresh page.
; -> d0 = 0 when the key was Q. Clobbers d1-d3/a0-a1/a6.
PagePrompt:
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
	move.l	PageLines(a4),PageLeft(a4)
	move.b	KeyBuf(a4),d0
	and.b	#$df,d0
	cmp.b	#'Q',d0
	beq.s	ppr_stop
	moveq.l	#-1,d0
	rts
ppr_stop:
	moveq.l	#0,d0
	rts

; Write a0/d0 bytes a line at a time. Before a line goes out, pause when its
; rows do not fit on what is left of the page, so nothing scrolls away unread;
; a line taller than a whole page goes out a page at a time. Unpaged output
; goes out the same way. -> d0 = 0 when the reader stopped
PageText:
	movem.l	d1-d5/a0-a1/a6,-(sp)
	move.l	a0,d4			;start of the next line
	move.l	a0,d5
	add.l	d0,d5			;end of the text
ptx_line:
	cmp.l	d5,d4
	bcc.w	ptx_done
	move.l	d4,a0
ptx_scan:
	cmp.l	d5,a0
	bcc.s	ptx_have
	cmp.b	#LF,(a0)+
	bne.s	ptx_scan
ptx_have:
	move.l	a0,d3
	sub.l	d4,d3			;bytes in this line
ptx_part:
	tst.l	PageLines(a4)
	beq.s	ptx_whole		;unpaged
	move.l	d3,d0
	move.l	d4,a0
	cmp.b	#LF,-1(a0,d3.l)
	bne.s	ptx_vis			;a last line may end without LF
	subq.l	#1,d0
ptx_vis:
	bsr.w	PageRowsOf		;d1 = rows
	cmp.l	PageLeft(a4),d1
	ble.s	ptx_fits
	move.l	PageLeft(a4),d0
	cmp.l	PageLines(a4),d0
	bge.s	ptx_tall		;fresh page: the line is taller than it
	movem.l	d1-d3,-(sp)
	bsr.w	PagePrompt
	movem.l	(sp)+,d1-d3
	tst.l	d0
	beq.s	ptx_ret
	bra.s	ptx_part
ptx_tall:
	mulu.w	PageCols+2(a4),d0	;bytes that fill the page
	move.l	d3,-(sp)
	move.l	d0,d3
	move.l	ConsoleO(a4),d1
	move.l	d4,d2
	CALLDOS	Write
	add.l	d3,d4
	move.l	(sp)+,d0
	sub.l	d3,d0
	move.l	d0,d3			;what is still to come of this line
	clr.l	PageLeft(a4)		;full: the rest waits for a key
	bra.s	ptx_part
ptx_fits:
	sub.l	d1,PageLeft(a4)
ptx_whole:
	move.l	ConsoleO(a4),d1
	move.l	d4,d2
	CALLDOS	Write
	add.l	d3,d4
	bra.w	ptx_line
ptx_done:
	moveq.l	#-1,d0
ptx_ret:
	movem.l	(sp)+,d1-d5/a0-a1/a6
	rts

; VFPrintf into PageBuf instead of the console: d2 = format, d3 = arguments.
; A line is written whole by PageFlush, so its length is known before it
; goes out.
PageFmt:
	movem.l	d0-d1/a0-a3/a6,-(sp)
	lea	PageBuf(a4),a0
	add.l	PagePos(a4),a0
	move.l	a0,PagePtr(a4)
	move.l	d2,a0
	move.l	d3,a1
	lea	pgf_put(pc),a2
	lea	PagePtr(a4),a3		;RawDoFmt restores a3: keep the cursor in memory
	move.l	ExecBase(a4),a6
	jsr	-522(a6)		;RawDoFmt
	move.l	PagePtr(a4),a0
	lea	PageBuf+1(a4),a1
	sub.l	a1,a0			;bytes kept, NUL dropped
	move.l	a0,PagePos(a4)
	movem.l	(sp)+,d0-d1/a0-a3/a6
	rts
pgf_put:				;d0 = byte, a3 = &PagePtr
	move.l	a0,-(sp)
	move.l	(a3),a0
	move.b	d0,(a0)+
	move.l	a0,(a3)
	move.l	(sp)+,a0
	rts

; Write what PageFmt collected. -> d0 = 0 when the reader stopped
PageFlush:
	move.l	a0,-(sp)
	lea	PageBuf(a4),a0
	move.l	PagePos(a4),d0
	clr.l	PagePos(a4)
	bsr.w	PageText
	move.l	(sp)+,a0
	rts

; Console must already be in RAW mode. WINDOW STATUS REQUEST is answered by
; CSI <p1>;<p2>;<p3>;<p4> SP r: the third field is the height, the fourth the
; width.
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
	move.l	d6,PageCols(a4)		;fourth field is the width
	moveq.l	#-1,d0
	bra.s	pgr_ret
pgr_fail:
	moveq.l	#0,d0
pgr_ret:
	movem.l	(sp)+,d1-d4/d6-d7/a0-a1/a6
	rts

WinStatReq:	dc.b	ESC,'[',' ','q'
WinStatEnd:
MorePrompt:	dc.b	ESC,'[3;7m'		;italic, reversed
MoreText:	dc.b	'-- more -- (any key, Q quits)'
MoreTextEnd:	dc.b	ESC,'[23;27m'		;both off, other attributes kept
MorePromptEnd:
MoreErase:	dc.b	CR
		dcb.b	MoreTextEnd-MoreText,' '
		dc.b	CR
MoreEraseEnd:
		even
