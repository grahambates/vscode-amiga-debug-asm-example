		incdir	"include"
		include	"hw.i"
		include	"debug.i"
		include	"P61.config.i"

		xdef	_start
_start:
		include	"PhotonsMiniWrapper1.04.i"


********************************************************************************
* Constants:
********************************************************************************

BOB_W = 32
BOB_H = 16
SCREEN_W = 320
SCREEN_H = 256
BPLS = 5

DMASET = DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER!DMAF_COPPER!DMAF_BLITTER
INTSET = INTF_SETCLR!INTF_INTEN!INTF_VERTB

;-------------------------------------------------------------------------------
; Derived

BOB_BW = BOB_W/8
BOB_SIZE = BOB_BW*BOB_H*BPLS
BOB_MOD = SCREEN_BW-BOB_BW

COLORS = 1<<BPLS
SCREEN_BW = SCREEN_W/16*2					; byte-width of 1 bitplane line
SCREEN_MOD = SCREEN_BW*(BPLS-1)					; modulo (interleaved)
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS				; byte size of screen buffer

DIW_XSTRT = ($242-SCREEN_W)/2
DIW_YSTRT = ($158-SCREEN_H)/2
DIW_XSTOP = DIW_XSTRT+SCREEN_W
DIW_YSTOP = DIW_YSTRT+SCREEN_H


********************************************************************************
Demo:
********************************************************************************
; Register debug resources:
		DebugRegisterResource DebugResImage
		DebugRegisterResource DebugResBob
		DebugRegisterResource DebugResColors
		DebugRegisterResource DebugResCop

; Install VBI:
		move.l	#Interrupt,$6c(a4)
		move.w	#INTSET,intena(a6)

; Set bpl pointers in copper:
		lea	Image,a0
		lea	CopBplPt+2,a1
		moveq	#BPLS-1,d0
.bpll:		move.l	a0,d1
		swap	d1
		move.w	d1,(a1)
		move.w	a0,4(a1)
		addq.w	#8,a1
		lea	SCREEN_BW(a0),a0
		dbf	d0,.bpll

; Init music:
		lea	Module,a0
		sub.l	a1,a1
		sub.l	a2,a2
		moveq	#0,d0
		bsr	P61_Init

; Init copper:
		bsr	WaitEOF
		move.l	#Cop,cop1lc(a6)
		move.w	#DMASET,dmacon(a6)

; Load palette:
		lea	Colors(pc),a0
		lea	color00(a6),a1
		moveq	#COLORS-1,d0
.col:		move.w	(a0)+,(a1)+
		dbf	d0,.col

;-------------------------------------------------------------------------------
.mainLoop:
; Clear
		move.l	#$1000000,bltcon0(a6)
		move.l	#Image+SCREEN_BW*200*BPLS,bltdpt(a6)
		clr.w	bltdmod(a6)
		move.l	#-1,bltafwm(a6)
		move.w	#(56*BPLS)<<6!SCREEN_BW>>1,bltsize(a6)

; Blit bobs:
		lea	Sinus32(pc),a0
		lea	Sinus40(pc),a1
		lea	BltconTbl(pc),a5
		move.b	VBlank+3(pc),d0				; d0 = frameCounter
		and.w	#$ff,d0
		move.w	#(BOB_H*BPLS)<<6!BOB_BW>>1,d5		; d5 = bltsize

		; Common blitter regs
		bsr	WaitBlitter
		move.l	#BOB_MOD<<16!BOB_BW,bltcmod(a6)
		move.l	#BOB_BW<<16!BOB_MOD,bltamod(a6)

		moveq	#16-1,d1
.l:
		move.w	d0,d3					; d3 = frameCounter + i
		add.w	d1,d3

		; x = i * 16 + sinus32[(frameCounter + i) % sizeof(sinus32)] * 2;
		move.w	d1,d2
		lsl.w	#4,d2
		moveq	#0,d4
		move.w	d3,d4
		divu	#Sinus32E-Sinus32,d4
		swap.w	d4
		move.b	(a0,d4.w),d4
		add.w	d4,d4
		add.w	d4,d2					; d2 = x

		; y = sinus40[((frameCounter + i) * 2) & 63] / 2
		add.w	d3,d3
		and.w	#63,d3
		move.b	(a1,d3.w),d3
		lsr.w	d3					;d3 = y

		; Channel bpl pointers:
		; a4 = bob mask (A)
		lea	Bob,a4
		; add offset: 32 / 8 * 10 * 16 * (i % 6)
		move.l	d1,d4
		divu	#6,d4
		swap.w	d4
		mulu	#BOB_BW*BOB_H*10,d4
		add.l	d4,a4
		; a3 = bob data (B)
		lea	BOB_BW(a4),a3
		; a2 = dest (C/D)
		lea	Image+SCREEN_BW*BPLS*200,a2
		mulu	#SCREEN_BW*BPLS,d3			; add y offset
		add.l	d3,a2
		move.w	d2,d4					; add x offset
		lsr.w	#3,d4
		add.l	d4,a2

		; Look up offset for bltcon table
		move.w	d2,d4
		and.w	#15,d4
		lsl.w	#2,d4
		move.l	(a5,d4.w),d6				; d6 = bltcon

		bsr	WaitBlitter
		move.l	d6,bltcon0(a6)
		movem.l	a2-a4,bltcpt(a6)
		move.l	a2,bltdpt(a6)
		move.w	d5,bltsize(a6)

		dbf	d1,.l

; Debug overlay:
		DebugClear
		swap.w	d0					; move frame counter to upper word for x offset
		clr.w	d0
		move.l	#100<<16!(200*2),d1
		add.l	d0,d1
		move.l	#400<<16!(220*2),d2
		add.l	d0,d2
		DebugFilledRectDyn d1,d2,#$ff00
		move.l	#90<<16!(190*2),d1
		add.l	d0,d1
		DebugRectDyn d1,d2,#$ff
		move.l	#130<<16!(209*2),d1
		add.l	d0,d1
		DebugTextDyn d1,OverlayText,#$ff00ff

		DebugStartIdle
		bsr	WaitEOF
		DebugStopIdle

		btst	#CIAB_GAMEPORT0,ciaa			; Left mouse button not pressed?
		bne	.mainLoop
		rts


********************************************************************************
Interrupt:
********************************************************************************
		movem.l	d0-a6,-(sp)
		btst	#5,intreqr+1(a6)
		beq.s	.notvb

		; Modify scrolling in copper list
		lea	CopScroll,a0
		lea	Sinus15,a1
		move.w	VBlank+2(pc),d0
		and.w	#63,d0
		move.b	(a1,d0.w),d0
		move.w	d0,d1
		lsl.w	#4,d1
		or.w	d1,d0
		move.w	d0,(a0)

		; Play music
		bsr	P61_Music

		; Increment frame counter:
		lea.l	VBlank(pc),a0
		addq.l	#1,(a0)

		moveq	#INTF_VERTB,d0
		move.w	d0,intreq(a6)
		move.w	d0,intreq(a6)
.notvb:		movem.l	(sp)+,d0-a6
		rte

		include	"P6112-Play.i"


********************************************************************************
* Data
********************************************************************************

VBlank		dc.l	0

OverlayText:	dc.b	"This is a WinUAE debug overlay",0
		even

; Table for combined minterm and shifts for bltcon0/bltcon1
BltconTbl:
		dc.l	$0fca0000,$1fca1000,$2fca2000,$3fca3000
		dc.l	$4fca4000,$5fca5000,$6fca6000,$7fca7000
		dc.l	$8fca8000,$9fca9000,$afcaa000,$bfcab000
		dc.l	$cfcac000,$dfcad000,$efcae000,$ffcaf000

Colors:		incbin	"image.pal"

Sinus15:
		dc.b	8,8,9,10,10,11,12,12
		dc.b	13,13,14,14,14,15,15,15
		dc.b	15,15,15,15,14,14,14,13
		dc.b	13,12,12,11,10,10,9,8
		dc.b	8,7,6,5,5,4,3,3
		dc.b	2,2,1,1,1,0,0,0
		dc.b	0,0,0,0,1,1,1,2
		dc.b	2,3,3,4,5,5,6,7

Sinus40:
		dc.b	20,22,24,26,28,30,31,33
		dc.b	34,36,37,38,39,39,40,40
		dc.b	40,40,39,39,38,37,36,35
		dc.b	34,32,30,29,27,25,23,21
		dc.b	19,17,15,13,11,10,8,6
		dc.b	5,4,3,2,1,1,0,0
		dc.b	0,0,1,1,2,3,4,6
		dc.b	7,9,10,12,14,16,18,20

Sinus32:
		dc.b	16,18,20,22,24,25,27,28
		dc.b	30,30,31,32,32,32,32,31
		dc.b	30,30,28,27,25,24,22,20
		dc.b	18,16,14,12,10,8,7,5
		dc.b	4,2,2,1,0,0,0,0
		dc.b	1,2,2,4,5,7,8,10
		dc.b	12,14,16
Sinus32E:

; Debug resource data:
DebugResImage:	DebugResourceBitmap Image,"image.bpl",SCREEN_W,SCREEN_H,BPLS,DEBUG_RESOURCE_BITMAP_INTERLEAVED
DebugResBob:	DebugResourceBitmap Bob,"bob.bpl",BOB_W,BOB_H*6,BPLS,DEBUG_RESOURCE_BITMAP_INTERLEAVED|DEBUG_RESOURCE_BITMAP_MASKED
DebugResColors:	DebugResourcePalette Colors,"image.pal",COLORS
DebugResCop:	DebugResourceCopperlist Cop,"Cop",CopE-Cop


*******************************************************************************
		data_c
*******************************************************************************

Bob:		incbin	"bob.bpl"
Image:		incbin	"image.bpl"
Module:		incbin	"testmod.p61"

Cop:
		dc.w	fmode,0
		dc.w	diwstrt,DIW_YSTRT<<8!DIW_XSTRT
		dc.w	diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
		dc.w	ddfstrt,(DIW_XSTRT-17)>>1&$fc
		dc.w	ddfstop,(DIW_XSTRT-17+(SCREEN_W>>4-1)<<4)>>1&$fc
		dc.w	bpl1mod,SCREEN_MOD
		dc.w	bpl2mod,SCREEN_MOD
		dc.w	bplcon0,BPLS<<12!$200
		dc.w	bplcon1
CopScroll:	dc.w	0
CopBplPt:	rept	BPLS*2
		dc.w	bpl0pt+REPTN*2,0
		endr
		dc.w	color00,$000
		dc.w	$4101,$ff00,color00,$111		; line $41
		dc.w	$4201,$ff00,color00,$222		; line $42
		dc.w	$4301,$ff00,color00,$333		; line $43
		dc.w	$4401,$ff00,color00,$444		; line $44
		dc.w	$4501,$ff00,color00,$555		; line $45
		dc.w	$4601,$ff00,color00,$666		; line $46
		dc.w	$4701,$ff00,color00,$777		; line $47
		dc.w	$4801,$ff00,color00,$888		; line $48
		dc.w	$4901,$ff00,color00,$999		; line $49
		dc.w	$4a01,$ff00,color00,$aaa		; line $4a
		dc.w	$4b01,$ff00,color00,$bbb		; line $4b
		dc.w	$4c01,$ff00,color00,$ccc		; line $4c
		dc.w	$4d01,$ff00,color00,$ddd		; line $4d
		dc.w	$4e01,$ff00,color00,$eee		; line $4e
		dc.w	$4f01,$ff00,color00,$fff		; line $4e
		dc.l	-2					; end copper list
CopE:
