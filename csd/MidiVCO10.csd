; Written by Iain McCurdy, 2010
vco2 models a variety of waveforms based on the integration of band-limited impulses.
<CsoundSynthesizer>
<CsOptions>
-n -dm0 -+rtaudio=null -b1024 -B4096 -+rtmidi=alsa -Ma
</CsOptions>
<CsInstruments>
sr      = 44100
ksmps   = 32
nchnls  = 1
0dbfs   = 1


gisine	ftgen       0, 0, 4096, 10, 1													;Sine wave

itmp	ftgen	    1, 0, 16384, 7, 0, 2048, 1, 4096, 1, 4096, -1, 4096, -1, 2048, 0	;user defined waveform: trapezoid wave
ift		vco2init	-1, 10000, 0, 0, 0, 1

		massign	0, 2		;Midi router to instr 2
		turnon	1			;GUI update


instr	1	;GUI
	gkWave		chnget	"Waveform"
	kOctave		chnget	"Octave"
	gkOctave	= int(kOctave)
	kSemitone	chnget	"Semitone"
	gkSemitone	= int(kSemitone)
	gknyx		chnget	"Harmonics"
	gkpw		chnget	"PulseWidth"
	gkphsDep	chnget	"PhaseDepth"
	gkphsRte	chnget	"PhaseRate"
	gkbw		chnget	"NoiseBW"	

    kgate      active  2
               chnset  kgate, "Gate"
endin

instr	2	;Poly Midi Instrument
	icps		cpsmidi
	iamp		ampmidi	1

	;PITCH BEND=================================================================
	iSemitoneBendRange =	2
	imin		=		0
	imax		=		iSemitoneBendRange / 12
	kbend		pchbend	imin, imax
	ioct		=		octcps(icps)
	kcps		=		cpsoct(ioct + kbend + gkOctave + gkSemitone/12)
	;========================================================================

	iporttime	=			0.05
	kporttime	linseg		0, 0.001, iporttime
	kpw		    portk		gkpw, kporttime
	kenv		linsegr 	0, 0.01, 1, 0.01, 0

	if gkWave==8 then				;buzz
		asig	buzz		kenv*iamp, kcps,  gknyx * sr /4 / kcps, gisine	
	elseif gkWave==9 then			;noise
		asig	pinkish	4*iamp
		asig	butbp		asig, kcps, kcps * gkbw
	else								;vco2
		kmode = gkWave * 2
		if gkphsDep > 0.01 then
			kmode = kmode + 16
		endif

		kphs	poscil		gkphsDep*0.5, gkphsRte, gisine			;Phase mod
		kphs	=			kphs + 0.5

;*** All this to reduce click during reinit !!!
		kinit init 0
		kChanged	changed	gknyx, kmode
		if	kChanged==1	then
			kinit = 1
		endif

		if kinit == 1 then
			Reinit_fade:
			kfade		linseg		1, 0.01, 0, 0.01, 1
			rireturn
			ktrig1		trigger	kfade, 0.01, 1
			ktrig2		trigger	kfade, 0.99, 0
			if ktrig1==1 then
				reinit	Reinit_vco
			endif
			if ktrig2==1 then
				kinit = 0
				reinit	Reinit_fade
			endif
		endif
;***

		Reinit_vco:
		asig		vco2		kenv*kfade*iamp, kcps, i(kmode), kpw, kphs, i(gknyx)/2
					rireturn
	endif
				out		asig
endin
</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>
