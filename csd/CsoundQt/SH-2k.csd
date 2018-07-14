;;SH - 2k Reaktor émulation, René Feb 2015
<CsoundSynthesizer>
<CsOptions>
-dm0
</CsOptions>
<CsInstruments>
sr		= 48000
ksmps	= 128
nchnls	= 2
0dbfs	= 1


; MESSAGE :


;;Channels init
	;Modulator
	chn_k	"MOD_Rate",		1
	chn_k	"MOD_Wave",		1
	;VCO
	chn_k	"VCO_Mod",		1
	chn_k	"VCO_LFOMW",		1
	chn_k	"VCO_VCO",		1
	chn_k	"VCO_PWidth",		1
	chn_k	"VCO_Range",		1
	chn_k	"VCO_PWM",		1
	;Source Mixer
	chn_k	"Source_Pulse",		1
	chn_k	"Source_Saw",		1
	chn_k	"Source_Fine",		1
	chn_k	"Source_SubOsc",	1
	chn_k	"Source_Noise",		1
	chn_k	"Source_Down",		1
	chn_k	"Source_Wave",		1
	;ENV
	chn_k	"ENV_A",			1
	chn_k	"ENV_D",			1
	chn_k	"ENV_S",			1
	chn_k	"ENV_R",			1
	;VCA
	chn_k	"VCA_A",			1
	chn_k	"VCA_R",			1
	;VCF
	chn_k	"VCF_Freq",		1
	chn_k	"VCF_Res",		1
	chn_k	"VCF_Env",		1
	chn_k	"VCF_Mod",		1
	chn_k	"VCF_Kybd",		1
	chn_k	"VCF_VCF",		1
	chn_k	"VCF_Mode",		1
	;Portamento
	chn_k	"PORT_Porta",		1
	;Global + Misc
	chn_k	"OscSprd",			1
	chn_k	"PanSprd",			1
	chn_k	"Pan",			1
	chn_k	"PanRnd",			1
	chn_k	"Synth_Mode",		1
	chn_k	"Vel_Mode",		1
	chn_k	"VCA_Mode",		1
	chn_k	"Legato_Mode",		1
	chn_k	"Volume",			1

	;Stereo Delay
	chn_k	"SD_Time_L",		1
	chn_k	"SD_Fine_L",		1
	chn_k	"SD_Time_R",		1
	chn_k	"SD_Fine_R",		1
	chn_k	"SD_CutOff",		1
	chn_k	"SD_FB",			1
	chn_k	"SD_Cross",		1
	chn_k	"SD_Wet",			1
	chn_k	"SD_OnOff",		1

	;Stereo Chorus
	chn_k	"CHO_Delay_L",		1
	chn_k	"CHO_Depth_L",	1
	chn_k	"CHO_Rate_L",		1
	chn_k	"CHO_Delay_R",	1
	chn_k	"CHO_Depth_R",	1
	chn_k	"CHO_Rate_R",		1
	chn_k	"CHO_OnOff",		1

	;Active voice
	chn_k	"Voices",			2


;;Variables init
	;Modulator
	gkTri				init	0
	gkLFO			init	0
	;VCO + VCF
	gkMidiPitchBend		init	0								;Midi PitchBend	Range -1 / +1 (with sliders VCO_VCO and VCF_VCF)
	;VCO
	gkMidiController1	init	0								;Controller 1	Range 0 / +1(with slider VCO_LFOMW)
	;Randomize generator
	gkRandomize		init	0
	;Previous note for portamento
	gkPrevNum		init	60
	;New Note for envelope reinit
	gkNewNote		init	0								;used only in mono mode
	;Audio out
	gaSynth_L		init	0
	gaSynth_R		init	0
	gaCHORUS_L		init	0
	gaCHORUS_R		init	0

;;Tables
	giTabKnob1		ftgen		0, 0, 1024, -7, 0, 512, 4.0, 512, 28.0	;table for non linear knob VCO_Mod
	giTabKnob2		ftgen		0, 0, 1024, -7, 0, 512, 0.9, 512, 1.0	;table for non linear knob VCF_Res
	giTabKnob3		ftgen		0, 0, 1024, -7, 0, 512, 0.1, 512, 0.5	;table for non linear knob PORT_Porta

;;Midi router
	massign	0, 2											;all MIDI data directed to instr 2

;;Turn On instrument
	turnon	1	;GUI + Modulator + Midi controllers + Randomize generator
	turnon	5	;Dual Chorus
	turnon	6	;Stereo Delay

;;Opcodes
opcode Filter_1PLP, a, ak
	;State variable 1 pole LP filter: Reaktor module 1-Pole Filter
	;Inputs:	
	;	aIn	Audio in
	;	kW	Cutoff	 (kW = cpsmidinn(kP) * 2 * $M_PI / sr; max(kW)= 1)

		setksmps	1

	alpd		init	0

	aIn, kW	xin

	alp	= alpd + kW * (aIn - alpd)
	alpd	= alp
		xout  alp
endop

opcode Filter_2P, aaa, akk
	;State variable 2 poles LP BP HP filter: Reaktor module 2-Poles Filter
	;Inputs:
	;	aIn	Audio in
	;	kW	Cutoff
	;	kd	Reso

		setksmps	1

	abpd		init	0
	alpd		init	0

	aIn, kW, kd   xin

	ahp	= aIn - kd*abpd - alpd
	abp	= kW*ahp + abpd
	alp	= kW*abp + alpd
	abpd	= abp
	alpd	= alp
		xout  alp, abp, ahp
endop

opcode ADSR, k, kiiiik
	;Envelope with ADSR
	;Inputs:
	;	kGate		Gate		0 - 1
	;	iAtt			Attack	0 / +80 (log)
	;	iDec		Decay	0 / +80 (log)
	;	iSus		Sustain	0 / 1
	;	iRel		Release	0 / +80 (log)
	;	kVel		Velocity	0 / 1

	;Output:
	;	kEnv		Envelope	0 / 1 (scaled by the velocity)


	kGate, iAtt, iDec, iSus, iRel, kVel 	xin

	;Function db(x) = pow(10; x/20) for Att, Dec,Rel in sec
	iAtt_time		= 0.001 * db(iAtt)
	iDec_time		= 0.001 * db(iDec)
	iRel_time		= 0.001 * db(iRel)

	;A is a linear increasing segment from zero to 1 (minimum attack time is ksmps / sr in seconds)
	;D is an exponential decreasing segment from 1 to Sustain value
	;R is an exponential decreasing segment from Sustain value to 0

	;Formula for exponential decreasing:
		; D segment: 	Value = Start - (Start - End) * (1 - exp( - t / d)) with d = Dec value in second
		; R segment: 	Value = Start * exp( - t / r) with r = Rel value in second

	idt		=	ksmps / sr			;idt is minimum attack time = 2.6 ms for ksmps = 128
	idatt		=	idt / iAtt_time

	if idatt > 1 then
		idatt = 1
	endif

	iddec		=	exp(-idt / iDec_time)
	idrel		=	exp(-idt / iRel_time)

	kEnv		init	0

	kflag		trigger	kGate, 0.5, 0
	if kflag == 1 then
		kflagA = 1
	endif

	if kGate == 1 then
		if kflagA == 1 && kEnv <= (1-idatt) then
			kEnv	= kEnv + idatt
		else
			kflagA	= 0
			kEnv		= iSus + (kEnv - iSus) * iddec
		endif
	else
		kEnv		= kEnv * idrel
	endif
		xout		kEnv * kVel
endop

opcode AR, k, kiik
	;Envelope with AR
	;Inputs:
	;	kGate	Gate		0 - 1
	;	iAtt		Attack	0 / +80 (log)
	;	iRel		Release	0 / +80 (log)
	;	kVel		Velocity	0 / 1

	;Output:
	;	kEnv		Envelope	0 / 1 (scaled by the velocity)

	kGate, iAtt, iRel, kVel 	xin

	;Function db(x) = pow(10; x/20) for Att, Dec,Rel in sec
	iAtt_time		= 0.001 * db(iAtt)
	iRel_time		= 0.001 * db(iRel)

	;A is a linear increasing segment from zero to 1 (minimum attack time is ksmps / sr in seconds)
	;R is an exponential decreasing segment from 1 to 0

	;Formula for R segment exponential decreasing: 	Value = Start * exp( - t / r) with r = Rel value in second

	idt		=	ksmps / sr			;idt is minimum attack time = 2.6 ms for ksmps = 128
	idatt		=	idt / iAtt_time

	if idatt > 1 then
		idatt = 1
	endif

	idrel		=	exp(-idt / iRel_time)

	kEnv		init	0

	if kGate == 1 then
		if kEnv <= (1-idatt) then
			kEnv	= kEnv + idatt
		else
			kEnv		= 1
		endif
	else
		kEnv		= kEnv * idrel
	endif
		xout		kEnv * kVel
endop

instr	1	;GUI + Modulator + Midi controllers + Randomize generator
	;Number of active voices
	kinstr3	active	3
	kinstr4	active	4

	ktrig		metro	10								;read widgeets 10 times per second

	if (ktrig == 1)	then

	;Number of active voices
						chnset	(kinstr3 + kinstr4), "Voices" 
	;Modulator:
	gkMOD_Rate		chnget	"MOD_Rate"				;Slider  -90 / +14.8
	gkMOD_Wave		chnget	"MOD_Wave"				;Menu 0 = Triangle, 1 = Square, 2 = Random, 3 = Noise
	;VCO
	kVCO_Mod			chnget	"VCO_Mod"				;Slider   0 / +1
	gkVCO_Mod		table		kVCO_Mod, giTabKnob1, 1		;value 0 - 28 non linear
	gkVCO_LFOMW	chnget	"VCO_LFOMW"				;Slider   0 / +9
	gkVCO_VCO		chnget	"VCO_VCO"				;Slider   0 / +12
	gkVCO_PWidth		chnget	"VCO_PWidth"				;Slider   0 / +0.82
	gkVCO_Range		chnget	"VCO_Range"				;Menu 0 = 2', 1 = 4', 2 = 8', 3 = 16'  (24, 12, 0, -12)
	gkVCO_PWM		chnget	"VCO_PWM"				;Menu 0 = LFO, 1 = Man, 2 = Env
	;Source Mixer
	gkSource_Pulse	chnget	"Source_Pulse"				;Slider   0 / +0.25
	gkSource_Saw		chnget	"Source_Saw"				;Slider   0 / +0.25
	gkSource_Fine		chnget	"Source_Fine"				;Slider  -1 / +1
	gkSource_SubOsc	chnget	"Source_SubOsc"			;Slider   0 / +0.25
	gkSource_Noise	chnget	"Source_Noise"				;Slider   0 / +0.25
	gkSource_Down	chnget	"Source_Down"				;Menu 0 = 0 Oct, 1 = 1 Oct, 2 = 2 Oct (0, -12, -24)
	gkSource_Wave	chnget	"Source_Wave"				;Menu 0 = Pulse, 1 = Triangle, 2 = Saw
	;ENV
	gkENV_A			chnget	"ENV_A"					;Slider 0 / +72
	gkENV_D			chnget	"ENV_D"					;Slider 0 / +86
	gkENV_S			chnget	"ENV_S"					;Slider 0 / +1
	gkENV_R			chnget	"ENV_R"					;Slider 0 / +86
	;VCA
	gkVCA_A			chnget	"VCA_A"					;Slider 0 / +60
	gkVCA_R			chnget	"VCA_R"					;Slider 0 / +70
	;VCF
	gkVCF_Freq		chnget	"VCF_Freq"				;Slider -14 / +126
	kVCF_Res			chnget	"VCF_Res"				;Slider   0 / +0.985
	gkVCF_Res			table		kVCF_Res, giTabKnob2, 1		;value 0 - 1 non linear
	gkVCF_Env			chnget	"VCF_Env"				;Slider +15 / +100
	gkVCF_Mod		chnget	"VCF_Mod"				;Slider   0 / +65
	gkVCF_Kybd		chnget	"VCF_Kybd"				;Slider   0 / +1
	gkVCF_VCF		chnget	"VCF_VCF"				;Slider   0 / +24
	gkVCF_Mode		chnget	"VCF_Mode"				;Menu 0 = HPF, 1 = BPF, 2 = LPF
	;Portamento
	kPORT_Porta		chnget	"PORT_Porta"				;Slider   -65 / +35
	gkPORT_Porta		table		kPORT_Porta, giTabKnob3, 1	;value 0 - 0.5 non linear
	;Global + Not included in module opcode
	gkOscSprd			chnget	"OscSprd"					;Slider   0 / +1
	gkPanSprd			chnget	"PanSprd"					;Slider   0 / +1
	kPan				chnget	"Pan"					;Slider   -1 / +1
	gkPan				=			(kPan+1) * 0.5				;gkPan 0 / +1
	gkPanRnd			chnget	"PanRnd"					;Slider   0 / +1
	gkSynth_Mode		chnget	"Synth_Mode"				;Menu 0 = Poly, 1 = Mono
	gkVel_Mode		chnget	"Vel_Mode"				;Check box 0 = Off, 1 = On
	gkVCA_Mode		chnget	"VCA_Mode"				;Menu 0 = Env, 1 = Gate
	gkLegato_Mode	chnget	"Legato_Mode"				;Check box 0 = Off, 1 = On
	gkVol				chnget	"Volume"					;Slider   0 / +1

	;Stereo Delay
	gkSD_Time_L		chnget	"SD_Time_L"				;Slider 0 / +600
	gkSD_Fine_L		chnget	"SD_Fine_L"				;Slider 0 / +5
	gkSD_Time_R		chnget	"SD_Time_R"				;Slider 0 / +600
	gkSD_Fine_R		chnget	"SD_Fine_R"				;Slider 0 / +5
	gkSD_OnOff		chnget	"SD_OnOff"				;CheckBox 0 = Delay Off, 1 = Delay On
	gkSD_CutOff		chnget	"SD_CutOff"				;Slider 0 / +1 (kW = cpsmidinn(kP) * 2 * $M_PI / sr; max(kW)= 1)
	gkSD_FB			chnget	"SD_FB"					;Slider 0 / +1
	gkSD_Cross		chnget	"SD_Cross"				;Slider 0 / +1
	gkSD_Wet			chnget	"SD_Wet"					;Slider 0 / +1

	;Chorus
	gkCHO_Delay_L	chnget	"CHO_Delay_L"				;Slider +0.5 / +20
	gkCHO_Depth_L	chnget	"CHO_Depth_L"				;Slider 0 / +0.99
	gkCHO_Rate_L		chnget	"CHO_Rate_L"				;Slider 0 / +1
	gkCHO_Delay_R	chnget	"CHO_Delay_R"				;Slider +0.5 / +20
	gkCHO_Depth_R	chnget	"CHO_Depth_R"				;Slider 0 / +0.99
	gkCHO_Rate_R		chnget	"CHO_Rate_R"				;Slider 0 / +1
	gkCHO_OnOff		chnget	"CHO_OnOff"				;CheckBox 0 = Chorus Off, 1 = Chorus On
	endif

	;Modulator
	kFreq	=		cpsmidinn(gkMOD_Rate)

	gkTri		lfo		1, kFreq, 1							;Triangle

	if gkMOD_Wave == 0 then
		gkLFO	= gkTri
	elseif gkMOD_Wave == 1 then
		gkLFO	lfo	0.72, kFreq, 2						;Square bipolar 
	elseif gkMOD_Wave == 2 then
		gkLFO	randh	1, kFreq
	else
		gkLFO	random	-0.72, 0.72
	endif

	;Midi controllers
	gkMidiController1	ctrl7		1,1, 0, 1 					;Controller 1	Range 0 / +1	(using ctrl7 -> controller is active even if the midi instrument i2 is off)

	;Randomize generator
	gkRandomize	=	rnd(gkPanRnd)
endin

;SH-2k Modules Opcodes
opcode Source_Mixer_SH2k, a, kk
	;Source Mixer used in SH2k with Pulse / Saw / Tri / Noise mixed outputs 
	;Inputs:
	;	kPitch	Pitch
	;	kW		Control rate Pulse width

	;Output:
	;	amix		Mixed audio signal


	kPitch, kW    xin

	kFreq			= cpsmidinn(kPitch)
	kSubOscFreq	= cpsmidinn(gkSource_Fine - gkSource_Down * 12 + kPitch)

	arecw			vco2		gkSource_Pulse, kFreq, 2, kW						;RECTW
	asaw			vco2		gkSource_Saw, kFreq	 							;SAW

	if gkSource_Wave == 0 then
		asub		vco2		gkSource_SubOsc, kSubOscFreq, 10				;RECT
	elseif gkSource_Wave == 1 then
		asub		vco2		gkSource_SubOsc, kSubOscFreq, 12				;TRI
	else
		asub		vco2		gkSource_SubOsc, kSubOscFreq				;SAW
	endif

	amix		=	arecw + asaw + asub

	if gkSource_Noise > 0 then
		anoise	random		-gkSource_Noise, gkSource_Noise
		amix		=			amix + anoise
	endif

			xout		amix
endop

opcode VCF_SH2k, a, akkk
	;VCF used in SH2k with 1 x Filter 2P with LP BP HP in serie with 1xFilter 2PLP 
	;Inputs:
	;	aIn		Audio input	-1 / +1
	;	kPitch	Pitch
	;	kLFO		Modulation
	;	kEnv		Envelope

	;Output:
	;	alp2		Audio filtered signal

	;Global variable:
		;gkMidiPitchBend	Midi PitchBend -1 / +1


	ain, kPitch, kLFO, kEnv	xin

	kd1		=	2  - gkVCF_Res - gkVCF_Res
	kd2		=	0.4 + 0.8 * kd1

	kP		=	gkVCF_Freq + gkVCF_VCF * gkMidiPitchBend * 2 + kEnv * gkVCF_Env + kLFO * gkVCF_Mod + kPitch * gkVCF_Kybd

	kW		=	 cpsmidinn(kP) * 2 * $M_PI / sr

	if kW > 0.8 then
		kW = 0.8
	endif

	alp1, abp1, ahp1	Filter_2P	ain, kW, kd1

	if gkVCF_Mode == 0	then
		ain2	= ahp1
	elseif gkVCF_Mode == 1	then
		ain2 = abp1
	elseif gkVCF_Mode == 2	then
		ain2 = alp1
	endif

	alp2, abp2, ahp2	Filter_2P	ain2, kW, kd2

		xout		alp2
endop

instr	2	;MIDI triggered instr

	if (i(gkVel_Mode) == 0)	igoto VEL_OFF
						igoto VEL_ON
	VEL_OFF:
	ivel		=		1
	goto END_VEL
	VEL_ON:
	ivel		ampmidi	1													;read in midi note velocity as a value within the range 0 to 1
	ivel		= ivel * 1.2
	goto END_VEL
	END_VEL:

	inum			notnum													;read in midi note number as an integer (used for create a table of active notes flags)
				midipitchbend		gkMidiPitchBend								;Midi PitchBend	Range -1 / +1

	cggoto	(i(gkSynth_Mode) == 0), POLY
	MONO:
;	;Monophonic mode
	gknum		=	inum													;global pitch for mono mode
	gkvel			=	ivel													;global vel for mono mode
	gkNewNote	init	1													;flag used for envelope reinit

	iactive	active	2
	if (iactive == 1) then
		event_i	"i", 3, 0, 3600												;start Mono Synth
	endif
	;End Monophonic mode
	goto END_MODE

	POLY:
	;Polyphonic mode
	iprevnum		=	i(gkPrevNum)											;previous note for portamento
	gkPrevNum	=	inum

	aL, aR		subinstr	4, inum, ivel, iprevnum								;start Poly Synth
	;End Polyphonic mode
	goto END_MODE
	END_MODE:
endin

instr	3	;Mono Synth instr
	;Monophonic mode
	kGate	active	2

	if (kGate != 0)	kgoto CONTINUE
		turnoff

	CONTINUE:
	kGate	limit		kGate, 0, 1

	kPitch_in		=		gknum
	kVel			=		gkvel
	iPrevNum		=		i(gkPrevNum)										;Portamento, previous note, gkPrevNum is previous note, init at pitch = 60
	gkPrevNum	=		gknum											;Portamento, new note becomes previous note for the next step
	kPitch		portk	kPitch_in, gkPORT_Porta, iPrevNum						;Portamento

	if (gkNewNote == 1 && gkLegato_Mode == 0) then
		reinit		RESTART_ENVELOPE
	endif

	RESTART_ENVELOPE:
	kENV		ADSR	kGate, i(gkENV_A), i(gkENV_D), i(gkENV_S), i(gkENV_R), kVel
	kVCA		AR		kGate, i(gkVCA_A), i(gkVCA_R) + 6,  kVel
	rireturn

	gkNewNote	=	0													;Used for envelope reinit
	;End Monophonic mode

	;Release extra time
	if (i(gkVCA_Mode) == 0)	igoto ENV_ON
						igoto VCA_ON
	ENV_ON:
	ixtratim	= 6.90 * 0.001 * db(i(gkENV_R))			;6.90 is 3 * ln(10)
	goto END
	VCA_ON:
	ixtratim	= 6.90 * 0.001 * db(i(gkVCA_R))			;6.90 is 3 * ln(10)
	goto END
	END:
	xtratim	ixtratim

	;VCO
	kPitch_SMix	= kPitch + gkVCO_Mod * gkLFO + gkTri * gkVCO_LFOMW * gkMidiController1 + gkMidiPitchBend * gkVCO_VCO + 12 * (2 - gkVCO_Range)

	if gkVCO_PWM == 0 then
		kW	= gkVCO_PWidth * gkTri
	elseif gkVCO_PWM == 1 then
		kW	= gkVCO_PWidth
	else
		kW	= gkVCO_PWidth * kENV
	endif 

	kW	= (1 - kW) * 0.5														;kW scale change for vco opcode use

	;Osc Spread
	;aSynth0
	aSourceMixer0		Source_Mixer_SH2k	kPitch_SMix, kW
	aVCF0			VCF_SH2k		aSourceMixer0, kPitch, gkLFO, kENV
	;aSynth1
	aSourceMixer1		Source_Mixer_SH2k	kPitch_SMix + gkOscSprd, kW
	aVCF1			VCF_SH2k		aSourceMixer1, kPitch, gkLFO, kENV
	;aSynth2
	aSourceMixer2		Source_Mixer_SH2k	kPitch_SMix - gkOscSprd, kW
	aVCF2			VCF_SH2k		aSourceMixer2, kPitch, gkLFO, kENV

	if gkVCA_Mode == 0 then
		aSynth0	=	aVCF0 * kENV
		aSynth1	=	aVCF1 * kENV
		aSynth2	=	aVCF2 * kENV
	else
		aSynth0	=	aVCF0 * kVCA
		aSynth1	=	aVCF1 * kVCA
		aSynth2	=	aVCF2 * kVCA
	endif

	;Pan Spread
	kPan0			=		gkPan + i(gkRandomize)
	kPan1			=		kPan0 + gkPanSprd
	kPan2			=		kPan0 - gkPanSprd

	aLeft0, aRight0		pan2		aSynth0, kPan0
	aLeft1, aRight1		pan2		aSynth1, kPan1
	aLeft2, aRight2		pan2		aSynth2, kPan2

	aLeft				sum		aLeft0, aLeft1, aLeft2
	aRight			sum		aRight0, aRight1, aRight2

	gaSynth_L	=	gaSynth_L + aLeft
	gaSynth_R 	=	gaSynth_R + aRight
endin

instr	4	;Poly Synth instr
	;Polyphonic mode
	krel			release
	kGate		=		1 - krel
	kPitch_in		init		p4
	kVel			init		p5
	kprevnum		init		p6

	kPitch		portk	kPitch_in, gkPORT_Porta, i(kprevnum)						;Portamento, iprevnum is previous note, init at pitch = 60

	kENV		ADSR	kGate, i(gkENV_A), i(gkENV_D), i(gkENV_S), i(gkENV_R), kVel
	kVCA		AR		kGate, i(gkVCA_A), i(gkVCA_R) + 6,  kVel
	;End Polyphonic mode

	;Release extra time
	if (i(gkVCA_Mode) == 0)	igoto ENV_ON
						igoto VCA_ON
	ENV_ON:
	ixtratim	= 6.90 * 0.001 * db(i(gkENV_R))			;6.90 is 3 * ln(10)
	goto END
	VCA_ON:
	ixtratim	= 6.90 * 0.001 * db(i(gkVCA_R))			;6.90 is 3 * ln(10)
	goto END
	END:
	xtratim	ixtratim

	;VCO
	kPitch_SMix	= kPitch + gkVCO_Mod * gkLFO + gkTri * gkVCO_LFOMW * gkMidiController1 + gkMidiPitchBend * gkVCO_VCO + 12 * (2 - gkVCO_Range)

	if gkVCO_PWM == 0 then
		kW	= gkVCO_PWidth * gkTri
	elseif gkVCO_PWM == 1 then
		kW	= gkVCO_PWidth
	else
		kW	= gkVCO_PWidth * kENV
	endif 

	kW	= (1 - kW) * 0.5														;kW scale change for vco opcode use

	;Osc Spread
	;aSynth0
	aSourceMixer0		Source_Mixer_SH2k	kPitch_SMix, kW
	aVCF0			VCF_SH2k		aSourceMixer0, kPitch, gkLFO, kENV
	;aSynth1
	aSourceMixer1		Source_Mixer_SH2k	kPitch_SMix + gkOscSprd, kW
	aVCF1			VCF_SH2k		aSourceMixer1, kPitch, gkLFO, kENV
	;aSynth2
	aSourceMixer2		Source_Mixer_SH2k	kPitch_SMix - gkOscSprd, kW
	aVCF2			VCF_SH2k		aSourceMixer2, kPitch, gkLFO, kENV

	if gkVCA_Mode == 0 then
		aSynth0	=	aVCF0 * kENV
		aSynth1	=	aVCF1 * kENV
		aSynth2	=	aVCF2 * kENV
	else
		aSynth0	=	aVCF0 * kVCA
		aSynth1	=	aVCF1 * kVCA
		aSynth2	=	aVCF2 * kVCA
	endif

	;Pan Spread
	kPan0			=		gkPan + i(gkRandomize)
	kPan1			=		kPan0 + gkPanSprd
	kPan2			=		kPan0 - gkPanSprd

	aLeft0, aRight0		pan2		aSynth0, kPan0
	aLeft1, aRight1		pan2		aSynth1, kPan1
	aLeft2, aRight2		pan2		aSynth2, kPan2

	aLeft				sum		aLeft0, aLeft1, aLeft2
	aRight			sum		aRight0, aRight1, aRight2

	gaSynth_L	=	gaSynth_L + aLeft
	gaSynth_R 	=	gaSynth_R + aRight
endin

instr	5	;Dual Chorus
	if gkCHO_OnOff==0	kgoto CHORUS_OFF
					kgoto CHORUS_ON
	CHORUS_OFF:
	aCHORUS_L	=		gaSynth_L
	aCHORUS_R	=		gaSynth_R
				kgoto	END
	CHORUS_ON:
	imaxdel		=		200												;maximum delay 200 ms
	;Left channel
	aTri_L		lfo		gkCHO_Delay_L * gkCHO_Depth_L, gkCHO_Rate_L, 1			;Triangle
	aDelay_L		vdelay	gaSynth_L , aTri_L + gkCHO_Delay_L, imaxdel
	aCHORUS_L	=		aDelay_L + gaSynth_L
	;Right channel
	aTri_R		lfo		gkCHO_Delay_R * gkCHO_Depth_R, gkCHO_Rate_R, 1		;Triangle
	aDelay_R		vdelay	gaSynth_R , aTri_R + gkCHO_Delay_R, imaxdel
	aCHORUS_R	=		aDelay_R + gaSynth_R
	END:
	gaCHORUS_L	= 		gaCHORUS_L + aCHORUS_L
	gaCHORUS_R	=		gaCHORUS_R + aCHORUS_R
				clear		gaSynth_L
				clear		gaSynth_R
endin

instr	6	;Stereo Delay
	aSD_Filter_L	init	0
	aSD_Filter_R	init	0

	if gkSD_OnOff == 0	kgoto SD_OFF
					kgoto SD_ON
	SD_OFF:
	aDELAY_L	=		gaCHORUS_L
	aDELAY_R	=		gaCHORUS_R
				kgoto	END
	SD_ON:
	imaxdel		=		1000												;maximum delay 1000 ms
	;Left channel
	aSD_L		vdelay		gaCHORUS_L + gkSD_Cross * gaCHORUS_R + gkSD_FB * aSD_Filter_L, gkSD_Time_L + gkSD_Fine_L, imaxdel
	aSD_Filter_L	Filter_1PLP	aSD_L, gkSD_CutOff
	aDELAY_L	ntrpol		gaCHORUS_L , aSD_Filter_L, gkSD_Wet
	;Right channel	
	aSD_R		vdelay		gaCHORUS_R + gkSD_Cross * gaCHORUS_L + gkSD_FB * aSD_Filter_R, gkSD_Time_R + gkSD_Fine_R, imaxdel
	aSD_Filter_R	Filter_1PLP	aSD_R, gkSD_CutOff
	aDELAY_R	ntrpol		gaCHORUS_R, aSD_Filter_R, gkSD_Wet
	END:
				outs			aDELAY_L * gkVol, aDELAY_R * gkVol
				clear			gaCHORUS_L
				clear			gaCHORUS_R
endin
</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>
<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>482</x>
 <y>74</y>
 <width>941</width>
 <height>775</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="background">
  <r>187</r>
  <g>184</g>
  <b>181</b>
 </bgcolor>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>2</x>
  <y>42</y>
  <width>170</width>
  <height>220</height>
  <uuid>{5bd3427f-d49f-44f9-adad-b29aa038b448}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>MODULATOR</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="background">
   <r>120</r>
   <g>180</g>
   <b>180</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>12</borderradius>
  <borderwidth>4</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>23</x>
  <y>84</y>
  <width>60</width>
  <height>20</height>
  <uuid>{98b2a9b3-49b6-4565-990c-7922c296f6af}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>LFO Rate</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>90</x>
  <y>84</y>
  <width>60</width>
  <height>20</height>
  <uuid>{c765c135-c18a-4d1a-8ee3-a97ef06ee45e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Wave</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>2</x>
  <y>0</y>
  <width>930</width>
  <height>40</height>
  <uuid>{f62c79ff-8cd8-4de3-9457-d2ab3829628e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>? SH - 2000 ?</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>24</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="background">
   <r>120</r>
   <g>180</g>
   <b>180</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>12</borderradius>
  <borderwidth>4</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>MOD_Rate</objectName>
  <x>36</x>
  <y>226</y>
  <width>40</width>
  <height>20</height>
  <uuid>{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>-3.350</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>12</x>
  <y>52</y>
  <width>8</width>
  <height>8</height>
  <uuid>{668fc436-33a9-4ce9-8891-bd147db1e6f0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>154</x>
  <y>52</y>
  <width>8</width>
  <height>8</height>
  <uuid>{6dec78b0-498a-4df1-8eb5-18cb57f2f692}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>154</x>
  <y>244</y>
  <width>8</width>
  <height>8</height>
  <uuid>{2e6b90a7-5fd3-432c-a2a9-b03496bb260c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>12</x>
  <y>244</y>
  <width>8</width>
  <height>8</height>
  <uuid>{c16f7103-8b00-4720-91d4-5acb57fe17fe}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>MOD_Rate</objectName>
  <x>43</x>
  <y>104</y>
  <width>20</width>
  <height>120</height>
  <uuid>{642c07cb-0d5e-4bad-ac8a-31138524619a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>-90.00000000</minimum>
  <maximum>14.80000000</maximum>
  <value>-3.34999990</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>MOD_Wave</objectName>
  <x>83</x>
  <y>113</y>
  <width>80</width>
  <height>26</height>
  <uuid>{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>Triangle</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Square</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Random</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Noise</name>
    <value>3</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>0</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>175</x>
  <y>42</y>
  <width>254</width>
  <height>220</height>
  <uuid>{a371c70d-c652-48ef-a006-57046358b706}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>VCO</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="background">
   <r>120</r>
   <g>180</g>
   <b>180</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>12</borderradius>
  <borderwidth>4</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>196</x>
  <y>86</y>
  <width>60</width>
  <height>20</height>
  <uuid>{3e002768-5c45-4936-8308-bb4bb671936f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Mod</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>268</x>
  <y>86</y>
  <width>60</width>
  <height>20</height>
  <uuid>{bc46d908-6ecb-4cc0-a584-0a191c76d3aa}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Range</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCO_Mod</objectName>
  <x>209</x>
  <y>228</y>
  <width>40</width>
  <height>20</height>
  <uuid>{e1a7990f-523c-4a89-aad0-36e60fcfe344}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>185</x>
  <y>52</y>
  <width>8</width>
  <height>8</height>
  <uuid>{3c8ad312-f536-4b04-adb8-b7bce9fe5bf9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>410</x>
  <y>52</y>
  <width>8</width>
  <height>8</height>
  <uuid>{16f154e7-d2d8-450f-9ef4-152e25b49724}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>410</x>
  <y>244</y>
  <width>8</width>
  <height>8</height>
  <uuid>{bb94adf5-2b73-41d2-b517-ba6f2d233471}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>185</x>
  <y>244</y>
  <width>8</width>
  <height>8</height>
  <uuid>{0db74302-b957-4701-871d-9503818faf19}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>VCO_Mod</objectName>
  <x>216</x>
  <y>106</y>
  <width>20</width>
  <height>120</height>
  <uuid>{f87af5c6-cf47-42a2-abb8-b7444df4395b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>VCO_Range</objectName>
  <x>261</x>
  <y>113</y>
  <width>80</width>
  <height>26</height>
  <uuid>{e42cba75-2117-423d-ab14-f035f053381a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>2'</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>4'</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>8'</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>16'</name>
    <value>3</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>2</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>267</x>
  <y>152</y>
  <width>60</width>
  <height>20</height>
  <uuid>{437b7c25-f511-4038-b255-d767bf01931c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>PWM</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>VCO_PWM</objectName>
  <x>260</x>
  <y>179</y>
  <width>80</width>
  <height>26</height>
  <uuid>{37f146c2-57bf-4a51-890a-155f3fda4182}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>LFO</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Man</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Env</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>2</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>343</x>
  <y>85</y>
  <width>60</width>
  <height>20</height>
  <uuid>{9c69f8c6-2ff9-476d-b9b4-1de81274ed7f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>P Width</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCO_PWidth</objectName>
  <x>356</x>
  <y>227</y>
  <width>40</width>
  <height>20</height>
  <uuid>{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>VCO_PWidth</objectName>
  <x>363</x>
  <y>105</y>
  <width>20</width>
  <height>120</height>
  <uuid>{13364f3b-fcd8-4e06-bbde-da703d48b25f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>0.82000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>432</x>
  <y>42</y>
  <width>500</width>
  <height>220</height>
  <uuid>{cf438b55-65e9-4607-9ec8-99f92306e151}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>SOURCE MIXER</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="background">
   <r>120</r>
   <g>180</g>
   <b>180</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>12</borderradius>
  <borderwidth>4</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>453</x>
  <y>85</y>
  <width>60</width>
  <height>20</height>
  <uuid>{24a68a2f-3959-4dc0-ba0b-0c0b6ffe0e48}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Pulse</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>665</x>
  <y>85</y>
  <width>60</width>
  <height>20</height>
  <uuid>{ad51b3fc-015a-4a98-8a75-c54a3a9eed2e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Down</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Source_Pulse</objectName>
  <x>466</x>
  <y>227</y>
  <width>40</width>
  <height>20</height>
  <uuid>{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>442</x>
  <y>52</y>
  <width>8</width>
  <height>8</height>
  <uuid>{a42dec28-65a6-446a-bf9e-e5991256823c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>915</x>
  <y>52</y>
  <width>8</width>
  <height>8</height>
  <uuid>{fb2750e2-4356-4e06-84cb-d29794c09665}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>915</x>
  <y>244</y>
  <width>8</width>
  <height>8</height>
  <uuid>{b7d41a62-5f62-4736-9d62-f0a90f2b0f78}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>442</x>
  <y>244</y>
  <width>8</width>
  <height>8</height>
  <uuid>{49cd38c2-7b1c-443c-87ad-17cad090e7e4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>Source_Pulse</objectName>
  <x>473</x>
  <y>106</y>
  <width>20</width>
  <height>120</height>
  <uuid>{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>0.25000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>Source_Down</objectName>
  <x>658</x>
  <y>113</y>
  <width>80</width>
  <height>26</height>
  <uuid>{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>0 oct</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>1 oct</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>2 oct</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>1</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>750</x>
  <y>85</y>
  <width>60</width>
  <height>20</height>
  <uuid>{bff86747-75e9-407c-9c1d-a072a5e6e643}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Wave</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>Source_Wave</objectName>
  <x>743</x>
  <y>113</y>
  <width>80</width>
  <height>26</height>
  <uuid>{5cac16cb-1799-4b8c-8b28-a7b088819aa0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>Pulse</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Triangle</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Saw</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>0</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>590</x>
  <y>85</y>
  <width>60</width>
  <height>20</height>
  <uuid>{85b896c0-e087-4d31-9db0-7e90aaefe6fa}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>SubOsc</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Source_SubOsc</objectName>
  <x>603</x>
  <y>227</y>
  <width>40</width>
  <height>20</height>
  <uuid>{28c00fc0-b60e-4c59-bde1-80c4d079354a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.163</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>Source_SubOsc</objectName>
  <x>610</x>
  <y>106</y>
  <width>20</width>
  <height>120</height>
  <uuid>{58173576-1563-4420-b4c6-495214fe9a70}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>0.25000000</maximum>
  <value>0.16300000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>508</x>
  <y>85</y>
  <width>60</width>
  <height>20</height>
  <uuid>{c37319d3-e8ea-40f9-a7cb-cd69f2a1c883}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Saw</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Source_Saw</objectName>
  <x>521</x>
  <y>227</y>
  <width>40</width>
  <height>20</height>
  <uuid>{78176f70-03cb-4894-9605-cd4ed3b612dd}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.250</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>Source_Saw</objectName>
  <x>528</x>
  <y>106</y>
  <width>20</width>
  <height>120</height>
  <uuid>{5ae23e36-804c-417f-94a6-d7a98671d3c8}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>0.25000000</maximum>
  <value>0.25000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>Source_Fine</objectName>
  <x>710</x>
  <y>165</y>
  <width>60</width>
  <height>60</height>
  <uuid>{327ac730-039a-4c6c-9440-a32b3f56d549}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>-1.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>710</x>
  <y>144</y>
  <width>60</width>
  <height>20</height>
  <uuid>{7316f124-8ad0-431e-b4a4-01289e36755f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Fine</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Source_Fine</objectName>
  <x>710</x>
  <y>227</y>
  <width>60</width>
  <height>20</height>
  <uuid>{ffca81dd-fe2e-401f-ad74-621e70836e13}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>831</x>
  <y>85</y>
  <width>60</width>
  <height>20</height>
  <uuid>{ae7ed2ee-0da1-42f6-a6e7-9829fa23c90b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Noise</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Source_Noise</objectName>
  <x>844</x>
  <y>227</y>
  <width>40</width>
  <height>20</height>
  <uuid>{63e57e7c-01ef-47a1-b819-d6b6964cf682}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>Source_Noise</objectName>
  <x>851</x>
  <y>106</y>
  <width>20</width>
  <height>120</height>
  <uuid>{01c46d69-b2db-4cb2-a2f2-89baa522de26}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>0.25000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>2</x>
  <y>265</y>
  <width>427</width>
  <height>220</height>
  <uuid>{2d1c61a9-2be1-4e56-8c63-8fe8060b72f1}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>VCF</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="background">
   <r>120</r>
   <g>180</g>
   <b>180</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>12</borderradius>
  <borderwidth>4</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>23</x>
  <y>308</y>
  <width>60</width>
  <height>20</height>
  <uuid>{7ab9a680-1a9b-4170-bb36-df284b987f19}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Freq</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>355</x>
  <y>308</y>
  <width>60</width>
  <height>20</height>
  <uuid>{d2131702-5142-4e73-810d-39a7670d3f98}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Mode</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCF_Freq</objectName>
  <x>33</x>
  <y>450</y>
  <width>43</width>
  <height>20</height>
  <uuid>{887dc1a5-37db-4f2b-ade2-71bba0dd737f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>83.010</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>12</x>
  <y>275</y>
  <width>8</width>
  <height>8</height>
  <uuid>{f2d22557-dd67-41fe-b29d-4b7e202f3a11}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>410</x>
  <y>275</y>
  <width>8</width>
  <height>8</height>
  <uuid>{a5c4e94b-6e2d-4103-a82a-48af62c81d9b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>410</x>
  <y>467</y>
  <width>8</width>
  <height>8</height>
  <uuid>{76727f2c-a583-4e61-8f96-6ead02cecab3}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>12</x>
  <y>467</y>
  <width>8</width>
  <height>8</height>
  <uuid>{e46bef8c-e772-4c6f-9788-95c4b5db8a3e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>VCF_Freq</objectName>
  <x>43</x>
  <y>329</y>
  <width>20</width>
  <height>120</height>
  <uuid>{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>-14.00000000</minimum>
  <maximum>126.00000000</maximum>
  <value>83.01000214</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>VCF_Mode</objectName>
  <x>356</x>
  <y>336</y>
  <width>60</width>
  <height>26</height>
  <uuid>{f614b7a4-63dc-4281-8451-6136788f1d8d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>HPF</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>BPF</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>LPF</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>2</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>133</x>
  <y>308</y>
  <width>60</width>
  <height>20</height>
  <uuid>{d3385111-630a-42dd-999b-0a28979ce127}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Env</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCF_Env</objectName>
  <x>144</x>
  <y>450</y>
  <width>44</width>
  <height>20</height>
  <uuid>{69029598-c644-400a-9ca9-1cc9cf5f6c9f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>67.870</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>VCF_Env</objectName>
  <x>153</x>
  <y>329</y>
  <width>20</width>
  <height>120</height>
  <uuid>{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>15.00000000</minimum>
  <maximum>100.00000000</maximum>
  <value>67.87000275</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>78</x>
  <y>308</y>
  <width>60</width>
  <height>20</height>
  <uuid>{f73caab8-cfaf-4845-84e8-70756da1d75e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Res</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCF_Res</objectName>
  <x>91</x>
  <y>450</y>
  <width>40</width>
  <height>20</height>
  <uuid>{91e17b9a-93b0-4115-b716-eaaa978b7c10}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.380</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>VCF_Res</objectName>
  <x>98</x>
  <y>329</y>
  <width>20</width>
  <height>120</height>
  <uuid>{a0791461-05f9-4dd7-a0de-fbc855336f90}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>0.98500000</maximum>
  <value>0.38000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>188</x>
  <y>308</y>
  <width>60</width>
  <height>20</height>
  <uuid>{6578f309-ddcc-4bae-af30-130c53bf5045}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Mod</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCF_Mod</objectName>
  <x>201</x>
  <y>450</y>
  <width>40</width>
  <height>20</height>
  <uuid>{a992f830-37d6-41e0-887b-cf359db819df}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>VCF_Mod</objectName>
  <x>208</x>
  <y>329</y>
  <width>20</width>
  <height>120</height>
  <uuid>{5d016743-85d7-456a-8598-1e97091098d7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>65.00000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>298</x>
  <y>308</y>
  <width>60</width>
  <height>20</height>
  <uuid>{102a5dc4-95ef-4eea-95e0-186245af88ea}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>VCF</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCF_VCF</objectName>
  <x>311</x>
  <y>450</y>
  <width>40</width>
  <height>20</height>
  <uuid>{ec950d13-7f08-4c56-b68a-4099d0fe230e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>VCF_VCF</objectName>
  <x>318</x>
  <y>329</y>
  <width>20</width>
  <height>120</height>
  <uuid>{c23be871-3ab5-49a2-ab73-6c85043ebe8c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>24.00000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>243</x>
  <y>308</y>
  <width>60</width>
  <height>20</height>
  <uuid>{7fc5dcfd-8d93-40a9-a7ae-61fe704ada64}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Kybd</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCF_Kybd</objectName>
  <x>256</x>
  <y>450</y>
  <width>40</width>
  <height>20</height>
  <uuid>{6450f06d-d458-466a-8d5c-6298c4a8bbee}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.457</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>VCF_Kybd</objectName>
  <x>263</x>
  <y>329</y>
  <width>20</width>
  <height>120</height>
  <uuid>{1c1ff342-d5bf-490f-a6bf-51221980dc4f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.45699999</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>432</x>
  <y>265</y>
  <width>200</width>
  <height>220</height>
  <uuid>{f9fdb11b-2cce-4d0f-ba56-e5de1939b969}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>VCA</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="background">
   <r>120</r>
   <g>180</g>
   <b>180</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>12</borderradius>
  <borderwidth>4</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>513</x>
  <y>307</y>
  <width>60</width>
  <height>22</height>
  <uuid>{efa24b24-58ff-43b6-8b8b-fcc825397e01}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Attack</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>440</x>
  <y>307</y>
  <width>60</width>
  <height>22</height>
  <uuid>{82676598-bf29-4501-a5ed-286cc06c23c0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Mode</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCA_A</objectName>
  <x>526</x>
  <y>449</y>
  <width>40</width>
  <height>20</height>
  <uuid>{c82821cd-6155-4e35-8d35-bc5c2f77bf57}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>442</x>
  <y>275</y>
  <width>8</width>
  <height>8</height>
  <uuid>{960c2d07-ab7c-4b33-9568-50a1b83b2d2e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>614</x>
  <y>275</y>
  <width>8</width>
  <height>8</height>
  <uuid>{85f3943d-8d78-4388-8eb6-cdfcabcd1348}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>614</x>
  <y>467</y>
  <width>8</width>
  <height>8</height>
  <uuid>{9ffff2a4-ffda-4360-bfcd-fe3a48bceecd}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>442</x>
  <y>467</y>
  <width>8</width>
  <height>8</height>
  <uuid>{eac9e49c-3b52-4111-ae5a-e50d15560b15}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>VCA_A</objectName>
  <x>533</x>
  <y>327</y>
  <width>20</width>
  <height>120</height>
  <uuid>{b8ed00a9-e807-4c3e-9421-a9c935064aa2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>60.00000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>VCA_Mode</objectName>
  <x>445</x>
  <y>336</y>
  <width>60</width>
  <height>26</height>
  <uuid>{50b353e7-299e-41a1-8b16-30a019c4ddb5}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>Env</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Gate</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>1</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>568</x>
  <y>307</y>
  <width>60</width>
  <height>22</height>
  <uuid>{13244ad5-f957-45d3-94a7-28786a0b0a5c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Release</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCA_R</objectName>
  <x>581</x>
  <y>449</y>
  <width>40</width>
  <height>20</height>
  <uuid>{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>22.047</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>VCA_R</objectName>
  <x>588</x>
  <y>327</y>
  <width>20</width>
  <height>120</height>
  <uuid>{2cc0f99c-2217-4cee-96a8-90f8237a826d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>70.00000000</maximum>
  <value>22.04700089</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>636</x>
  <y>265</y>
  <width>296</width>
  <height>220</height>
  <uuid>{e1106eec-2b7a-45ae-9338-b20a304a79b2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>ENV</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="background">
   <r>120</r>
   <g>180</g>
   <b>180</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>12</borderradius>
  <borderwidth>4</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>675</x>
  <y>306</y>
  <width>60</width>
  <height>22</height>
  <uuid>{6c13bc7f-2fad-4057-ae31-5f0d11944418}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>A</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>ENV_A</objectName>
  <x>688</x>
  <y>448</y>
  <width>40</width>
  <height>20</height>
  <uuid>{7eb0d54d-541c-4759-baf0-17a96b733fd9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>1.701</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>645</x>
  <y>275</y>
  <width>8</width>
  <height>8</height>
  <uuid>{b8b0a60d-bf97-4436-89ef-32f139a4189a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>915</x>
  <y>275</y>
  <width>8</width>
  <height>8</height>
  <uuid>{3052d837-6907-450b-9383-373a9f9a719a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>915</x>
  <y>467</y>
  <width>8</width>
  <height>8</height>
  <uuid>{0ce6e2c0-1908-44f8-81dd-68a834f93019}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>645</x>
  <y>467</y>
  <width>8</width>
  <height>8</height>
  <uuid>{4a879092-f17d-4d32-9f94-f6eb4d7dabc3}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>ENV_A</objectName>
  <x>695</x>
  <y>326</y>
  <width>20</width>
  <height>120</height>
  <uuid>{8ffee666-07f7-41b6-b755-84e18dc00575}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>72.00000000</maximum>
  <value>1.70099998</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>730</x>
  <y>306</y>
  <width>60</width>
  <height>22</height>
  <uuid>{0440cf53-f87a-4179-adbb-adef3711cba2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>D</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>ENV_D</objectName>
  <x>743</x>
  <y>448</y>
  <width>40</width>
  <height>20</height>
  <uuid>{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>48.079</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>ENV_D</objectName>
  <x>750</x>
  <y>326</y>
  <width>20</width>
  <height>120</height>
  <uuid>{2edc58e5-7957-45bd-8cdd-858f2b90eaef}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>86.00000000</maximum>
  <value>48.07899857</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>785</x>
  <y>306</y>
  <width>60</width>
  <height>22</height>
  <uuid>{932848eb-e63f-4818-ba5b-db9df1fd6346}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>S</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>ENV_S</objectName>
  <x>798</x>
  <y>448</y>
  <width>40</width>
  <height>20</height>
  <uuid>{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.039</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>ENV_S</objectName>
  <x>805</x>
  <y>326</y>
  <width>20</width>
  <height>120</height>
  <uuid>{366152fc-e59d-4959-8970-0d1616267441}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.03900000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>842</x>
  <y>306</y>
  <width>55</width>
  <height>22</height>
  <uuid>{21dcbace-1e82-4340-9c12-3aad1c2798e5}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>R</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>ENV_R</objectName>
  <x>853</x>
  <y>448</y>
  <width>40</width>
  <height>20</height>
  <uuid>{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>41.984</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBVSlider" version="2">
  <objectName>ENV_R</objectName>
  <x>860</x>
  <y>326</y>
  <width>20</width>
  <height>120</height>
  <uuid>{d460dad0-c11e-46a1-a365-a0e14b7dbe89}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>86.00000000</maximum>
  <value>41.98400116</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>2</x>
  <y>487</y>
  <width>930</width>
  <height>120</height>
  <uuid>{d041ada0-fd97-441d-9c78-656add5f1d2b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="background">
   <r>120</r>
   <g>180</g>
   <b>180</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>12</borderradius>
  <borderwidth>4</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>VCO_VCO</objectName>
  <x>30</x>
  <y>516</y>
  <width>60</width>
  <height>60</height>
  <uuid>{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>12.00000000</maximum>
  <value>2.20000005</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>30</x>
  <y>495</y>
  <width>60</width>
  <height>20</height>
  <uuid>{617e7a0f-8682-4a36-8e68-44780d3a5170}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>VCO</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCO_VCO</objectName>
  <x>30</x>
  <y>578</y>
  <width>60</width>
  <height>20</height>
  <uuid>{7e3480ec-73da-458d-87ff-d9d7afc83301}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>2.200</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>12</x>
  <y>496</y>
  <width>8</width>
  <height>8</height>
  <uuid>{709ee709-b3aa-482c-b078-909104ece586}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>12</x>
  <y>588</y>
  <width>8</width>
  <height>8</height>
  <uuid>{e190e741-3dfa-410e-b496-898429c44f8a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>915</x>
  <y>496</y>
  <width>8</width>
  <height>8</height>
  <uuid>{52fa890e-1761-45e8-afe0-d8291ba426c4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>915</x>
  <y>588</y>
  <width>8</width>
  <height>8</height>
  <uuid>{6e08e164-2d99-4122-a3a7-8fc0be2b205f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBCheckBox" version="2">
  <objectName>Legato_Mode</objectName>
  <x>504</x>
  <y>534</y>
  <width>20</width>
  <height>20</height>
  <uuid>{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <selected>false</selected>
  <label/>
  <pressedValue>1</pressedValue>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>437</x>
  <y>534</y>
  <width>60</width>
  <height>22</height>
  <uuid>{79563427-240b-4563-86fe-dd3175e9c58e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Legato</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>PORT_Porta</objectName>
  <x>216</x>
  <y>516</y>
  <width>60</width>
  <height>60</height>
  <uuid>{8c454038-062a-4b0e-ae48-725119cb36cb}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>206</x>
  <y>495</y>
  <width>90</width>
  <height>20</height>
  <uuid>{d70d65be-cce1-4aec-bdca-e0e70331a9ca}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>PORTAMENTO</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>PORT_Porta</objectName>
  <x>216</x>
  <y>578</y>
  <width>60</width>
  <height>20</height>
  <uuid>{1b7c6549-2d92-42fa-8cda-1c232d95986e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>VCO_LFOMW</objectName>
  <x>100</x>
  <y>516</y>
  <width>60</width>
  <height>60</height>
  <uuid>{51de6163-fc0d-415c-99be-ad03ff79e313}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>9.00000000</maximum>
  <value>1.14999998</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>100</x>
  <y>495</y>
  <width>60</width>
  <height>20</height>
  <uuid>{57e390fb-c881-499c-8d16-b09385d630d6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>LFO MW</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>VCO_LFOMW</objectName>
  <x>100</x>
  <y>578</y>
  <width>60</width>
  <height>20</height>
  <uuid>{43b53135-0f7c-4a57-871d-c18990e06c2e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>1.150</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>PanRnd</objectName>
  <x>772</x>
  <y>516</y>
  <width>60</width>
  <height>60</height>
  <uuid>{937adfd8-d994-4175-a2cc-bc6050d490e0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.37000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>772</x>
  <y>495</y>
  <width>60</width>
  <height>20</height>
  <uuid>{b55f6efb-3deb-4ba4-851c-2b8641daf684}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Pan Rnd</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>PanRnd</objectName>
  <x>772</x>
  <y>578</y>
  <width>60</width>
  <height>20</height>
  <uuid>{de43a194-7aae-45f9-8b30-65a28db74fc9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.370</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>Pan</objectName>
  <x>702</x>
  <y>516</y>
  <width>60</width>
  <height>60</height>
  <uuid>{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>-1.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>-0.12000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>702</x>
  <y>495</y>
  <width>60</width>
  <height>20</height>
  <uuid>{48c5f8e8-53bd-410c-bfda-179f4c4ed0aa}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Pan</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Pan</objectName>
  <x>702</x>
  <y>578</y>
  <width>60</width>
  <height>20</height>
  <uuid>{9a2e6492-358c-46fe-8de7-341f4c704d1e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>-0.120</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>PanSprd</objectName>
  <x>632</x>
  <y>516</y>
  <width>60</width>
  <height>60</height>
  <uuid>{60e94c14-63ab-44d8-9ecf-59039180c728}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.22000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>632</x>
  <y>495</y>
  <width>60</width>
  <height>20</height>
  <uuid>{716d07b4-c4da-43a0-963e-279b7dc87058}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Pan Sprd</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>PanSprd</objectName>
  <x>632</x>
  <y>578</y>
  <width>60</width>
  <height>20</height>
  <uuid>{b17a30cc-4655-4f19-986d-3e33ad924c24}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.220</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>OscSprd</objectName>
  <x>562</x>
  <y>516</y>
  <width>60</width>
  <height>60</height>
  <uuid>{06211856-2752-4132-a954-7bd84c285c36}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.05000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>562</x>
  <y>495</y>
  <width>60</width>
  <height>20</height>
  <uuid>{02cff6bd-2d22-405d-bd2a-99daa6830587}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Osc Sprd</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>OscSprd</objectName>
  <x>562</x>
  <y>578</y>
  <width>60</width>
  <height>20</height>
  <uuid>{db42035e-f7b0-4137-b27f-0464cda89e85}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.050</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>437</x>
  <y>512</y>
  <width>60</width>
  <height>22</height>
  <uuid>{3563d866-6d68-45ec-a349-f34fd70bd689}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Velocity</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBCheckBox" version="2">
  <objectName>Vel_Mode</objectName>
  <x>504</x>
  <y>513</y>
  <width>20</width>
  <height>20</height>
  <uuid>{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <selected>true</selected>
  <label/>
  <pressedValue>1</pressedValue>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>362</x>
  <y>501</y>
  <width>60</width>
  <height>22</height>
  <uuid>{3b5aabd5-e859-49cf-8128-ef1d0c3b70f6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Synth Mode</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>Synth_Mode</objectName>
  <x>362</x>
  <y>521</y>
  <width>66</width>
  <height>26</height>
  <uuid>{bca40b7b-2c3b-4884-a877-85391e08bd36}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>Poly</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Mono</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>0</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>842</x>
  <y>495</y>
  <width>60</width>
  <height>20</height>
  <uuid>{9d873a75-1845-47ad-a5f2-4d48c07a3dc3}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Volume</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>362</x>
  <y>548</y>
  <width>60</width>
  <height>20</height>
  <uuid>{ed44fcfa-b7c9-48ed-a47e-819c11b85f01}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Program</label>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>_SetPresetIndex</objectName>
  <x>363</x>
  <y>567</y>
  <width>160</width>
  <height>26</height>
  <uuid>{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>001  Old Guy</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>002  Prophy</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>003  PWM Power</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>004  Superstack</name>
    <value>3</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>005  Spacy Sweep</name>
    <value>4</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>006  Sharp PWM</name>
    <value>5</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>007  Funky Syn</name>
    <value>6</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>008  Paris</name>
    <value>7</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>009  Zufall</name>
    <value>8</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>010  Solina</name>
    <value>9</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>011  Noiz Baz</name>
    <value>10</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>012  Puls Uni</name>
    <value>11</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>013  Euro</name>
    <value>12</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>014  Poly 8</name>
    <value>13</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>015  Mega Bass</name>
    <value>14</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>016  BPF Pad</name>
    <value>15</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>017  Reso Fly</name>
    <value>16</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>018  Fat Hook</name>
    <value>17</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>019  Space SQ</name>
    <value>18</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>020  Fat SQ</name>
    <value>19</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>021  BEF SQ LFO</name>
    <value>20</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>022  SQ Random</name>
    <value>21</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>023  HPF SQ LFO</name>
    <value>22</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>024  Chord SQ LFO</name>
    <value>23</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>025  Straight SQ LFO</name>
    <value>24</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>026  Detune SQ LFO</name>
    <value>25</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>027  Trance Chords 1</name>
    <value>26</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>028  Trance Chords 2</name>
    <value>27</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>029  Short Chords</name>
    <value>28</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>030  Velo Power</name>
    <value>29</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>031  Oktavstrings</name>
    <value>30</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>032  Glider</name>
    <value>31</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>033  Soft Lead</name>
    <value>32</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>034  Vintage Lead</name>
    <value>33</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>035  Software</name>
    <value>34</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>036  SH Gruv</name>
    <value>35</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>037  Square Dance</name>
    <value>36</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>038  Glub</name>
    <value>37</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>039  Hum</name>
    <value>38</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>040  Dooh</name>
    <value>39</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>041  Funny</name>
    <value>40</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>042  Random LFO</name>
    <value>41</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>043  Propaganda</name>
    <value>42</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>044  Tekkno Basic</name>
    <value>43</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>045  Tekkno Fat</name>
    <value>44</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>046  Tekkno Rezzo</name>
    <value>45</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>047  Poly Uni</name>
    <value>46</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>048  Jumper</name>
    <value>47</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>049  Polyswell</name>
    <value>48</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>050  Init Saw</name>
    <value>49</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>051  Long Fuzz</name>
    <value>50</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>052  Q Kick C1</name>
    <value>51</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>053  Fuzz SQ</name>
    <value>52</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>054  Dist Pulz</name>
    <value>53</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>055  Bad Boy</name>
    <value>54</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>056  HardCoreBass</name>
    <value>55</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>3</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>Volume</objectName>
  <x>842</x>
  <y>516</y>
  <width>60</width>
  <height>60</height>
  <uuid>{6be2e903-0bbe-41fe-8343-089fbcd2de1b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.50000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Volume</objectName>
  <x>842</x>
  <y>578</y>
  <width>60</width>
  <height>20</height>
  <uuid>{8a6fd0c3-466c-40e1-a311-a82342291cb7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.500</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>2</x>
  <y>609</y>
  <width>532</width>
  <height>130</height>
  <uuid>{f7451a86-5a89-4eca-a365-9e4d90aa6195}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>STEREO DELAY</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="background">
   <r>120</r>
   <g>180</g>
   <b>180</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>12</borderradius>
  <borderwidth>4</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>SD_Time_L</objectName>
  <x>32</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{2963de7a-be1d-447f-ab5b-793a53a9666d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>600.00000000</maximum>
  <value>300.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>27</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{7d76c7b9-77cf-4094-94f0-89b441ac286c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Time L</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>SD_Time_L</objectName>
  <x>27</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>300.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>12</x>
  <y>618</y>
  <width>8</width>
  <height>8</height>
  <uuid>{4cb3ff74-4f32-4596-a6ea-17c75729d179}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>12</x>
  <y>720</y>
  <width>8</width>
  <height>8</height>
  <uuid>{bfcf72d9-63b4-470f-8c2e-ae68d6da46a0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>SD_Time_R</objectName>
  <x>152</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{b964b8c0-be99-4725-a6d8-ef9d308f5135}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>600.00000000</maximum>
  <value>600.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>SD_Time_R</objectName>
  <x>147</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{fe5054e9-8a26-4ba7-9700-2fa71d40632d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>600.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>SD_Fine_L</objectName>
  <x>92</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>5.00000000</maximum>
  <value>1.50000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>87</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{a28c2c69-7e25-45dc-9813-9c87b6f5ec8f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Fine L</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>SD_Fine_L</objectName>
  <x>87</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{08584473-aa83-4cb0-bd90-ae916c48b731}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>1.500</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>FB_Cross</objectName>
  <x>392</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{674ef926-f096-4cbf-9463-b93cdc3c4b71}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.23000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>387</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{778bc737-69c0-48ff-91a0-f38ebdecf02f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Cross</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>FB_Cross</objectName>
  <x>387</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{6617596a-de0f-43e6-b8bc-431a46eee472}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.230</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>SD_FB</objectName>
  <x>332</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{b6b3e205-041e-4619-a0b9-9207988f6eb7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.23999999</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>327</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{004a80a5-26b2-45b7-9468-73e7fe11a6c7}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>FB</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>SD_FB</objectName>
  <x>327</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{d90d390f-534f-401b-8af7-d835ab7f0777}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.240</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>SD_CutOff</objectName>
  <x>272</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{cd67c41d-1e02-45ee-8ce0-a981721a1323}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.40000001</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>267</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{3e5eda00-ad46-4d5c-a31d-59bd90517125}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>CutOff</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>SD_CutOff</objectName>
  <x>267</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.400</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>SD_Fine_R</objectName>
  <x>212</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>5.00000000</maximum>
  <value>3.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>207</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{ef880393-684a-4936-9809-9704bef221e0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Fine R</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>SD_Fine_R</objectName>
  <x>207</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>3.000</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>447</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{5c0e74af-7b14-4fca-ae90-449a81639c94}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Wet</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>SD_Wet</objectName>
  <x>452</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.19000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>SD_Wet</objectName>
  <x>447</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{f91a921a-4a02-4ac6-abbd-83b016c6cb96}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.190</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>147</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{f41732d6-0137-4622-a80d-c6b982d731d5}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Time R</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>306</x>
  <y>501</y>
  <width>60</width>
  <height>22</height>
  <uuid>{a5176b55-634c-48ec-b283-deda5a92ee6d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Voices</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBScrollNumber" version="2">
  <objectName>Voices</objectName>
  <x>322</x>
  <y>523</y>
  <width>30</width>
  <height>20</height>
  <uuid>{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>16</fontsize>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <value>0.00000000</value>
  <resolution>1.00000000</resolution>
  <minimum>0.00000000</minimum>
  <maximum>100.00000000</maximum>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
  <randomizable group="0">false</randomizable>
  <mouseControl act=""/>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>537</x>
  <y>609</y>
  <width>395</width>
  <height>130</height>
  <uuid>{28635a18-07b6-4b4c-ac0b-117dd2609a50}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>STEREO CHORUS</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="background">
   <r>120</r>
   <g>180</g>
   <b>180</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>12</borderradius>
  <borderwidth>4</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>547</x>
  <y>618</y>
  <width>8</width>
  <height>8</height>
  <uuid>{2b918f52-072d-466d-9d5b-13d161c194c3}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>547</x>
  <y>720</y>
  <width>8</width>
  <height>8</height>
  <uuid>{cc64cf27-f822-47ac-bea5-7379699c1e1b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>516</x>
  <y>618</y>
  <width>8</width>
  <height>8</height>
  <uuid>{c1e9a1bb-42c9-4916-96e9-d8811fd3f118}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>516</x>
  <y>720</y>
  <width>8</width>
  <height>8</height>
  <uuid>{0a2a254f-c4a5-4499-b1b2-53c6ede2767e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>915</x>
  <y>618</y>
  <width>8</width>
  <height>8</height>
  <uuid>{44cb3e7a-62f7-4f64-9f33-c567f24ce7c6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>915</x>
  <y>720</y>
  <width>8</width>
  <height>8</height>
  <uuid>{d72babe3-262a-4670-8bce-190639af6664}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>left</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>170</r>
   <g>170</g>
   <b>170</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>4</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBCheckBox" version="2">
  <objectName>SD_OnOff</objectName>
  <x>358</x>
  <y>615</y>
  <width>20</width>
  <height>20</height>
  <uuid>{3f82051f-eb2b-4568-83a6-df731707f43a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <selected>true</selected>
  <label/>
  <pressedValue>1</pressedValue>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>318</x>
  <y>614</y>
  <width>40</width>
  <height>20</height>
  <uuid>{20680bf9-9b65-4991-ada1-b981dc511385}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>On</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBCheckBox" version="2">
  <objectName>CHO_OnOff</objectName>
  <x>841</x>
  <y>615</y>
  <width>20</width>
  <height>20</height>
  <uuid>{2a3d8d6f-18b8-4543-81ae-690b9da1da00}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <selected>true</selected>
  <label/>
  <pressedValue>1</pressedValue>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>801</x>
  <y>614</y>
  <width>40</width>
  <height>20</height>
  <uuid>{3f4e8218-14ef-4c6e-aca1-e0b2a178cf7d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>On</label>
  <alignment>right</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>CHO_Delay_L</objectName>
  <x>560</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{59cb56ba-1834-4f28-aece-d4ced86ab11f}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.50000000</minimum>
  <maximum>20.00000000</maximum>
  <value>4.95499992</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>CHO_Delay_L</objectName>
  <x>555</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>4.955</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>CHO_Depth_R</objectName>
  <x>800</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{16036f95-bd0d-44e9-ad75-abece8ffcba8}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>0.99000000</maximum>
  <value>0.69300002</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>795</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{0cb400a5-4675-4588-8bea-8db01e8e54c8}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Depth R</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>CHO_Depth_R</objectName>
  <x>795</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{154105e8-96a6-4576-ad7d-2bec68a97595}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.693</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>CHO_Delay_R</objectName>
  <x>740</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{065b020d-a389-4ef6-87de-b827cb36efc9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.50000000</minimum>
  <maximum>20.00000000</maximum>
  <value>5.57000017</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>735</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{9eceb369-f28f-4181-9f41-a04af9d4c0fb}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Delay R</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>CHO_Delay_R</objectName>
  <x>735</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{391eafa1-19b3-425c-ae97-9f40a5f76434}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>5.570</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>CHO_Rate_L</objectName>
  <x>680</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.43000001</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>675</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{d6fbb729-bf86-490d-8246-581a0cd3f942}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Rate L</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>CHO_Rate_L</objectName>
  <x>675</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{77450294-bb31-4d0c-b16b-95ee95790cb9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.430</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>CHO_Depth_L</objectName>
  <x>620</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{f9da2d45-4167-4a28-9247-5e7f19c19564}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>0.99000000</maximum>
  <value>0.53460002</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>615</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{88e5e343-6405-4350-948e-5be8750887a6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Depth L</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>CHO_Depth_L</objectName>
  <x>615</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.535</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>170</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>3</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>855</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{c451a6c8-49f2-4589-87bf-0bf567324681}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Rate R</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>CHO_Rate_R</objectName>
  <x>860</x>
  <y>660</y>
  <width>50</width>
  <height>50</height>
  <uuid>{314b2676-2771-4847-8fd9-0576014b2b22}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.43000001</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>CHO_Rate_R</objectName>
  <x>855</x>
  <y>710</y>
  <width>60</width>
  <height>20</height>
  <uuid>{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.430</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>555</x>
  <y>640</y>
  <width>60</width>
  <height>20</height>
  <uuid>{6be1ea54-3f59-43f1-abb8-03925183e668}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Delay L</label>
  <alignment>center</alignment>
  <font>Arial</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>127</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
</bsbPanel>
<bsbPresets>
<preset name="Old Guy" number="0" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-9.96000004</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-9.960</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-9.96000004</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.14600000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.146</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.14600000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.16500001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.165</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.16500001</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.12000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.12000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.120</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >56.54999924</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >56.55</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >56.54999924</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >67.87000275</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >67.87</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >67.87000275</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.46540001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.4654</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.46540001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >17.91300011</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >17.913</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >17.91300011</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21259999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.2126</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21259999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >25.98399925</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >25.984</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >25.98399925</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >54.01599884</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >54.016</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >54.01599884</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >23.24399948</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >23.244</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >23.24399948</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >69.74800110</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >69.748</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >69.74800110</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >53.17300034</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >53.173</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >53.17300034</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.50000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.50000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.500</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.11000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.11000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.110</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.220</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >0.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.25000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.25000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.250</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.150</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.955</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.44999981</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.44999981</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.450</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.44999999</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.44999999</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.450</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.60000002</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.60000002</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.600</value>
</preset>
<preset name="Prophy" number="1" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.25000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.250</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.08000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.08000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.080</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >27.88999939</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >27.890</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >27.88999939</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >91.97000122</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >91.970</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >91.97000122</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.33350000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.3335</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.33350000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.33800000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.338</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.33800000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >16.53499985</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >16.535</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >16.53499985</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >29.76399994</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >29.764</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >29.76399994</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >31.74799919</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >31.748</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >31.74799919</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >58.91299820</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >58.913</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >58.91299820</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.36199999</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.362</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.36199999</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >54.84999847</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >54.850</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >54.84999847</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.50000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.50000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.500</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.000</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.240</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.18000001</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.18000001</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.180</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >1.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.955</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.44999981</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.44999981</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.450</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.44999999</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.44999999</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.450</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.60000002</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.60000002</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.600</value>
</preset>
<preset name="PWM Power" number="2" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.21600001</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.216</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.21600001</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.000</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.000</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.00000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >24.57999992</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >24.580</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >24.57999992</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >91.97000122</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >91.970</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >91.97000122</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.31000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.310</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.31000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.37799999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.378</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.37799999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >25.35400009</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >25.354</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >25.35400009</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >47.40200043</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >47.402</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >47.40200043</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.30000001</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.300</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.30000001</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >37.92100143</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >37.921</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >37.92100143</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.20000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.20000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.200</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.50000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.50000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.500</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >1.000</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.06000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.06000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.060</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >2.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.955</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.44999981</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.44999981</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.450</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.44999999</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.44999999</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.450</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.60000002</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.60000002</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.600</value>
</preset>
<preset name="Superstack" number="3" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-3.34999990</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-3.350</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-3.34999990</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.16300000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.163</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.16300000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >83.01000214</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >83.010</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >83.01000214</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >67.87000275</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >67.870</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >67.87000275</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.38000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.380</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.38000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.45699999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.457</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.45699999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >22.04700089</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >22.047</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >22.04700089</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >48.07899857</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >48.079</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >48.07899857</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.03900000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.039</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.03900000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >41.98400116</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >41.984</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >41.98400116</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.37000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.37000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.370</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.12000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.12000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.120</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >3.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.500</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.230</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.23999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.23999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.240</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.400</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.000</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.19000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.19000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.190</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.955</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.43000001</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.43000001</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.430</value>
</preset>
<preset name="Spacy Sweep" number="4" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17899990</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.179</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17899990</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.14000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.140</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.14000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.14000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.140</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.14000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.12000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.12000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.120</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >56.54999924</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >56.55</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >56.54999924</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >73.90000153</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >73.9</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >73.90000153</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.68199998</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.682</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.68199998</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.13400000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.134</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.13400000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >44.88199997</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >44.882</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >44.88199997</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >57.87400055</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >57.874</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >57.87400055</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >68.03099823</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >68.031</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >68.03099823</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >64.33100128</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >64.331</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >64.33100128</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >69.74800110</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >69.748</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >69.74800110</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.10000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.10000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.100</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.85000002</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.85000002</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.850</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.220</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >4.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.500</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.230</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.23999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.23999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.240</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.400</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.000</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.19000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.19000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.190</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.955</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.36629999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.36600000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.366</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.396</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Sharp PWM" number="5" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-42.95999908</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-42.960</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-42.95999908</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.09200000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.092</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.09200000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.08900000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.089</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.08900000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.000</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.00000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.100</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >35.61000061</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >35.610</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >35.61000061</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >1.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.51200002</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.512</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.51200002</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.13400000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.134</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.13400000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >52.36199951</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >52.362</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >52.36199951</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >46.72399902</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >46.724</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >46.72399902</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >65.68499756</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >65.685</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >65.68499756</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.40000010</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.40000010</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.400</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >5.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.500</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.230</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.23999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.23999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.240</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.400</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.000</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.19000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.19000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.190</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.955</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.36629999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.36600000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.366</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.396</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Funky Syn" number="6" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.17900001</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.179</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.17900001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.20299999</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.203</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.20299999</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >19.06999969</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >19.070</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >19.06999969</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.62800002</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.628</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.62800002</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.41700000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.417</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.41700000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >8.97599983</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >8.976</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >8.97599983</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >9.92099953</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >9.921</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >9.92099953</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >40.63000107</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >40.630</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >40.63000107</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.53500003</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.535</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.53500003</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >63.65399933</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >63.654</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >63.65399933</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.01000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.01000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.010</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.16000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.16000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.160</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.16000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.16000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.160</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >6.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.955</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.36629999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.36600000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.366</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.396</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Paris" number="7" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-5.00000000</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-5.000</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-5.00000000</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.03900000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.039</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.03900000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.14900000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.149</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.14900000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.20600000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.206</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.20600000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.06000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.06000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.060</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >35.61000061</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >35.610</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >35.61000061</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >84.61000061</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >84.610</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >84.61000061</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.37200001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.372</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.37200001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >3.58299994</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >3.583</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >3.58299994</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.13400000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.134</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.13400000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >30.70899963</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >30.709</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >30.70899963</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >55.11800003</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >55.118</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >55.11800003</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >64.62999725</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >64.630</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >64.62999725</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >67.71700287</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >67.717</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >67.71700287</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >79.90599823</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >79.906</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >79.90599823</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.40000001</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.40000001</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.400</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.140</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.23999999</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.23999999</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.240</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >7.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.500</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.230</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.250</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.400</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.000</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.200</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.95499992</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.955</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Zufall" number="8" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >1.60000002</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >1.600</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >1.60000002</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >2.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81300002</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.813</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81300002</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.05100000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.051</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.05100000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.10200000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.102</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.10200000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.12200000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.122</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.12200000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.02000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.02000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.020</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >34.50000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >34.500</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >34.50000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >85.94000244</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >85.940</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >85.94000244</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.62000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.620</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.62000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >27.12599945</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >27.126</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >27.12599945</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.000</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >4.25199986</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >4.252</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >4.25199986</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >41.88999939</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >41.890</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >41.88999939</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >39.11800003</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >39.118</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >39.11800003</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >73.81099701</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >73.811</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >73.81099701</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.54299998</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.543</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.54299998</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >85.32299805</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >85.323</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >85.32299805</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.70999998</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.70999998</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.710</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.140</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.28999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.28999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.290</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.120</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >8.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >222.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >222.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >222.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >438.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >438.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >438.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.150</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >10.64000034</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >10.64000034</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >10.640</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.99000001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.99000001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.990</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >10.25000000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >10.25000000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >10.250</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.09000000</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.09000000</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.090</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.99000001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.99000001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.990</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.11000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.11000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.110</value>
</preset>
<preset name="Solina" number="9" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-5.82999992</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-5.830</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-5.82999992</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.01600000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.016</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.01600000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81300002</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.813</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81300002</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.09400000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.094</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.09400000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.09600000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.096</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.09600000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.100</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >44.43000031</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >44.430</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >44.43000031</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.19400001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.194</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.19400001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.12600000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.126</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.12600000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >31.18099976</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >31.181</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >31.18099976</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >54.56700134</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >54.567</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >54.56700134</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >39.11800003</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >39.118</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >39.11800003</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >73.81099701</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >73.811</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >73.81099701</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >1.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >1.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >1.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >85.32299805</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >85.323</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >85.32299805</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.34999999</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.34999999</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.350</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.140</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.44000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.44000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.440</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.120</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >9.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.500</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.230</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.250</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.400</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.000</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.200</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.985</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.36629999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.36600000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.366</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.396</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.520</value>
</preset>
<preset name="Noiz Baz" number="10" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-80.09999847</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-80.100</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-80.09999847</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.19499999</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.195</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.19499999</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.15500000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.155</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.15500000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.25000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.250</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.25000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >51.04000092</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >51.040</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >51.04000092</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.29499999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.295</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.29499999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >8.18900013</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >8.189</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >8.18900013</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >0.000</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >40.63000107</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >40.630</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >40.63000107</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >32.50400162</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >32.504</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >32.50400162</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.240</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.06000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.06000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.060</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >10.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >0.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.985</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.36629999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.36600000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.366</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.396</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.520</value>
</preset>
<preset name="Puls Uni" number="11" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-85.87000275</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-85.870</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-85.87000275</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.24800000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.248</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.24800000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.24200000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.242</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.24200000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.000</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.00000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >56.54999924</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >56.550</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >56.54999924</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.44200000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.442</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.44200000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.30700001</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.307</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.30700001</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >0.000</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >41.98400116</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >41.984</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >41.98400116</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >21.66900063</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >21.669</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >21.66900063</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.000</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.19000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.19000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.190</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >11.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.985</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.36629999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.36600000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.366</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.39600000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.396</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.520</value>
</preset>
<preset name="Euro" number="12" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-85.87000275</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-85.870</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-85.87000275</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.09400000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.094</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.09400000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.17500000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.175</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.17500000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.100</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >95.12999725</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >95.130</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >95.12999725</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >93.30999756</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >93.310</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >93.30999756</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.29499999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.295</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.29499999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.27599999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.276</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.27599999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >2.20499992</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >2.205</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >2.20499992</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >50.11000061</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >50.110</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >50.11000061</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >18.28300095</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >18.283</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >18.28300095</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.10000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.10000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.100</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.25999999</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.25999999</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.260</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.19000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.19000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.190</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >12.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.150</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >10.83500004</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >10.83500004</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >10.835</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.99000001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.99000001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.990</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >10.05500031</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >10.05500031</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >10.055</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.08000000</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.08000000</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.080</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.99000001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.99000001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.990</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.11000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.11000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.110</value>
</preset>
<preset name="Poly 8" number="13" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-5.00000000</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-5.000</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-5.00000000</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.22600000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.226</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.22600000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.22600000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.226</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.22600000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.18000001</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.18000001</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.180</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >75.29000092</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >75.290</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >75.29000092</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >74.56999969</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >74.570</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >74.56999969</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.36399999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.364</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.36399999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >24.45199966</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >24.452</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >24.45199966</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >59.59099960</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >59.591</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >59.59099960</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.25999999</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.260</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.25999999</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >48.75600052</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >48.756</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >48.75600052</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.09999990</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.09999990</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.100</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.55000001</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.55000001</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.550</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.02000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.02000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.020</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.120</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >13.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.200</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.23999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.23999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.240</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.150</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.22770000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.22800000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.228</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Mega Bass" number="14" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.10000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.100</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.10000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.10000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.100</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.10000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.000</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.00000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >55.45000076</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >55.450</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >55.45000076</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.27200001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.272</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.27200001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.37799999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.378</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.37799999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >0.000</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >50.11000061</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >50.110</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >50.11000061</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.05500000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.055</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.05500000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >41.98400116</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >41.984</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >41.98400116</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.22000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.22000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.220</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >1.000</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.09000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.09000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.090</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >14.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.200</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.23999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.23999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.240</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.150</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.22770000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.22800000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.228</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="BPF Pad" number="15" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-9.96000004</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-9.960</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-9.96000004</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.03100000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.031</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.03100000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.24200000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.242</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.24200000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.24200000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.242</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.24200000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.100</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >52.13999939</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >52.140</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >52.13999939</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >1.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >64.52999878</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >64.530</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >64.52999878</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.46500000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.465</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.46500000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >1.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >1.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >1.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.15000001</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.150</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.15000001</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >42.04700089</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >42.047</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >42.04700089</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >56.77199936</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >56.772</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >56.77199936</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >68.03099823</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >68.031</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >68.03099823</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >78.55100250</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >78.551</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >78.55100250</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >77.87400055</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >77.874</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >77.87400055</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.70000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.70000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.700</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.64999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.64999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.650</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.15000001</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.15000001</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.150</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.220</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >15.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.500</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.230</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.250</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.400</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.000</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.19000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.19000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.190</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.22770000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.22800000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.228</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Reso Fly" number="16" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-11.60999966</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-11.610</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-11.60999966</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.01600000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.016</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.01600000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.06900000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.069</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.06900000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.05900000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.059</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.05900000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.000</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.00000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.08000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.08000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.080</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >74.19000244</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >74.190</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >74.19000244</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >67.19999695</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >67.200</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >67.19999695</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.75999999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.760</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.75999999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >1.53499997</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >1.535</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >1.53499997</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.37799999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.378</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.37799999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >13.70100021</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >13.701</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >13.70100021</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >48.50400162</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >48.504</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >48.50400162</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >62.29899979</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >62.299</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >62.29899979</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.05500000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.055</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.05500000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >75.16500092</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >75.165</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >75.16500092</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.17000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.17000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.170</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.230</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.14000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.14000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.140</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >16.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.500</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.23000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.230</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.250</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.400</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.000</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.200</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.22770000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.22800000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.228</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Fat Hook" number="17" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00800000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.008</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00800000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.24400000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.244</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.24400000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.24400000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.244</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.24400000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.02000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.02000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.020</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >70.87999725</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >70.880</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >70.87999725</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.34900001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.349</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.34900001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.37799999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.378</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.37799999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >18.18899918</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >18.189</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >18.18899918</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >74.48799896</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >74.488</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >74.48799896</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.99199998</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.992</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.99199998</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >30.47200012</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >30.472</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >30.47200012</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.10000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.10000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.100</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.11000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.11000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.110</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.25999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.25999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.260</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >17.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.200</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.23999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.23999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.240</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.16000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.16000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.160</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Space SQ" number="18" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.18700001</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.187</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.18700001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >10.25000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >10.250</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >10.25000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.24800000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.248</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.24800000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.44900000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.449</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.44900000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >22.59799957</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >22.598</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >22.59799957</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >39.95299911</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >39.953</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >39.95299911</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >67.71700287</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >67.717</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >67.71700287</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.80000001</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.80000001</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.800</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.27000001</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.27000001</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.270</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.000</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.50999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.50999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.510</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.11000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.11000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.110</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >18.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.15000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.15000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.150</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.34000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.34000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.340</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Fat SQ" number="19" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00800000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.008</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00800000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.12000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.120</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.12000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.23999999</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.240</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.23999999</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >17.96999931</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >17.970</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >17.96999931</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.31000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.310</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.31000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.37799999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.378</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.37799999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >24.80299950</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >24.803</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >24.80299950</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >41.98400116</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >41.984</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >41.98400116</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.02300000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.023</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.02300000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >86.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >86.000</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >86.00000000</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.320</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.170</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >19.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.150</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="BEF SQ LFO" number="20" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-85.05000305</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-85.050</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-85.05000305</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.23999999</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.240</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.23999999</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.23999999</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.240</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.23999999</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.100</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >65.37000275</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >65.370</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >65.37000275</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >1.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >87.94999695</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >87.950</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >87.94999695</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.35699999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.357</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.35699999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >21.49600029</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >21.496</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >21.49600029</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >1.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >1.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >1.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >15.11800003</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >15.118</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >15.11800003</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >58.42499924</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >58.425</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >58.42499924</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >29.11800003</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >29.118</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >29.11800003</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >56.88199997</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >56.882</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >56.88199997</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.70000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.70000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.700</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.64999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.64999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.650</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.28999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.28999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.290</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.140</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.220</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >20.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.34999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.34999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.350</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="SQ Random" number="21" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-80.09999847</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-80.100</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-80.09999847</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >1.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.19300000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.193</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.19300000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >22.37999916</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >22.380</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >22.37999916</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.27200001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.272</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.27200001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.41700000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.417</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.41700000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >31.41699982</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >31.417</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >31.41699982</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >37.24399948</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >37.244</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >37.24399948</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >86.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >86.000</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >86.00000000</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.47000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.47000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.470</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.000</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.070</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >21.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.34999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.34999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.350</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="HPF SQ LFO" number="22" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-84.22000122</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-84.220</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-84.22000122</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.25000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.250</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.08000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.08000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.080</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >47.72999954</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >47.730</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >47.72999954</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >0.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >86.61000061</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >86.610</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >86.61000061</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.15500000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.155</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.15500000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >21.49600029</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >21.496</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >21.49600029</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >1.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >1.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >1.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.94499999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.945</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.94499999</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >43.54299927</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >43.543</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >43.54299927</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >29.11800003</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >29.118</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >29.11800003</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >52.14199829</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >52.142</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >52.14199829</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.70000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.70000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.700</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.64999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.64999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.650</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.140</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.220</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >22.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.15000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.15000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.150</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.23999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.23999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.240</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Chord SQ LFO" number="23" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-84.22000122</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-84.220</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-84.22000122</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.21500000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.215</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.21500000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.21600001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.216</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.21600001</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.08000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.08000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.080</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >78.59999847</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >78.600</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >78.59999847</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >75.91000366</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >75.910</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >75.91000366</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.36399999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.364</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.36399999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >34.80300140</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >34.803</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >34.80300140</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >1.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >1.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >1.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >29.76399994</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >29.764</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >29.76399994</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >41.98400116</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >41.984</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >41.98400116</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >58.23600006</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >58.236</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >58.23600006</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.70000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.70000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.700</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.64999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.64999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.650</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.47000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.47000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.470</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.140</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.22000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.220</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >23.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.15000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.15000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.150</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.210</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.25000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.25000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.250</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.34999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.34999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.350</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Straight SQ LFO" number="24" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-83.40000153</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-83.400</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-83.40000153</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.20500000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.205</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.20500000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.20299999</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.203</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.20299999</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >73.08999634</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >73.090</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >73.08999634</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >77.23999786</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >77.240</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >77.23999786</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.41900000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.419</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.41900000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >65.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >65.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >65.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.41700000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.417</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.41700000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >29.21299934</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >29.213</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >29.21299934</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >32.50400162</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >32.504</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >32.50400162</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >72.45700073</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >72.457</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >72.45700073</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.08000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.08000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.080</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.240</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.070</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >24.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.210</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.25000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.25000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.250</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.34999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.34999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.350</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Detune SQ LFO" number="25" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-82.56999969</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-82.570</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-82.56999969</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.25000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.250</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.100</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >71.98000336</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >71.980</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >71.98000336</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >88.62000275</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >88.620</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >88.62000275</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.35699999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.357</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.35699999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >65.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >65.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >65.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.41700000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.417</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.41700000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >0.000</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >38.59799957</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >38.598</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >38.59799957</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >29.11800003</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >29.118</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >29.11800003</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.41999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.41999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.420</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.08000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.08000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.080</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.240</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.070</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >25.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.200</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.36000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.36000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.360</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Trance Chords 1" number="26" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-82.56999969</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-82.570</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-82.56999969</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.21500000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.215</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.21500000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.22000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.220</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.22000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.100</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >69.77999878</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >69.780</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >69.77999878</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >85.27999878</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >85.280</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >85.27999878</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.37200001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.372</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.37200001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >30.70899963</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >30.709</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >30.70899963</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.41700000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.417</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.41700000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >23.70100021</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >23.701</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >23.70100021</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >32.50400162</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >32.504</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >32.50400162</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >72.45700073</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >72.457</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >72.45700073</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.10000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.10000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.100</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.19000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.19000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.190</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.08000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.08000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.080</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.240</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.070</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >26.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.36000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.36000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.360</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Trance Chords 2" number="27" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-82.56999969</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-82.570</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-82.56999969</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.22000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.220</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.22000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.17700000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.177</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.17700000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.100</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >58.75999832</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >58.760</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >58.75999832</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >87.94999695</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >87.950</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >87.94999695</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.37200001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.372</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.37200001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >30.70899963</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >30.709</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >30.70899963</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.41700000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.417</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.41700000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >23.14999962</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >23.150</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >23.14999962</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >39.27600098</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >39.276</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >39.27600098</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >70.42500305</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >70.425</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >70.42500305</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.10000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.10000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.100</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.18000001</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.18000001</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.180</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.08000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.08000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.080</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.240</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.070</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >27.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.34999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.34999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.350</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Short Chords" number="28" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-80.09999847</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-80.100</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-80.09999847</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.21799999</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.218</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.21799999</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.21600001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.216</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.21600001</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.06000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.06000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.060</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >51.04000092</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >51.040</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >51.04000092</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >79.25000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >79.250</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >79.25000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.31000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.310</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.31000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >38.89799881</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >38.898</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >38.89799881</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >1.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >1.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >1.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >14.33100033</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >14.331</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >14.33100033</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >25.73200035</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >25.732</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >25.73200035</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.37799999</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.378</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.37799999</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >48.07899857</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >48.079</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >48.07899857</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.25000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.25000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.250</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.14000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.14000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.140</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >28.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.16000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.16000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.160</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.36000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.36000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.360</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.985</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.49500000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.49500000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.495</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Velo Power" number="29" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-81.75000000</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-81.750</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-81.75000000</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.000</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >63.16999817</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >63.170</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >63.16999817</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >84.61000061</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >84.610</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >84.61000061</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.41100001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.411</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.41100001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >43.50400162</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >43.504</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >43.50400162</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.37799999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.378</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.37799999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >24.25200081</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >24.252</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >24.25200081</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >39.27600098</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >39.276</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >39.27600098</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >33.85800171</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >33.858</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >33.85800171</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.22000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.22000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.220</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.02000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.02000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.020</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >29.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.15000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.15000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.150</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.34000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.34000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.340</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Oktavstrings" number="30" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.31000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.310</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.31000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.07300000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.073</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.07300000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.15700001</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.157</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.15700001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.03100000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.031</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.03100000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.04000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.04000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.040</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >44.43000031</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >44.430</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >44.43000031</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.19400001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.194</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.19400001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >24.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >24.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >24.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.12600000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.126</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.12600000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >41.57500076</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >41.575</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >41.57500076</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >54.56700134</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >54.567</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >54.56700134</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >37.98400116</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >37.984</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >37.98400116</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >73.81099701</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >73.811</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >73.81099701</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >1.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >1.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >1.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >85.32299805</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >85.323</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >85.32299805</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.44999999</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.44999999</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.450</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.33000001</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.33000001</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.330</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.44000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.44000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.440</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.120</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >30.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.500</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.23999999</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.23999999</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.240</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.250</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.400</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.000</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.200</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.985</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.35640001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.35600001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.356</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.38609999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.38600001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.386</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Glider" number="31" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.02600000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.026</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.02600000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.22400001</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.224</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.22400001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.16300000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.163</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.16300000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.04000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.04000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.040</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >44.43000031</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >44.430</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >44.43000031</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.39600000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.396</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.39600000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >24.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >24.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >24.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.12600000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.126</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.12600000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >41.57500076</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >41.575</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >41.57500076</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >54.56700134</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >54.567</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >54.56700134</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >23.81100082</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >23.811</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >23.81100082</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >68.39399719</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >68.394</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >68.39399719</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.30700001</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.307</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.30700001</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >85.32299805</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >85.323</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >85.32299805</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.36000001</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.36000001</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.360</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.44999999</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.44999999</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.450</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.33000001</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.33000001</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.330</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.44000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.44000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.440</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.120</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >31.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.500</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.25000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.25000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.250</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.25999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.25999999</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.260</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.400</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.000</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.23999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.23999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.240</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >4.98500013</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >4.985</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.52469999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.52499998</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.525</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.43000001</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.43000001</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.430</value>
</preset>
<preset name="Soft Lead" number="32" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-9.13000011</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-9.130</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-9.13000011</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00800000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.008</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00800000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.14000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.140</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.14000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >1.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.03100000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.031</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.03100000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.000</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.00000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >67.56999969</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >67.570</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >67.56999969</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >76.56999969</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >76.570</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >76.56999969</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.24800000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.248</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.24800000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >24.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >24.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >24.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >33.07099915</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >33.071</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >33.07099915</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >33.07099915</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >33.071</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >33.07099915</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >53.85800171</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >53.858</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >53.85800171</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >48.07899857</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >48.079</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >48.07899857</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.06300000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.063</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.06300000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >27.76399994</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >27.764</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >27.76399994</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.44999999</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.44999999</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.450</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.01000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.01000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.010</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.16000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.16000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.160</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.120</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >32.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.28999999</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.28999999</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.290</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.30000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.30000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.300</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.31999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.31999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.320</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.16000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.16000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.160</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >0.50000000</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >0.50000000</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >0.500</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.99000001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.99000001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.990</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >0.50000000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >0.50000000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >0.500</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.12000000</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.12000000</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.120</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.99000001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.99000001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.990</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.17000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.17000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.170</value>
</preset>
<preset name="Vintage Lead" number="33" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-7.48000002</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-7.480</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-7.48000002</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00600000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.006</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00600000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.17700000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.177</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.17700000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.18500000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.185</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.18500000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.10000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.100</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >74.19000244</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >74.190</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >74.19000244</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >76.56999969</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >76.570</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >76.56999969</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.33300000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.333</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.33300000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >24.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >24.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >24.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.12600000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.126</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.12600000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >19.29100037</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >19.291</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >19.29100037</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >48.07899857</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >48.079</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >48.07899857</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.63800001</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.638</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.63800001</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >25.05500031</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >25.055</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >25.05500031</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.15000001</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.15000001</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.150</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.44999999</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.44999999</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.450</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.02000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.02000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.020</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.16000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.16000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.160</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.120</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >33.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.16000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.16000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.160</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.150</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Software" number="34" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-29.76000023</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-29.760</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-29.76000023</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.54900002</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.549</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.54900002</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.08300000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.083</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.08300000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >1.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.22600000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.226</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.22600000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.000</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.00000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >41.11999893</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >41.120</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >41.11999893</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >87.94999695</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >87.950</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >87.94999695</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.31799999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.318</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.31799999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >3.58299994</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >3.583</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >3.58299994</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >24.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >24.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >24.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.13400000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.134</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.13400000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >5.19700003</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >5.197</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >5.19700003</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >59.52799988</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >59.528</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >59.52799988</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >69.07099915</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >69.071</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >69.07099915</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >79.90599823</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >79.906</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >79.90599823</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.14000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.140</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.23999999</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.23999999</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.240</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >34.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.50000000</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.500</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.23999999</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.23999999</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.240</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.25000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.250</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.40000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.400</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.00000000</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.000</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.200</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >20.00000000</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >20.00000000</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >20.000</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.99000001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.99000001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.990</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >20.00000000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >20.00000000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >20.000</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.16000000</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.16000000</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.160</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.99000001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.99000001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.990</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.12000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.12000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.120</value>
</preset>
<preset name="SH Gruv" number="35" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-5.00000000</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-5.000</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-5.00000000</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >2.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.18500000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.185</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.18500000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.16900000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.169</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.16900000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.04000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.04000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.040</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >35.61000061</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >35.610</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >35.61000061</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >87.94999695</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >87.950</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >87.94999695</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.70599997</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.706</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.70599997</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >53.22800064</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >53.228</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >53.22800064</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >24.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >24.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >24.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.000</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >5.19700003</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >5.197</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >5.19700003</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >28.11000061</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >28.110</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >28.11000061</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >66.36199951</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >66.362</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >66.36199951</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.31500000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.315</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.31500000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >79.90599823</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >79.906</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >79.90599823</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.08000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.08000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.080</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.19000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.19000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.190</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.15000001</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.15000001</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.150</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >35.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.200</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.23999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.23999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.240</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.150</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.23760000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.23800001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.238</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.520</value>
</preset>
<preset name="Square Dance" number="36" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-90.00000000</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-90.000</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-90.00000000</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.06500000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.065</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.06500000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.09800000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.098</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.09800000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.24200000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.242</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.24200000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >76.38999939</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >76.390</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >76.38999939</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >81.93000031</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >81.930</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >81.93000031</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.36399999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.364</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.36399999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >24.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >24.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >24.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.29899999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.299</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.29899999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >14.88199997</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >14.882</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >14.88199997</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >37.24399948</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >37.244</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >37.24399948</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.31500000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.315</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.31500000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >55.52799988</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >55.528</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >55.52799988</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.25000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.25000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.250</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.50000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.50000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.500</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >1.000</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.04000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.04000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.040</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >36.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.200</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.23999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.23999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.240</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.16000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.16000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.160</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.23760000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.23800001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.238</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.520</value>
</preset>
<preset name="Glub" number="37" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-14.90999985</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-14.910</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-14.90999985</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >1.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.02000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.020</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.02000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >-14.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >-14.000</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >-14.00000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.98500001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.985</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.98500001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >1.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >1.000</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >1.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >0.000</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >27.08699989</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >27.087</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >27.08699989</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >35.88999939</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >35.890</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >35.88999939</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.40000010</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.40000010</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.400</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >9.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >9.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >9.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.69000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.69000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.690</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.50000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.50000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.500</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >1.000</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.08000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.08000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.080</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >37.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >250.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >250.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >250.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >500.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >500.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >500.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.28000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.28000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.280</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.30000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.30000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.300</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.31999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.31999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.320</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.200</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Hum" number="38" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-90.00000000</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-90.000</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-90.00000000</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.06500000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.065</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.06500000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.09800000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.098</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.09800000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.24200000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.242</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.24200000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >76.38999939</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >76.390</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >76.38999939</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >81.93000031</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >81.930</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >81.93000031</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.36399999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.364</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.36399999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >24.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >24.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >24.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.29899999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.299</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.29899999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >14.88199997</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >14.882</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >14.88199997</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >37.24399948</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >37.244</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >37.24399948</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.31500000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.315</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.31500000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >55.52799988</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >55.528</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >55.52799988</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.20000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.20000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.200</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.50000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.50000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.500</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >1.000</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.04000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.04000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.040</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >38.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >250.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >250.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >250.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >500.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >500.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >500.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.27000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.27000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.270</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.30000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.30000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.300</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.31999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.31999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.320</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.18000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.18000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.180</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.22770000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.22800000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.228</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Dooh" number="39" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-9.13000011</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-9.130</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-9.13000011</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.03900000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.039</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.03900000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.31000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.310</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.31000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.13400000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.134</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.13400000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.15000001</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.150</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.15000001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.17100000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.171</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.17100000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >57.65000153</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >57.650</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >57.65000153</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >55.83000183</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >55.830</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >55.83000183</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.49599999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.496</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.49599999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.33899999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.339</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.33899999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >0.000</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >18.96100044</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >18.961</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >18.96100044</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.15000001</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.150</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.15000001</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >20.99200058</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >20.992</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >20.99200058</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >12.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >12.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >12.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.07000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.07000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.070</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >9.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >9.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >9.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.000</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >1.000</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >39.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >250.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >250.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >250.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >500.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >500.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >500.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.27000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.27000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.270</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.30000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.30000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.300</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.31999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.31999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.320</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.200</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Funny" number="40" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-5.00000000</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-5.000</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-5.00000000</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.11600000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.116</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.11600000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >16.87000084</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >16.870</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >16.87000084</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >75.91000366</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >75.910</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >75.91000366</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.65899998</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.659</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.65899998</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.69300002</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.693</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.69300002</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >0.000</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >34.58300018</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >34.583</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >34.58300018</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >49.43299866</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >49.433</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >49.43299866</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.40900001</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.409</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.40900001</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >73.13400269</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >73.134</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >73.13400269</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >12.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >12.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >12.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >2.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >2.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >2.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.02000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.02000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.020</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >1.000</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >40.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.37500000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.37500000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.375</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.23760000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.23800001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.238</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.520</value>
</preset>
<preset name="Random LFO" number="41" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-11.60999966</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-11.610</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-11.60999966</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >2.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.14800000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.148</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.14800000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.17100000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.171</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.17100000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.000</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.00000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >54.34999847</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >54.350</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >54.34999847</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >50.47000122</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >50.470</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >50.47000122</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.74500000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.745</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.74500000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >32.75600052</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >32.756</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >32.75600052</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >24.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >24.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >24.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.25200000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.252</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.25200000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >43.54299927</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >43.543</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >43.54299927</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >71.77999878</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >71.780</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >71.77999878</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.63800001</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.638</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.63800001</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >81.93699646</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >81.937</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >81.93699646</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >0.00000000</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >0.000</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >9.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >9.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >9.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.11000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.11000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.110</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.20000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.20000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.200</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.06000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.06000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.060</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >41.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >300.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >300.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >600.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >600.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.27000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.27000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.270</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.30000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.30000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.300</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.31999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.31999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.320</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.14000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.14000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.140</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.37500000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.37500000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.375</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.23760000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.23800001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.238</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.520</value>
</preset>
<preset name="Propaganda" number="42" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-14.90999985</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-14.910</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-14.90999985</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.25000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.250</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.25000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.15400000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.154</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.15400000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.000</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.00000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >59.86000061</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >59.860</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >59.86000061</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.31799999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.318</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.31799999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >13.77999973</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >13.780</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >13.77999973</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >47.40200043</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >47.402</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >47.40200043</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >35.88999939</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >35.890</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >35.88999939</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.23999999</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.23999999</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.240</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >0.00000000</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >0.000</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.28000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.28000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.280</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >1.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >1.000</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.07000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.070</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >42.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >0.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.21780001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.21799999</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.218</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.37500000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.37500000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.375</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.23760000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.23800001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.238</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.51999998</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.520</value>
</preset>
<preset name="Tekkno Basic" number="43" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.17500000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.175</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.17500000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.06000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.06000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.060</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >126.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >126.000</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >126.00000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.51200002</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.512</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.51200002</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.40900001</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.409</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.40900001</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >0.000</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >56.88199997</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >56.882</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >56.88199997</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >37.24399948</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >37.244</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >37.24399948</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.06000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.06000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.060</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.22000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.22000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.220</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.240</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.23999999</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.23999999</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.240</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >43.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.28999999</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.28999999</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.290</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.31000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.31000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.310</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.33000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.33000001</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.330</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.17000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.17000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.170</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Tekkno Fat" number="44" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.17500000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.175</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.17500000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.06000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.06000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.060</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >126.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >126.000</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >126.00000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.51200002</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.512</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.51200002</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.40900001</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.409</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.40900001</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >7.16499996</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >7.165</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >7.16499996</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >56.88199997</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >56.882</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >56.88199997</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >37.24399948</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >37.244</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >37.24399948</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.06000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.06000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.060</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.17000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.17000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.170</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.240</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >44.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.20000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.200</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.31000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.31000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.310</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.47000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.47000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.470</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.200</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >20.00000000</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >20.00000000</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >20.000</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.99000001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.99000001</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.990</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >20.00000000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >20.00000000</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >20.000</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.16000000</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.16000000</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.160</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.99000001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.99000001</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.990</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.12000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.12000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.120</value>
</preset>
<preset name="Tekkno Rezzo" number="45" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.21600001</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.216</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.21600001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >24.57999992</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >24.580</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >24.57999992</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.45800000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.458</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.45800000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.40900001</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.409</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.40900001</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >22.59799957</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >22.598</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >22.59799957</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >57.55899811</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >57.559</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >57.55899811</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.03200000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.032</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.03200000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >85.32299805</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >85.323</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >85.32299805</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.17000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.17000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.170</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.240</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.18000001</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.18000001</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.180</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >45.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.20999999</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.20999999</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.210</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.31000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.31000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.310</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.47999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.47999999</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.480</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.20000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.200</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Poly Uni" number="46" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-5.00000000</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-5.000</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-5.00000000</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.81999999</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.820</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.81999999</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.21600001</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.216</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.21600001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.22000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.220</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.22000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.18000001</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.18000001</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.180</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >66.47000122</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >66.470</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >66.47000122</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >75.23999786</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >75.240</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >75.23999786</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.42699999</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.427</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.42699999</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >24.25200081</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >24.252</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >24.25200081</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >0.000</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >0.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >42.66099930</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >42.661</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >42.66099930</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.14200000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.142</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.14200000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >48.75600052</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >48.756</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >48.75600052</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.09999990</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.09999990</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.100</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >3.70000005</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >3.70000005</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >3.700</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.09000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.09000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.090</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.22000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.220</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.12000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.120</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >46.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.22770000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.22800000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.228</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Jumper" number="47" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.25000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.250</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.14000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.14000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.140</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >75.29000092</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >75.290</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >75.29000092</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.30300000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.303</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.30300000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.33899999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.339</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.33899999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >16.53499985</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >16.535</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >16.53499985</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >29.76399994</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >29.764</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >29.76399994</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >31.74799919</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >31.748</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >31.74799919</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >59.59099960</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >59.591</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >59.59099960</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.36199999</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.362</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.36199999</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >54.84999847</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >54.850</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >54.84999847</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.000</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.230</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.04000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.04000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.040</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >47.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.22770000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.22800000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.228</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Polyswell" number="48" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >0.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.25000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.250</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.14000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.14000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.140</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >44.43000031</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >44.430</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >44.43000031</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >69.87999725</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >69.880</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >69.87999725</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.38000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.380</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.38000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >28.81900024</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >28.819</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >28.81900024</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >51.81100082</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >51.811</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >51.81100082</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >68.59799957</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >68.598</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >68.59799957</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >67.71700287</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >67.717</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >67.71700287</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.13400000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.134</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.13400000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >67.03900146</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >67.039</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >67.03900146</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.000</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.230</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.04000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.04000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.040</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >48.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >1.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.22770000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.22800000</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.228</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.24750000</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.24699999</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.247</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.52999997</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.530</value>
</preset>
<preset name="Init Saw" number="49" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >3.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.000</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.02000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.02000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.020</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >126.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >126.000</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >126.00000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.000</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.37799999</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.378</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.37799999</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >7.16499996</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >7.165</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >7.16499996</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >86.00000000</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >86.000</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >86.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >1.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >1.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >1.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >37.24399948</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >37.244</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >37.24399948</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >0.00000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >0.000</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.00000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.000</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.00000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.00000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.000</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >0.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >49.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >0.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Long Fuzz" number="50" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00800000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.008</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00800000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.12000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.120</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.12000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.23999999</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.240</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.23999999</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >-14.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >-14.000</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >-14.00000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.68300003</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.683</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.68300003</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.16500001</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.165</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.16500001</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >0.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >0.000</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >0.00000000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >67.03900146</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >67.039</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >67.03900146</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.54299998</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.543</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.54299998</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >0.000</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >0.00000000</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.320</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.170</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >1.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >50.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.22000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.22000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.220</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.25000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.25000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.250</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.15000001</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.150</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Q Kick C1" number="51" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00800000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.008</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00800000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >1.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.000</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.23999999</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.240</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.23999999</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >-14.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >-14.000</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >-14.00000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.82200003</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.822</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.82200003</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.21300000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.213</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.21300000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >1.10200000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >1.102</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >1.10200000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >46.04700089</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >46.047</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >46.04700089</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.00000000</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.000</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >0.000</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >0.00000000</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.320</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.170</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >1.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >51.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >200.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >200.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >400.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >400.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.64999998</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.650</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.17000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.170</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.27000001</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.270</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.17000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.170</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >2.90000010</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >2.900</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.08000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.080</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >0.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Fuzz SQ" number="52" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00800000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.008</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00800000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >2.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.000</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >-14.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >-14.000</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >-14.00000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >93.98000336</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >93.980</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >93.98000336</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.68300003</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.683</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.68300003</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.29100001</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.291</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.29100001</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >1.10200000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >1.102</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >1.10200000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >62.29899979</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >62.299</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >62.29899979</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.51200002</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.512</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.51200002</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >0.000</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >0.00000000</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.320</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.170</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >1.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >52.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.15000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.15000001</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.150</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.23999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.23999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.240</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Dist Pulz" number="53" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00800000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.008</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00800000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.59399998</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.594</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.59399998</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.25000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.250</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.25000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >0.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.11400000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.114</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.11400000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.00000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.000</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.00000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.00000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >-14.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >-14.000</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >-14.00000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >93.98000336</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >93.980</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >93.98000336</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.68300003</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.683</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.68300003</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.26800001</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.268</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.26800001</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >1.10200000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >1.102</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >1.10200000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >72.45700073</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >72.457</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >72.45700073</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.25999999</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.260</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.25999999</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >0.000</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >0.00000000</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.00000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.000</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.320</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.170</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >1.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >53.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.23999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.23999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.240</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="Bad Boy" number="54" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00800000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.008</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00800000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.59399998</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.594</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.59399998</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.22100000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.221</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.22100000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.22800000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.228</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.22800000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >-0.02000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >-0.02000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >-0.020</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >-14.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >-14.000</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >-14.00000000</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >93.98000336</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >93.980</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >93.98000336</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.81400001</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.814</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.81400001</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.26800001</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.268</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.26800001</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >1.10200000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >1.102</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >1.10200000</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >68.39399719</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >68.394</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >68.39399719</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.72399998</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.724</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.72399998</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >0.000</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >0.00000000</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.04000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.04000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.040</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.31999999</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.320</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.19000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.190</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.17000000</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.170</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >1.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >1.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >54.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.23000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.23000000</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.230</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
<preset name="HardCoreBass" number="55" >
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="1" >-4.17999983</value>
<value id="{22ca346c-3f17-45c0-a9f8-9f4d3e26f3e3}" mode="4" >-4.180</value>
<value id="{642c07cb-0d5e-4bad-ac8a-31138524619a}" mode="1" >-4.17999983</value>
<value id="{b1ddf7c2-3d7e-44d7-8e5e-f59448eb8c1e}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="1" >0.00000000</value>
<value id="{e1a7990f-523c-4a89-aad0-36e60fcfe344}" mode="4" >0.000</value>
<value id="{f87af5c6-cf47-42a2-abb8-b7444df4395b}" mode="1" >0.00000000</value>
<value id="{e42cba75-2117-423d-ab14-f035f053381a}" mode="1" >2.00000000</value>
<value id="{37f146c2-57bf-4a51-890a-155f3fda4182}" mode="1" >2.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="1" >0.00000000</value>
<value id="{39c1ba2b-75b7-4dfb-b2d2-b7deb44760b3}" mode="4" >0.000</value>
<value id="{13364f3b-fcd8-4e06-bbde-da703d48b25f}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="1" >0.00000000</value>
<value id="{39a81ce9-1e89-49a4-b7f1-f89dcf5e670e}" mode="4" >0.000</value>
<value id="{3a6c021e-2a7f-4939-a0e8-b1811d33f5c2}" mode="1" >0.00000000</value>
<value id="{6b7e0461-5bc9-4e77-95cd-c53e4b4222f7}" mode="1" >1.00000000</value>
<value id="{5cac16cb-1799-4b8c-8b28-a7b088819aa0}" mode="1" >2.00000000</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="1" >0.17900001</value>
<value id="{28c00fc0-b60e-4c59-bde1-80c4d079354a}" mode="4" >0.179</value>
<value id="{58173576-1563-4420-b4c6-495214fe9a70}" mode="1" >0.17900001</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="1" >0.25000000</value>
<value id="{78176f70-03cb-4894-9605-cd4ed3b612dd}" mode="4" >0.250</value>
<value id="{5ae23e36-804c-417f-94a6-d7a98671d3c8}" mode="1" >0.25000000</value>
<value id="{327ac730-039a-4c6c-9440-a32b3f56d549}" mode="1" >0.06000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="1" >0.06000000</value>
<value id="{ffca81dd-fe2e-401f-ad74-621e70836e13}" mode="4" >0.060</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="1" >0.00000000</value>
<value id="{63e57e7c-01ef-47a1-b819-d6b6964cf682}" mode="4" >0.000</value>
<value id="{01c46d69-b2db-4cb2-a2f2-89baa522de26}" mode="1" >0.00000000</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="1" >22.37999916</value>
<value id="{887dc1a5-37db-4f2b-ade2-71bba0dd737f}" mode="4" >22.380</value>
<value id="{dfa4a963-5e88-4eca-ab45-fe6f3dfb63c6}" mode="1" >22.37999916</value>
<value id="{f614b7a4-63dc-4281-8451-6136788f1d8d}" mode="1" >2.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="1" >100.00000000</value>
<value id="{69029598-c644-400a-9ca9-1cc9cf5f6c9f}" mode="4" >100.000</value>
<value id="{85b2ecd0-4bfc-4593-bd50-8bf4544b5303}" mode="1" >100.00000000</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="1" >0.63599998</value>
<value id="{91e17b9a-93b0-4115-b716-eaaa978b7c10}" mode="4" >0.636</value>
<value id="{a0791461-05f9-4dd7-a0de-fbc855336f90}" mode="1" >0.63599998</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="1" >0.00000000</value>
<value id="{a992f830-37d6-41e0-887b-cf359db819df}" mode="4" >0.000</value>
<value id="{5d016743-85d7-456a-8598-1e97091098d7}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="1" >0.00000000</value>
<value id="{ec950d13-7f08-4c56-b68a-4099d0fe230e}" mode="4" >0.000</value>
<value id="{c23be871-3ab5-49a2-ab73-6c85043ebe8c}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="1" >0.00000000</value>
<value id="{6450f06d-d458-466a-8d5c-6298c4a8bbee}" mode="4" >0.000</value>
<value id="{1c1ff342-d5bf-490f-a6bf-51221980dc4f}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="1" >0.00000000</value>
<value id="{c82821cd-6155-4e35-8d35-bc5c2f77bf57}" mode="4" >0.000</value>
<value id="{b8ed00a9-e807-4c3e-9421-a9c935064aa2}" mode="1" >0.00000000</value>
<value id="{50b353e7-299e-41a1-8b16-30a019c4ddb5}" mode="1" >1.00000000</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="1" >7.16499996</value>
<value id="{ddcb2b58-94d8-4a4a-88f4-b3a962a8201d}" mode="4" >7.165</value>
<value id="{2cc0f99c-2217-4cee-96a8-90f8237a826d}" mode="1" >7.16499996</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="1" >1.70099998</value>
<value id="{7eb0d54d-541c-4759-baf0-17a96b733fd9}" mode="4" >1.701</value>
<value id="{8ffee666-07f7-41b6-b755-84e18dc00575}" mode="1" >1.70099998</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="1" >36.56700134</value>
<value id="{b2282bb8-d19b-4e17-9dbf-8cef960e54ef}" mode="4" >36.567</value>
<value id="{2edc58e5-7957-45bd-8cdd-858f2b90eaef}" mode="1" >36.56700134</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="1" >0.37799999</value>
<value id="{06e3f1da-47c1-4a91-bed7-88fbbe17a26a}" mode="4" >0.378</value>
<value id="{366152fc-e59d-4959-8970-0d1616267441}" mode="1" >0.37799999</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="1" >0.00000000</value>
<value id="{89e56c3e-6a73-4b0f-9524-6865f2bfd7a7}" mode="4" >0.000</value>
<value id="{d460dad0-c11e-46a1-a365-a0e14b7dbe89}" mode="1" >0.00000000</value>
<value id="{ff6a8ba9-0c4e-4504-8056-bcf38c56f2e7}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="1" >2.20000005</value>
<value id="{7e3480ec-73da-458d-87ff-d9d7afc83301}" mode="4" >2.200</value>
<value id="{4cbe5fcd-8c7d-4270-8c3a-47244111be8e}" mode="1" >0.00000000</value>
<value id="{8c454038-062a-4b0e-ae48-725119cb36cb}" mode="1" >0.02000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="1" >0.02000000</value>
<value id="{1b7c6549-2d92-42fa-8cda-1c232d95986e}" mode="4" >0.020</value>
<value id="{51de6163-fc0d-415c-99be-ad03ff79e313}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="1" >1.14999998</value>
<value id="{43b53135-0f7c-4a57-871d-c18990e06c2e}" mode="4" >1.150</value>
<value id="{937adfd8-d994-4175-a2cc-bc6050d490e0}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="1" >0.00000000</value>
<value id="{de43a194-7aae-45f9-8b30-65a28db74fc9}" mode="4" >0.000</value>
<value id="{bc0d866d-b9bf-4d8c-bfb9-083aae7efea2}" mode="1" >-0.17000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="1" >-0.17000000</value>
<value id="{9a2e6492-358c-46fe-8de7-341f4c704d1e}" mode="4" >-0.170</value>
<value id="{60e94c14-63ab-44d8-9ecf-59039180c728}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="1" >0.23999999</value>
<value id="{b17a30cc-4655-4f19-986d-3e33ad924c24}" mode="4" >0.240</value>
<value id="{06211856-2752-4132-a954-7bd84c285c36}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="1" >0.05000000</value>
<value id="{db42035e-f7b0-4137-b27f-0464cda89e85}" mode="4" >0.050</value>
<value id="{ae1ffb1c-6b00-4064-86c0-83de7a7f5330}" mode="1" >0.00000000</value>
<value id="{bca40b7b-2c3b-4884-a877-85391e08bd36}" mode="1" >1.00000000</value>
<value id="{e5f02fc7-c8ad-4efa-8979-a455f4fc4b50}" mode="1" >55.00000000</value>
<value id="{6be2e903-0bbe-41fe-8343-089fbcd2de1b}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="1" >0.50000000</value>
<value id="{8a6fd0c3-466c-40e1-a311-a82342291cb7}" mode="4" >0.500</value>
<value id="{2963de7a-be1d-447f-ab5b-793a53a9666d}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="1" >220.00000000</value>
<value id="{afeddd2f-fca8-4eb5-b5fe-7246cad1fc0c}" mode="4" >220.000</value>
<value id="{b964b8c0-be99-4725-a6d8-ef9d308f5135}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="1" >440.00000000</value>
<value id="{fe5054e9-8a26-4ba7-9700-2fa71d40632d}" mode="4" >440.000</value>
<value id="{1e471b5e-ba10-4ec3-99c8-76ae17ea7440}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="1" >1.60000002</value>
<value id="{08584473-aa83-4cb0-bd90-ae916c48b731}" mode="4" >1.600</value>
<value id="{674ef926-f096-4cbf-9463-b93cdc3c4b71}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="1" >0.14000000</value>
<value id="{6617596a-de0f-43e6-b8bc-431a46eee472}" mode="4" >0.140</value>
<value id="{b6b3e205-041e-4619-a0b9-9207988f6eb7}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="1" >0.20000000</value>
<value id="{d90d390f-534f-401b-8af7-d835ab7f0777}" mode="4" >0.200</value>
<value id="{cd67c41d-1e02-45ee-8ce0-a981721a1323}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="1" >0.20000000</value>
<value id="{6efe5134-a6d0-45b7-a6b1-fc00b5aacf6b}" mode="4" >0.200</value>
<value id="{bc2f0b58-d7d5-4cf4-a0d0-1e587d83399c}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="1" >3.20000005</value>
<value id="{06c09aa5-bb0e-4085-bc82-a9a75218cd4e}" mode="4" >3.200</value>
<value id="{1ef05d8d-20e4-4336-9ce1-03e2f0ba23e4}" mode="1" >0.23999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="1" >0.23999999</value>
<value id="{f91a921a-4a02-4ac6-abbd-83b016c6cb96}" mode="4" >0.240</value>
<value id="{c7cdbc36-cc6d-4a1b-884b-30a3ca1005ae}" mode="1" >0.00000000</value>
<value id="{3f82051f-eb2b-4568-83a6-df731707f43a}" mode="1" >1.00000000</value>
<value id="{2a3d8d6f-18b8-4543-81ae-690b9da1da00}" mode="1" >0.00000000</value>
<value id="{59cb56ba-1834-4f28-aece-d4ced86ab11f}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="1" >5.17999983</value>
<value id="{170a46f5-765e-4a8b-96b6-fad3a7d14dbe}" mode="4" >5.180</value>
<value id="{16036f95-bd0d-44e9-ad75-abece8ffcba8}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="1" >0.69300002</value>
<value id="{154105e8-96a6-4576-ad7d-2bec68a97595}" mode="4" >0.693</value>
<value id="{065b020d-a389-4ef6-87de-b827cb36efc9}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="1" >5.57000017</value>
<value id="{391eafa1-19b3-425c-ae97-9f40a5f76434}" mode="4" >5.570</value>
<value id="{ce1af4d3-7bd9-4c48-9bdb-61a62f3e0575}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="1" >0.43000001</value>
<value id="{77450294-bb31-4d0c-b16b-95ee95790cb9}" mode="4" >0.430</value>
<value id="{f9da2d45-4167-4a28-9247-5e7f19c19564}" mode="1" >0.53460002</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="1" >0.53500003</value>
<value id="{b7fe395a-5d72-44ae-ad9d-b481ee7b1d7a}" mode="4" >0.535</value>
<value id="{314b2676-2771-4847-8fd9-0576014b2b22}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="1" >0.44000000</value>
<value id="{05380af7-7ba0-4c0d-9b4a-7beac0c2f025}" mode="4" >0.440</value>
</preset>
</bsbPresets>
<EventPanel name="Events" tempo="60.00000000" loop="8.00000000" x="1074" y="182" width="519" height="322" visible="false" loopStart="0" loopEnd="0">    </EventPanel>
<EventPanel name="" tempo="60.00000000" loop="8.00000000" x="1050" y="585" width="596" height="322" visible="false" loopStart="0" loopEnd="0">    </EventPanel>
