;;Stereo Chorus, René Feb 2015
<CsoundSynthesizer>
<CsOptions>
-n -dm0 -+rtaudio=null -+rtmidi=null -b1024 -B4096
</CsOptions>
<CsInstruments>
sr		= 44100
ksmps	= 32    ;128
nchnls	= 2     ;2 in + 2 out
0dbfs	= 1


turnon  1       ;start instr 1


instr	1	;Stereo Chorus
	k_Delay_L	chnget	"Delay_L"			;Slider +0.5 / +20
	k_Depth_L	chnget	"Depth_L"			;Slider 0 / +0.99
	k_Rate_L	chnget	"Rate_L"			;Slider 0 / +1
	k_Delay_R	chnget	"Delay_R"			;Slider +0.5 / +20
	k_Depth_R	chnget	"Depth_R"			;Slider 0 / +0.99
	k_Rate_R	chnget	"Rate_R"			;Slider 0 / +1
	k_Cross 	chnget	"Cross"				;Slider 0 / +1
	k_Wet		chnget	"Wet"				;Slider 0 / +1


	imaxdel     =		200					;maximum delay 200 ms

    ainL, ainR  ins

	;Left channel
	aTri_L      lfo			k_Delay_L * k_Depth_L, k_Rate_L, 1		;Triangle
	aDelay_L    vdelay		ainL + k_Cross * ainR , aTri_L + k_Delay_L, imaxdel
	aLeft       ntrpol		ainL , aDelay_L, k_Wet

	;Right channel
	aTri_R      lfo			k_Delay_R * k_Depth_R, k_Rate_R, 1		;Triangle
	aDelay_R    vdelay		ainR + k_Cross * ainL , aTri_R + k_Delay_R, imaxdel
	aRight		ntrpol		ainR, aDelay_R, k_Wet

                outs        aLeft, aRight
endin
</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>
