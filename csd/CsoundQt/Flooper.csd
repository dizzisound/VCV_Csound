;;part of BufPlay1 opcode, written by Joachim Heintz (github.com/csudo/csudo/blob/master/buffers/record_and_play/buffers__record_and_play.udo)
<CsoundSynthesizer>
<CsOptions>
-m229  --omacro:Filepath=/home/moi/Programmes/Rack/plugins/VCV_Csound/samples/hellorcb.wav
</CsOptions>
<CsInstruments>
sr	= 44100
ksmps	= 32
nchnls	= 1
0dbfs	= 1


				;Channel init
	 			chn_k	"Mode",		1
				chn_k	"Gate",		1
				chn_k	"Start",	1
				chn_k	"End",		1
				chn_k	"Transpose",	1

				chn_k	"samplePosition",	2
				chn_k	"FileSr",		2
				chn_k	"FileLen",		2


	iFileSr		filesr	"$Filepath"
			chnset	iFileSr, "FileSr"
	giFileLen	filelen "$Filepath"
			chnset	giFileLen, "FileLen"

			turnon	1

	gitable		ftgen	1, 0, 0, 1, "$Filepath", 0, 0, 1		;channel 1

instr	1	;gui
	gkMode		chnget	"Mode"
	gkGate		chnget	"Gate"
	gkStart		chnget	"Start"
	gkEnd		chnget	"End"
	kTranspose	chnget	"Transpose"
	gkSpeed		= semitone(int(kTranspose))
	gkRange		= gkEnd - gkStart

	if gkRange == 0 then
		gkRange = 0.01
	endif

	ktrig	trigger	gkGate, 0.5, 0

	if gkMode == 1 then 
		kdur	= -1
	else
		kdur	= giFileLen * abs(gkRange) / gkSpeed
	endif

	schedkwhen	ktrig, 0, 0, 2, 0, kdur, giFileLen
endin

instr	2
	if gkGate ==0 && gkMode ==1 then
		turnoff
	endif

	if p4 > 0 then		;BufPlay
		andxrel		phasor 	(1/p4) * gkSpeed / gkRange
		andx		= andxrel * gkRange + gkStart
		asig		table3	andx, 1, 1
				out	asig
				chnset	k(andx), "samplePosition"
	endif
endin
</CsInstruments>  
<CsScore>
</CsScore>
</CsoundSynthesizer>
<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>1118</x>
 <y>216</y>
 <width>366</width>
 <height>259</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="nobackground">
  <r>199</r>
  <g>23</g>
  <b>23</b>
 </bgcolor>
 <bsbObject type="BSBKnob" version="2">
  <objectName>End</objectName>
  <x>200</x>
  <y>40</y>
  <width>50</width>
  <height>50</height>
  <uuid>{bd8883ee-b290-45c2-aa00-2fdbd344a7d8}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>1.00000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>200</x>
  <y>17</y>
  <width>50</width>
  <height>26</height>
  <uuid>{a6d2caa7-9b0a-49e9-8223-f54dfbf09b74}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>End</label>
  <alignment>center</alignment>
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
  <objectName>End</objectName>
  <x>200</x>
  <y>89</y>
  <width>50</width>
  <height>22</height>
  <uuid>{4eb24c7d-a436-4bd0-bc5d-212a275c041e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>1.000</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>12</fontsize>
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
 <bsbObject type="BSBButton" version="2">
  <objectName>Gate</objectName>
  <x>33</x>
  <y>74</y>
  <width>90</width>
  <height>25</height>
  <uuid>{673bb596-57c7-44e6-847e-3ada19c1205a}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>value</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>Trig</text>
  <image>/</image>
  <eventLine/>
  <latch>true</latch>
  <latched>false</latched>
 </bsbObject>
 <bsbObject type="BSBKnob" version="2">
  <objectName>Start</objectName>
  <x>148</x>
  <y>40</y>
  <width>50</width>
  <height>50</height>
  <uuid>{3892e87b-d192-4c10-a824-babffad5cb64}</uuid>
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
  <x>36</x>
  <y>120</y>
  <width>120</width>
  <height>27</height>
  <uuid>{e8ff5bd6-4005-4bc6-86ab-685c9fb776df}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Sample Position :</label>
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
 <bsbObject type="BSBDisplay" version="2">
  <objectName>Start</objectName>
  <x>148</x>
  <y>89</y>
  <width>50</width>
  <height>22</height>
  <uuid>{4719b3db-3e5b-4057-aa86-7ed0e16d445e}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>12</fontsize>
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
 <bsbObject type="BSBKnob" version="2">
  <objectName>Transpose</objectName>
  <x>280</x>
  <y>40</y>
  <width>50</width>
  <height>50</height>
  <uuid>{cbec0cb2-fd44-4992-8374-c6d5d85885d2}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>-12.00000000</minimum>
  <maximum>12.00000000</maximum>
  <value>0.96000000</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>0.01000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>267</x>
  <y>17</y>
  <width>70</width>
  <height>26</height>
  <uuid>{d13f745d-d3e7-474f-a752-9e8f5b4dcb7b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Transpose</label>
  <alignment>center</alignment>
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
  <objectName>Transpose</objectName>
  <x>280</x>
  <y>89</y>
  <width>50</width>
  <height>22</height>
  <uuid>{f2e643eb-e734-4898-a14c-3f0958030c46}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.960</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>12</fontsize>
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
 <bsbObject type="BSBDropdown" version="2">
  <objectName>Mode</objectName>
  <x>33</x>
  <y>37</y>
  <width>90</width>
  <height>25</height>
  <uuid>{03ae68a7-dd87-4923-8bde-e4930133da97}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>-3</midicc>
  <bsbDropdownItemList>
   <bsbDropdownItem>
    <name>One shot</name>
    <value>0</value>
    <stringvalue/>
   </bsbDropdownItem>
   <bsbDropdownItem>
    <name> Loop</name>
    <value>1</value>
    <stringvalue/>
   </bsbDropdownItem>
  </bsbDropdownItemList>
  <selectedIndex>0</selectedIndex>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>samplePosition</objectName>
  <x>155</x>
  <y>122</y>
  <width>101</width>
  <height>24</height>
  <uuid>{3676313e-82f1-4f96-8ef6-36fb802faf97}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>0.000</label>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>12</fontsize>
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
  <x>36</x>
  <y>151</y>
  <width>120</width>
  <height>27</height>
  <uuid>{4f9f944f-c6a7-47dd-b58c-0e2502ffbf5b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>FileSr :</label>
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
 <bsbObject type="BSBDisplay" version="2">
  <objectName>FileSr</objectName>
  <x>155</x>
  <y>153</y>
  <width>101</width>
  <height>24</height>
  <uuid>{e3ffe2e9-812e-4ff0-958c-b44e39dc3e28}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>12</fontsize>
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
  <x>36</x>
  <y>182</y>
  <width>120</width>
  <height>27</height>
  <uuid>{94c3ef3f-524f-4c4f-b2fc-4f4410f541e6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>FileLen :</label>
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
 <bsbObject type="BSBDisplay" version="2">
  <objectName>FileLen</objectName>
  <x>155</x>
  <y>184</y>
  <width>101</width>
  <height>24</height>
  <uuid>{dfa63a0e-68d1-4db8-8e7e-98475a4c766c}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label/>
  <alignment>center</alignment>
  <font>Liberation Sans</font>
  <fontsize>12</fontsize>
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
</bsbPanel>
<bsbPresets>
</bsbPresets>
