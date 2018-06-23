; Vocoder.csd
; Written by Iain McCurdy, 2012 (iainmccurdy.org/csound.html) for Cabbage (cabbageaudio.com)

This is an implementation of a traditional analogue style vocoder. Two audio signals, referred to as a modulator and a carrier, are passed
into the vocoder effect. The modulator is typically a voice and the carrier is typically a synthesizer.
The modulator is analysed by being passed into a multiband filter (a bank of bandpass filters), the amplitude envelope of each band is
tracked and a control function for each band generated. The carrier signal is also passed through a matching multiband filter, the set of
amplitude envelopes derived from the modulator analysis is applied to the outputs of this second multiband filter.

The uppermost band of the filter bank is always a highpass filter.
This is to allow high frequency sibilants in the modulator signal to be accurately represented.

The modulator signal is always the signal received at the left input channel.
For best results it is recommended to use a high quality external microphone.

Carrier Source:
	Source used as carrier signal. Either an internal synth or an external signal.
	If external is chosen, audio is taken from the right input channel.

Filter:
	Steepness: Steepness of the filters used for both analysis and carrier processing.

Synth Type:
	Type of oscillator used by the internal synthesizer. Choose between sawtooth, square, pulse or noise.

Base:
	Frequency of the lowest filter (both analysis and processing) expressed as a MIDI note number.

Num:
	Number of filters that constitute the multibank filters used during both the analysis of the modulator and the carrier processing.

Bandwidth:
	Bandwidth of the bandpass filters expressed in octaves.

Spacing:
	Spacing between the bandpass filters expressed in semitones.

BPF:
	Gain of the bank of bandpass filters.

HPF:
	Gain of the single highpass filter.

Gate Input:
	Activating this switch will apply a noise gate to the modulator signal.
	This option might be useful if the microphone used in rather noisy, such as would be the case if using the built-in microphone on a laptop, or if working in a noisy environment.
<CsoundSynthesizer>
<CsOptions>
-dm0
</CsOptions>
<CsInstruments>
sr	 		= 44100
ksmps		= 64
nchnls		= 1
0dbfs		= 1

		massign	0, 2

gisine	ftgen		0, 0, 4096, 10, 1

;TABLES FOR EXP SLIDER
giExp1		ftgen	0, 0, 256, -25, 0, 0.01, 256, 1.0
giExp2		ftgen	0, 0, 256, -25, 0, 1.0, 256, 12.0
giExp3		ftgen	0, 0, 256, -25, 0, 0.0001, 256, 1.0
giExp4		ftgen	0, 0, 256, -25, 0, 0.0001, 256, 5.0

gaSyn		init	0


opcode VocoderChannel, a, aakiiiii									;MODE UDO 
	aMod,aCar,ksteepness,ibase,ibw,iincr,icount,inum	xin			;NAME INPUT VARIABLES
	icf	=	cpsmidinn(ibase+(icount*iincr))							;DERIVE FREQUENCY FOR *THIS* BANDPASS FILTER BASED ON BASE FREQUENCY AND FILTER NUMBER (icount)
	icount	=	icount + 1												;INCREMENT COUNTER IN PREPARTION FOR NEXT FILTER
	
	if	icf>15000 goto SKIP											;IF FILTER FREQUENCY EXCEEDS A SENSIBLE LIMIT SKIP THE CREATION OF THIS FILTER AND END RECURSION
	
	aModF	butbp	aMod,icf,ibw*icf								;BANDPASS FILTER MODULATOR
	
	if ksteepness=1 then												;IF 24DB PER OCT MODE IS CHOSEN...
	  aModF	butbp	aModF,icf,ibw*icf								;...BANDPASS FILTER AGAIN TO SHARPEN CUTOFF SLOPES
	endif																;END OF THIS CONDITIONAL BRANCH
	aEnv 	follow2	aModF, 0.05, 0.05							;FOLLOW THE ENVELOPE OF THE FILTERED AUDIO

	aCarF	butbp	aCar,icf,ibw*icf									;BANDPASS FILTER CARRIER
	if ksteepness=1 then												;IF 24 DB PER OCT IS CHOSEN...
	  aCarF	butbp	aCarF,icf,ibw*icf								;...BANDPASS FILTER AGAIN TO SHARPEN CUTOFF SLOPES
	endif																;END OF THIS CONDITIONAL BRANCH

	amix	init	0													;INITIALISE MIX VARIABLE CONTAINING ALL SUBSEQUENT BANDS
	
	if	icount < inum	then											;IF MORE FILTERS STILL NEED TO BE CREATED...
		amix	VocoderChannel	aMod,aCar,ksteepness,ibase,ibw,iincr,icount,inum			;...CALL UDO AGAIN WITH INCREMENTED COUNTER
	endif																;END OF THIS CONDITIONAL BRANCH
	SKIP:																;LABEL
		xout	amix + (aCarF*aEnv)								;MIX LOCAL BAND WITH SUBSEQUENT BANDS GENERATED VIA RECURSION
endop																	;END OF UDO

instr	1	;READ IN WIDGETS
	gkCarSource	invalue	"CarSource"							;Carrier Source
	gkbase			invalue	"base"									;Base
	gknum			invalue	"num"									;Num

	kbw			invalue	"bw"									;Bandwidth
	gkbw			tablei		kbw, giExp1, 1
					outvalue	"bw_value", gkbw

	kincr			invalue	"incr"									;Spacing 
	gkincr			tablei		kincr, giExp2, 1
					outvalue	"incr_value", gkincr

	kBPGain		invalue	"BPGain"								;BPF
	gkBPGain		tablei		kBPGain, giExp3, 1
					outvalue	"BPGain_value", gkBPGain

	kHPGain		invalue	"HPGain"								;HPF
	gkHPGain		tablei		kHPGain, giExp3, 1
					outvalue	"HPGain_value", gkHPGain

	gksteepness	invalue	"steepness"							;Steepness
	gkSynType		invalue	"SynType"								;Synth Type	

	gkgate			invalue	"gate"									;Gate Input

	klevel			invalue	"level"									;Level
	gklevel			tablei		klevel, giExp4, 1
					outvalue	"level_value", gklevel
endin

instr	2	;SIMPLE MIDI SYNTH
	icps	cpsmidi													;READ MIDI NOTE IN CPS FORMAT
	icps	=	icps*0.5												;TRANSPOSE DOWN AN OCTAVE
	aenv	linsegr	0,0.01,1,0.02,0								;CREATE A SIMPLE GATE-TYPE ENVELOPE

	if gkSynType==0 then											;IF SYNTH TYPE CHOSEN FROM BUTTON BANK GUI IS SAWTOOTH...
	 a1	vco2	1,icps													;...CREATE A SAWTOOTH WAVE TONE
	 a1	tone	a1,12000												;LOWPASS FILTER THE SOUND
	elseif gkSynType=1 then										;IF SYNTH TYPE CHOSEN FROM BUTTON BANK GUI IS SQUARE...
	 a1	vco2	1,icps,2,0.5											;...CREATE A SQUARE WAVE TONE
	 a1	tone	a1,12000												;LOWPASS FILTER THE SOUND
	elseif gkSynType=2 then										;IF SYNTH TYPE CHOSEN FROM BUTTON BANK GUI IS PULSE...
	 a1	vco2	1,icps,2,0.1											;...CREATE A PULSE WAVE TONE
	 a1	tone	a1,12000												;LOWPASS FILTER THE SOUND
	else																;OTHERWISE...
	 a1	pinkish	10													;...CREATE SOME PINK NOISE
	 a1	butbp	a1,icps,icps											;BANDPASS FILTER THE SOUND. BANDWIDTH = 1 OCTAVE. NARROW BANDWIDTH IF YOU WANT MORE OF A SENSE OF PITCH IN THE NOISE SIGNAL.
	endif																;END OF THIS CONDITIONAL BRANCH
	gaSyn	=	gaSyn + (a1*aenv)									;APPLY ENVELOPE
endin

instr	3	;VOCODER
	ktrig	changed	gkbase,gkbw,gknum,gkincr					;IF ANY OF THE INPUT VARIABLE ARE CHANGED GENERATE A MOMENTARY '1' VALUE (A BANG IN MAX-MSP LANGUAGE)
	if ktrig=1 then													;IF A CHANGED VALUE TRIGGER IS RECEIVED...
	  reinit UPDATE													;REINITIALISE THIS INSTRUMENT FROM THE LABEL 'UPDATE'
	endif																;END OF THIS CONDITIONAL BRANCH
	UPDATE:															;LABEL
	ibase	init	i(gkbase)											;CREATE AN INITIALISATION TIME VARIABLE
	inum	init	i(gknum)											;CREATE AN INITIALISATION TIME VARIABLE
	ibw		init	i(gkbw)											;CREATE AN INITIALISATION TIME VARIABLE
	iincr	init	i(gkincr)											;CREATE AN INITIALISATION TIME VARIABLE
	
	;aMod	inch		1												;READ LIVE AUDIO FROM THE COMPUTER'S LEFT INPUT CHANNEL
	aMod	diskin2	"hellorcb.wav", 1, 0, 1							;READ A FILE FROM DISK

	;GATE MODULATOR SIGNAL
	if gkgate==1 then												;IF 'Gate Modulator' SWITCH IS ON....
	 krms	rms	aMod												;SCAN RMS OF MODUALTOR SIGNAL
	 kgate	=	(krms<0.05?0:1)										;IF RMS OF MODULATOR SIGNAL IS BELOW A THRESHOLD, GATE WILL BE CLOSED (ZERO) OTHERWISE IT WILL BE OPEN ('1').
	 																	;LOWER THE THRESHOLD IF THE GATE IS CUTTING OUT TOO MUCH DESIRED SIGNAL,
	 																	;RAISE IT IF TOO MUCH EXTRANEOUS NOISE IS ENTERING THE OUTPUT SIGNAL.
	 kgate	port	kgate,0.01											;DAMP THE OPENING AND CLOSING OF THE GATE SLIGHTLY
	 agate	interp	kgate												;INTERPOLATE GATE VALUE AND CREATE AN A-RATE VERSION
	 aMod	=	aMod * agate											;APPLY THE GATE TO THE MODULATOR SIGNAL
	endif
	
	if gkCarSource==0 then											;IF 'SYNTH' IS CHOSEN AS CARRIER SOURCE...
	 aCar	=	gaSyn													;...ASSIGN SYNTH SIGNAL FROM INSTR 2 AS CARRIER SIGNAL
	else																;OTHERWISE...
	 aCar	inch	2													;READ AUDIO FROM RIGHT INPUT CHANNEL FOR CARRIER SIGNAL
	endif
		
	icount	init	0													;INITIALISE THE FILTER COUNTER TO ZERO
	amix	VocoderChannel	aMod,aCar,gksteepness,ibase,ibw,iincr,icount,inum		;CALL 'VocoderChannel' UDO
																								;WILL RECURSE WITHIN THE UDO ITSELF FOR THE REQUIRED NUMBER OF FILTERS

	;HIGH-PASS CHANNEL
	iHPcf	=	cpsmidinn(ibase+(inum*iincr)+1)					;HIGHPASS FILTER CUTOFF (ONE INCREMENT ABOVE THE HIGHEST BANDPASS FILTER)
	iHPcf	limit	iHPcf,2000,18000									;LIMIT THE HIGHPASS FILTER TO BE WITHIN SENSIBLE LIMITS

	aModHP	buthp	aMod, iHPcf									;HIGHPASS FILTER THE MODULATOR
	aEnv		follow2	aModHP,0.01,0.01						;FOLLOW THE HIGHPASS FILTERED MODULATOR'S AMPLITUDE ENVELOPE
	aCarHP	buthp	aCar, iHPcf									;HIGHPASS FILTER THE CARRIER
	amix		=	((amix*gkBPGain*5)+(aCarHP*aEnv*gkHPGain*3))*gklevel		;MIX THE HIGHPASS FILTERED CARRIER WITH THE BANDPASS FILTERS. APPLY THE MODULATOR'S ENVELOPE.

				out	amix											;SEND AUDIO TO THE OUTPUTS
				clear	gaSyn											;CLEAR THE INTERNAL SYNTH ACCUMULATING GLOBAL VARIABLE, READ FOR THE NEXT PERF. PASS
				rireturn												;RETURN FROM REINITIALISATION PASS. (NOT REALLY NEED AS THE endin FULFILS THE SAME FUNCTION.)
endin

instr	10	;INIT
		outvalue	"CarSource"	, 0			;gkCarSource -> Internal Synth
		outvalue	"base"			, 40
		outvalue	"num"			, 16
		outvalue	"bw"			, 0.5		;gkbw  = 0.1
		outvalue	"incr"			, 0.648		;gkincr = 5
		outvalue	"BPGain"		, 0.945		;gkBPGain = 0.6
		outvalue	"HPGain"		, 0.849		;gkHPGain = 0.25
		outvalue	"steepness"	, 1			;gksteepness -> 24dB/oct
		outvalue	"SynType"		, 0			;gkSynType -> Saw	
		outvalue	"gate"			, 0			;gkgate -> Off
		outvalue	"level"			, 0.851		;gklevel = 1.0
endin
</CsInstruments>
<CsScore>
i 1 0 [60*60*24*7]		;read in widgets
i 3 0 [60*60*24*7]		;vocoder
i 10 0 0				;init
</CsScore>
</CsoundSynthesizer>

<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>1482</x>
 <y>16</y>
 <width>216</width>
 <height>715</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="nobackground">
  <r>241</r>
  <g>226</g>
  <b>185</b>
 </bgcolor>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>0</x>
  <y>0</y>
  <width>213</width>
  <height>687</height>
  <uuid>{049f4dd4-ff71-4d6d-9157-43c84efad8a4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Vocoder</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>24</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </color>
  <bgcolor mode="background">
   <r>5</r>
   <g>27</g>
   <b>150</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>5</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>107</x>
  <y>37</y>
  <width>100</width>
  <height>42</height>
  <uuid>{3ebc1139-1fdb-48dc-9150-49ee8dfdbd4a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Band Spacing (semitones)</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <objectName>incr_value</objectName>
  <x>117</x>
  <y>159</y>
  <width>80</width>
  <height>30</height>
  <uuid>{e54486c5-f9aa-4d0e-9a67-6506dae3c790}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>5.004</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <x>6</x>
  <y>37</y>
  <width>100</width>
  <height>42</height>
  <uuid>{78a7e9cd-fb57-421c-8e1f-40b60a90dfc0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Bandwidth (octaves)</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <objectName>bw_value</objectName>
  <x>16</x>
  <y>159</y>
  <width>80</width>
  <height>30</height>
  <uuid>{58265963-6245-459e-8071-9ed8bba850a4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.100</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <x>109</x>
  <y>202</y>
  <width>100</width>
  <height>42</height>
  <uuid>{1c02d7bd-4198-417f-a816-a560f4133e23}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Highpass
Filter Gain</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <objectName>HPGain_value</objectName>
  <x>117</x>
  <y>323</y>
  <width>80</width>
  <height>30</height>
  <uuid>{8341c14a-4acb-4d3d-824f-675147975768}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.249</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <x>8</x>
  <y>202</y>
  <width>100</width>
  <height>42</height>
  <uuid>{fd3ea893-7f4f-4d74-a6c6-2ed00b696056}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Bandpass
Filters Gain</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <objectName>BPGain_value</objectName>
  <x>16</x>
  <y>323</y>
  <width>80</width>
  <height>30</height>
  <uuid>{78473677-bb47-45c2-bf88-fa6930dca759}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.603</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <x>19</x>
  <y>439</y>
  <width>60</width>
  <height>30</height>
  <uuid>{d7f5620d-8a05-4982-8edb-af45fcc4611c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Base</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
 <bsbObject type="BSBSpinBox" version="2">
  <objectName>base</objectName>
  <x>80</x>
  <y>439</y>
  <width>60</width>
  <height>30</height>
  <uuid>{66a00915-8240-4189-b441-9cc8399d70aa}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <resolution>1.00000000</resolution>
  <minimum>24</minimum>
  <maximum>80</maximum>
  <randomizable group="0">false</randomizable>
  <value>40</value>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>19</x>
  <y>476</y>
  <width>60</width>
  <height>30</height>
  <uuid>{2ff0a3cd-f045-46fa-bcbc-4f44ee7fb423}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Num.</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
 <bsbObject type="BSBSpinBox" version="2">
  <objectName>num</objectName>
  <x>80</x>
  <y>476</y>
  <width>60</width>
  <height>30</height>
  <uuid>{aa29e343-5d22-4238-bb99-a1a9ba851b2d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <resolution>1.00000000</resolution>
  <minimum>1</minimum>
  <maximum>100</maximum>
  <randomizable group="0">false</randomizable>
  <value>16</value>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>8</x>
  <y>510</y>
  <width>70</width>
  <height>42</height>
  <uuid>{7ba7c4e3-eaeb-4036-b014-11c0c41d483c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Filter
Steepness</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <objectName>CarSource</objectName>
  <x>80</x>
  <y>366</y>
  <width>116</width>
  <height>30</height>
  <uuid>{87392937-db97-42d1-8890-d619532257bb}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>Internal Synth</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>External</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>0</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>SynType</objectName>
  <x>80</x>
  <y>402</y>
  <width>80</width>
  <height>30</height>
  <uuid>{1eca9d44-ace2-4e49-b0ec-ced60019042b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>Saw</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Square</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Pulse</name>
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
  <x>-1</x>
  <y>402</y>
  <width>80</width>
  <height>30</height>
  <uuid>{fc6f50d0-1a2d-471c-9b93-792a6fccca9b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Synth</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <objectName>steepness</objectName>
  <x>80</x>
  <y>513</y>
  <width>50</width>
  <height>30</height>
  <uuid>{81b78f68-290a-483e-8c19-e4b6c24342c4}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>12</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>24</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>1</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>0</x>
  <y>361</y>
  <width>80</width>
  <height>42</height>
  <uuid>{20e8c98c-e334-4f24-bd10-e181988b45fd}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Carrier
Source</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <x>-1</x>
  <y>550</y>
  <width>80</width>
  <height>30</height>
  <uuid>{30de8bf6-4efa-492c-8572-b4bbb17d38e5}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Gate Input</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <objectName>gate</objectName>
  <x>80</x>
  <y>550</y>
  <width>50</width>
  <height>30</height>
  <uuid>{3c7abc6a-ae96-4be0-bf36-12d70f0c6656}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>Off</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>On</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>0</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>level</objectName>
  <x>96</x>
  <y>593</y>
  <width>80</width>
  <height>80</height>
  <uuid>{28cb29c4-be81-4f2b-9274-f1499248f212}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.85100000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>8</x>
  <y>601</y>
  <width>80</width>
  <height>30</height>
  <uuid>{650adef3-40ff-45ff-901a-de133d8492ef}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Level</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <objectName>level_value</objectName>
  <x>8</x>
  <y>634</y>
  <width>80</width>
  <height>30</height>
  <uuid>{4e0abb2f-c08f-4709-a2d7-88ce5209d562}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.997</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
  <objectName>bw</objectName>
  <x>16</x>
  <y>79</y>
  <width>80</width>
  <height>80</height>
  <uuid>{4f9fe5e4-80fa-460d-86ef-35b8395718ed}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.50000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>incr</objectName>
  <x>117</x>
  <y>79</y>
  <width>80</width>
  <height>80</height>
  <uuid>{9938015d-9b7f-4588-af5e-46685336603a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.64800000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>BPGain</objectName>
  <x>16</x>
  <y>243</y>
  <width>80</width>
  <height>80</height>
  <uuid>{0c2e2b91-e48f-49bf-8d62-bd55b8951aa8}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.94500000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>HPGain</objectName>
  <x>117</x>
  <y>243</y>
  <width>80</width>
  <height>80</height>
  <uuid>{2acbc6a5-2e1f-4e9d-9003-dd248066a44b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.84900000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>126</x>
  <y>513</y>
  <width>60</width>
  <height>30</height>
  <uuid>{a786eef8-23dd-48af-81f9-c14001f0c056}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>dB / Oct</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
  <color>
   <r>255</r>
   <g>255</g>
   <b>255</b>
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
</bsbPresets>
<EventPanel name="" tempo="60.00000000" loop="8.00000000" x="913" y="162" width="655" height="346" visible="false" loopStart="0" loopEnd="0">    </EventPanel>
