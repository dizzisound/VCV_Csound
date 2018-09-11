;Vocoder written by Iain McCurdy, 2012 (iainmccurdy.org/csound.html) for Cabbage (cabbageaudio.com)
<CsoundSynthesizer>
<CsOptions>
-n -dm0 -+rtaudio=null -+rtmidi=null -b1024 -B4096
</CsOptions>
<CsInstruments>
sr      = 44100
ksmps   = 32
nchnls  = 2     ;2 in + 2 out
0dbfs   = 1


turnon  1       ;start instr 1

;TABLES FOR EXP SLIDER
giExp1		ftgen	0, 0, 256, -25, 0, 0.01, 256, 1.0
giExp2		ftgen	0, 0, 256, -25, 0, 1.0, 256, 12.0
giExp3		ftgen	0, 0, 256, -25, 0, 0.0001, 256, 1.0


opcode VocoderChannel, a, aakkkkii
	aMod, aCar, ksteepness, kbase, kbw, kincr, icount, inum	xin
	icount	=	icount + 1

	kcf	=	cpsmidinn(kbase+(icount*kincr))
	kbwcf	=	kbw*kcf

	if	kcf<15000 then
		aModF	butbp	aMod, kcf, kbwcf
		if ksteepness=1 then
			aModF	butbp	aModF, kcf, kbwcf
		endif
		aEnv 	follow2	aModF, 0.05, 0.05
		aCarF	butbp		aCar, kcf, kbwcf
		if ksteepness=1 then	
			aCarF	butbp	aCarF, kcf, kbwcf
		endif
	endif

	amix	init	0
	
	if	icount < inum	then
		amix	VocoderChannel	aMod, aCar, ksteepness, kbase, kbw, kincr, icount, inum
	endif

		xout	amix + (aCarF*aEnv)
endop


instr	1	;Vocoder
	;Read in widgets
	kbw			chnget	"bw"						;Band Width
	kbw			tablei	kbw, giExp1, 1
	kincr		chnget	"incr"						;Band Spacing 
	kincr		tablei	kincr, giExp2, 1
	kBPGain		chnget	"BPGain"					;Band Pass Filter Gain
	kBPGain		tablei	kBPGain, giExp3, 1
	kHPGain		chnget	"HPGain"					;High Pass Filter Gain
	kHPGain		tablei	kHPGain, giExp3, 1
	kbase		chnget	"base"						;Base
	kCarFilter	chnget	"carFilter"					;LP filtering on carrier
	ksteepness	chnget	"steepness"					;Filter Steepness (12dB or 24dB)
	kgate		chnget	"gate"						;Noise Gate on modulator

	;Vocoder
	aMod	inch	1

	;Gate modulator signal
	if kgate==1 then
		krms	rms	aMod
		kgate1	=	(krms<0.05?0:1)
		kgate1	port	kgate1, 0.01
		agate	interp	kgate1
		aMod	=	aMod * agate
	endif

	aCar	inch	2
	if kCarFilter == 1 then
		aCar	tone	aCar, 12000                 ;use if carrier is PULSE
	endif 

	icount	= 0
	inum	= 32
	amix	VocoderChannel	aMod, aCar, ksteepness, kbase, kbw, kincr, icount, inum

	;HIGH-PASS CHANNEL
	kHPcf	=	cpsmidinn(kbase+(inum * kincr)+1)
	kHPcf	limit	kHPcf, 2000, 18000

	aModHP	buthp	aMod, kHPcf
	aEnv	follow2	aModHP,0.01,0.01
	aCarHP	buthp	aCar, kHPcf
	amix	=	(amix * kBPGain * 5)+(aCarHP * aEnv * kHPGain * 3)

			outch 	1, amix*2
endin
</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>

