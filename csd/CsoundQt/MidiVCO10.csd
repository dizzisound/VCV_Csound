; Written by Iain McCurdy, 2010
vco2 models a variety of waveforms based on the integration of band-limited impulses.
A key difference with vco opcode is that it precalculates the tables that it will use and therefore requires less realtime computation.
It will however require additional RAM for the storage of these precalculated tables.
Optional use of the vco2init will allow stored tables to be shared between instruments and voices therefore saving RAM and computation
of the tables each time the opcode is initialized - this might prove useful where a high level of polyphony and instrument reiteration is required.
vco2 offers more waveforms than vco and higher quality waveforms. vco2 also allows k-rate modulation of phase which vco does not.

This example can be manipulated using the GUI widgets and it can be partially controlled using a MIDI keyboard
in which case it will respond to MIDI note numbers, key velocity and pitch bend.

Some of vco2's waveform options offer improved efficiency by removing options which might not be needed such as pulse width modulation.
Waveform options that offer multiple types (such as options 2 and 3) can morph between the waveforms offered by modulating 'Pulse Width'.
Choosing the 'User Defined Opcode' option requires the use of the 'vco2init' opcode.
There are additional advantages to using vco2init, even when using vco2's other waveforms:
* Waveforms are loaded at the beginning of the performance as opposed to when the opcode is initialized. This might offer realtime performance adavantages.
* Waveforms can be shared between instances of vco2. This will provide an efficiency advantage if multiple instances of vco2 are begin used.
* By using vco2init we can access vco2's internal waveforms from other opcodes.
The appropriate table numbers can be derived by using the vco2ft opcode.
If 'k-rate phase' has been activated, phase is modulated by a sine wave LFO, the depth and rate of which can be changed by user.
If 'k-rate phase' is not activated, initial phase is set using the 'Initial Phase' slider. It will be heard that phase modulation is heard as a modulation of pitch.
<CsoundSynthesizer>
<CsOptions>
;-n -dm0 -odac -+rtaudio=null -+rtmidi=alsa -Ma -b1024 -B4096
-dm229
</CsOptions>
<CsInstruments>
sr		= 44100
ksmps	= 32
nchnls	= 1
0dbfs	= 1

	;channel init
	chn_k	"Waveform",		1
	chn_k	"Octave",		1
	chn_k	"Semitone",		1
	chn_k	"Harmonics",	1
	chn_k	"PulseWidth",	1
	chn_k	"PhaseDepth",	1
	chn_k	"PhaseRate",	1
	chn_k	"NoiseBW",		1


gisine	ftgen		0, 0, 4096, 10, 1													;Sine wave

itmp	ftgen		1, 0, 16384, 7, 0, 2048, 1, 4096, 1, 4096, -1, 4096, -1, 2048, 0	; user defined waveform -1: trapezoid wave with default parameters
ift		vco2init	-1, 10000, 0, 0, 0, 1

		massign	0, 2
		turnon	1			;GUI update

instr	1	;GUI
	gkWave			chnget	"Waveform"
	kOctave			chnget	"Octave"
	gkOctave		= int(kOctave)
	kSemitone		chnget	"Semitone"
	gkSemitone		= int(kSemitone)
	gknyx			chnget	"Harmonics"
	gkpw			chnget	"PulseWidth"
	gkphsDep		chnget	"PhaseDepth"
	gkphsRte		chnget	"PhaseRate"
	gkbw			chnget	"NoiseBW"	

	gkmode = gkWave * 2
	if gkphsDep > 0.01 then
		gkmode = gkmode + 16
	endif
endin

instr	2	;POLY MIDI INPUT INSTRUMENT
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
	kpw			portk		gkpw, kporttime
	kenv		linsegr	0, 0.01, 1, 0.01, 0

	if gkWave==8 then				;buzz
		asig	buzz		kenv*iamp, kcps,  gknyx * sr /4 / kcps, gisine	
	elseif gkWave==9 then			;noise
		asig	pinkish		4*iamp
		asig	butbp		asig, kcps, kcps * gkbw
	else								;vco2
		kphs	poscil		gkphsDep*0.5, gkphsRte, gisine			;Phase mod
		kphs	=			kphs + 0.5								;Phase depth

;*** All this to reduce click during reinit !!!
		kinit init 0
		kChanged	changed	gknyx, gkmode
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
		asig		vco2		kenv*kfade*iamp, kcps, i(gkmode), kpw, kphs, i(gknyx)/2
					rireturn
	endif
				out		asig
endin
</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>
<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>1184</x>
 <y>41</y>
 <width>521</width>
 <height>809</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="background">
  <r>241</r>
  <g>226</g>
  <b>185</b>
 </bgcolor>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>5</x>
  <y>5</y>
  <width>512</width>
  <height>493</height>
  <uuid>{aa607456-d368-4d59-8497-d16d608404c3}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>vco2 </label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>18</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="background">
   <r>63</r>
   <g>162</g>
   <b>255</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>5</borderradius>
  <borderwidth>2</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>8</x>
  <y>248</y>
  <width>160</width>
  <height>30</height>
  <uuid>{b066c36d-a132-4a1a-aee4-e421b02bca48}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Pulse Width / Ramp</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>PulseWidth</objectName>
  <x>448</x>
  <y>248</y>
  <width>60</width>
  <height>30</height>
  <uuid>{262729b5-3e13-43d4-af01-99d1e8aabf34}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.432</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>PulseWidth</objectName>
  <x>8</x>
  <y>232</y>
  <width>500</width>
  <height>27</height>
  <uuid>{f4910f7d-2341-46e1-aa20-a4d3db351c24}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00100000</minimum>
  <maximum>0.99900000</maximum>
  <value>0.43213600</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>8</x>
  <y>325</y>
  <width>220</width>
  <height>30</height>
  <uuid>{d1ad1809-ed86-4ecd-b6c9-15b4c9686e35}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Phase Mod. Depth</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>PhaseDepth</objectName>
  <x>448</x>
  <y>325</y>
  <width>60</width>
  <height>30</height>
  <uuid>{39d4f770-c1eb-4c2d-9b6d-41b78e8955f0}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.200</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>PhaseDepth</objectName>
  <x>8</x>
  <y>309</y>
  <width>500</width>
  <height>27</height>
  <uuid>{37911dd5-758c-4ec8-9871-ce3f5cd67670}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.20000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDropdown" version="2">
  <objectName>Waveform</objectName>
  <x>92</x>
  <y>43</y>
  <width>200</width>
  <height>26</height>
  <uuid>{fd321c7c-a7e3-49dd-9c35-b4d1a0054c73}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>Sawtooth</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Square-PWM</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Sawtooth / Triangle / Ramp</name>
    <value>2</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Pulse</name>
    <value>3</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Parabola</name>
    <value>4</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Square-no PWM</name>
    <value>5</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Triangle</name>
    <value>6</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>User Wave</name>
    <value>7</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Buzz</name>
    <value>8</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name>Pink Noise</name>
    <value>9</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>6</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>12</x>
  <y>43</y>
  <width>80</width>
  <height>26</height>
  <uuid>{e192d1b0-4e18-4b7a-97cb-800767992d7e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Waveform :</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>8</x>
  <y>210</y>
  <width>220</width>
  <height>30</height>
  <uuid>{739c0de4-0e99-4a68-9011-c90835b376ed}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Number of Harmonics</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Harmonics</objectName>
  <x>448</x>
  <y>210</y>
  <width>60</width>
  <height>30</height>
  <uuid>{01641a65-23d8-4e33-932e-417c9b9dbe6c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.500</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>Harmonics</objectName>
  <x>8</x>
  <y>194</y>
  <width>500</width>
  <height>27</height>
  <uuid>{e251ff65-9564-4e72-aa03-739f0cc74de4}</uuid>
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
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>8</x>
  <y>363</y>
  <width>160</width>
  <height>30</height>
  <uuid>{1338d825-15af-4e81-80f6-f224913a4ac9}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Phase Mod. Rate</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>PhaseRate</objectName>
  <x>448</x>
  <y>363</y>
  <width>60</width>
  <height>30</height>
  <uuid>{08fe63ca-841f-46f6-97dc-f5f82273211e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>4.000</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>PhaseRate</objectName>
  <x>8</x>
  <y>347</y>
  <width>500</width>
  <height>27</height>
  <uuid>{c18eed49-061a-498b-a0b1-6e38ba9a1975}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00100000</minimum>
  <maximum>50.00000000</maximum>
  <value>4.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>8</x>
  <y>458</y>
  <width>160</width>
  <height>30</height>
  <uuid>{c1b076c8-6e8c-4a8b-bff1-781ef697954a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Noise Bandwidth</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>NoiseBW</objectName>
  <x>448</x>
  <y>458</y>
  <width>60</width>
  <height>30</height>
  <uuid>{e5fd7457-fcac-4433-9574-ab8bdb6463e6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>1.000</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>NoiseBW</objectName>
  <x>8</x>
  <y>442</y>
  <width>500</width>
  <height>27</height>
  <uuid>{bb9adbb3-40e1-47f3-885f-5a018c5ab8cb}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>10.00000000</maximum>
  <value>1.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>8</x>
  <y>97</y>
  <width>220</width>
  <height>30</height>
  <uuid>{2ef23e28-8861-444d-b006-59898a776eeb}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Octave</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Octave</objectName>
  <x>448</x>
  <y>97</y>
  <width>60</width>
  <height>30</height>
  <uuid>{f7158dee-df4a-47bf-847c-188e921c089a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>Octave</objectName>
  <x>8</x>
  <y>81</y>
  <width>500</width>
  <height>27</height>
  <uuid>{eb49aa9d-b0ac-4855-86d8-e8c4e417f3bc}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>-5.00000000</minimum>
  <maximum>5.00000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>8</x>
  <y>140</y>
  <width>220</width>
  <height>30</height>
  <uuid>{f18b303b-be8e-4050-ab5f-7d588d948140}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Semitone</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Semitone</objectName>
  <x>448</x>
  <y>140</y>
  <width>60</width>
  <height>30</height>
  <uuid>{ad8430e1-6bb8-484a-83dc-3525107e1622}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>right</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>Semitone</objectName>
  <x>8</x>
  <y>124</y>
  <width>500</width>
  <height>27</height>
  <uuid>{e5bb881c-12e0-4334-bf5c-d52110b44d0e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>-12.00000000</minimum>
  <maximum>12.00000000</maximum>
  <value>0.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>7</x>
  <y>401</y>
  <width>76</width>
  <height>30</height>
  <uuid>{1bcf7c46-8a32-4701-aa28-55d7f387624a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Pink Noise:</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>14</fontsize>
  <precision>3</precision>
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
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBScope" version="2">
  <objectName/>
  <x>6</x>
  <y>503</y>
  <width>509</width>
  <height>275</height>
  <uuid>{9ef7ed95-c92b-49dd-82cb-a81b21aa4902}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <value>-255.00000000</value>
  <type>scope</type>
  <zoomx>2.00000000</zoomx>
  <zoomy>1.00000000</zoomy>
  <dispx>1.00000000</dispx>
  <dispy>1.00000000</dispy>
  <mode>0.00000000</mode>
 </bsbObject>
</bsbPanel>
<bsbPresets>
</bsbPresets>
