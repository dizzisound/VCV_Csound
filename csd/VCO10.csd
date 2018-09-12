; Written by Iain McCurdy, 2010
;vco2 models a variety of waveforms based on the integration of band-limited impulses.
<CsoundSynthesizer>
<CsOptions>
-n -dm0 -+rtaudio=null -+rtmidi=null -b1024 -B4096
</CsOptions>
<CsInstruments>
sr		= 44100
ksmps	= 32
nchnls	= 1
0dbfs	= 1


gisine	ftgen		0, 0, 4096, 10, 1													;Sine wave

itmp	ftgen		1, 0, 16384, 7, 0, 2048, 1, 4096, 1, 4096, -1, 4096, -1, 2048, 0	;user defined waveform -1: trapezoid wave with default parameters
ift		vco2init	-1, 10000, 0, 0, 0, 1

		turnon	1

instr	1
	;GUI
	kWave		chnget	"Waveform"
    kWave       = int(kWave)
	kOctave		chnget	"Octave"
	kOctave		= int(kOctave)
	kSemitone	chnget	"Semitone"
	kSemitone	= int(kSemitone)
	knyx		chnget	"Harmonics"
	kpw			chnget	"PulseWidth"
	kphsDep		chnget	"PhaseDepth"
	kphsRte		chnget	"PhaseRate"
	kbw			chnget	"NoiseBW"	

	;VCO
	iamp		= 1.0
	kcps		= cpsoct(8 + kOctave + kSemitone/12)

	iporttime	=		0.05
	kporttime	linseg	0, 0.001, iporttime
	kpw		    portk	kpw, kporttime
	kenv		linsegr	0, 0.01, 1, 0.01, 0

	if kphsDep > 0.01 then
		kphs	poscil	kphsDep * 0.5, kphsRte, gisine		;Phase mod
		kphs	=		kphs + 0.5
	endif

	if		kWave==0 then	;Sawtooth
							asig	vco2	kenv*iamp, kcps, 16, kpw, kphs	

	elseif	kWave==1 then	;Square-PWM
							asig	vco2	kenv*iamp, kcps, 18, kpw, kphs

	elseif	kWave==2 then	;Sawtooth / Triangle / Ramp
							asig	vco2	kenv*iamp, kcps, 20, kpw, kphs

	elseif	kWave==3 then	;Pulse
							asig	vco2	kenv*iamp, kcps, 22, kpw, kphs

	elseif	kWave==4 then	;Parabola
							asig	vco2	kenv*iamp, kcps, 24, kpw, kphs

	elseif	kWave==5 then	;Square-noPWM
							asig	vco2	kenv*iamp, kcps, 26, kpw, kphs

	elseif	kWave==6 then	;Triangle
							asig	vco2	kenv*iamp, kcps, 28, kpw, kphs

	elseif	kWave==7 then	;User Wave
							asig	vco2	kenv*iamp, kcps, 30, kpw, kphs

	elseif	kWave==8 then	;Buzz
							asig	buzz	kenv*iamp, kcps*kphs,  knyx * sr /4 / kcps, gisine	

	elseif	kWave==9 then	;Noise
							asig	pinkish	4*iamp
							asig	butbp		asig, kcps, kcps * kbw
	endif	

			out		asig
endin
</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>
