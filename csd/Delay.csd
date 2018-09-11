;;Stereo Delay, René Feb 2015
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


opcode Filter_1PLP, a, ak
	;State variable 1 pole LP filter: Reaktor module 1-Pole Filter
	;Inputs:	
	;	aIn	Audio in
	;	kW	Cutoff	 (kW = cpsmidinn(kP) * 2 * $M_PI / sr; max(kW)= 1)

	        setksmps	1
	alpd    init    	0

	aIn, kW	xin
	alp	= alpd + kW * (aIn - alpd)
	alpd	= alp
		xout  alp
endop


instr	1	;Stereo Delay
	k_Time_L		chnget	"Time_L"			;Slider 0 / +600
	k_Time_R		chnget	"Time_R"			;Slider 0 / +600
	k_Fine_L		chnget	"Fine_L"			;Slider 0 / +5
	k_Fine_R		chnget	"Fine_R"			;Slider 0 / +5
	k_Cutoff		chnget	"Cutoff"			;Slider 0 / +1
	k_FB			chnget	"Feedback"			;Slider 0 / +1
	k_Cross 		chnget	"Cross"				;Slider 0 / +1
	k_Wet			chnget	"Wet"				;Slider 0 / +1


    a_Filter_L	init	0
	a_Filter_R	init	0

	imaxdel		=		1000												;maximum delay 1000 ms

    ainL, ainR  ins

	;Left channel
	a_L         vdelay			ainL + k_Cross * ainR + k_FB * a_Filter_L, k_Time_L + k_Fine_L, imaxdel
	a_Filter_L  Filter_1PLP		a_L, k_Cutoff
	aLeft       ntrpol			ainL , a_Filter_L, k_Wet

	;Right channel	
	a_R			vdelay			ainR + k_Cross * ainL + k_FB * a_Filter_R, k_Time_R + k_Fine_R, imaxdel
	a_Filter_R  Filter_1PLP		a_R, k_Cutoff
	aRight		ntrpol			ainR, a_Filter_R, k_Wet

				                outs        aLeft, aRight
endin
</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>
