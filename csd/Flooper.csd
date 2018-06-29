;;part of BufPlay1 opcode, written by Joachim Heintz (github.com/csudo/csudo/blob/master/buffers/record_and_play/buffers__record_and_play.udo)
<CsoundSynthesizer>
<CsOptions>
-n -dm0 -+rtaudio=null -+rtmidi=null -b1024 -B4096
</CsOptions>
<CsInstruments>
sr		= 44100
ksmps	= 32
nchnls	= 1
0dbfs	= 1


            turnon	1

gitable		ftgen	1, 0, 0, 1, "$Filepath", 0, 0, 1		;channel 1

;for file info display in Rack
iFileSr		filesr		"$Filepath"
			chnset	    iFileSr, "FileSr"
giFileLen	filelen 	"$Filepath"
			chnset	    giFileLen, "FileLen"


instr	1	;gui
	gkLoop		chnget	"Loop"
	gkGate		chnget	"Gate"
	gkStart		chnget	"Start"
	gkEnd		chnget	"End"
	kTranspose	chnget	"Transpose"
	gkSpeed		=		semitone(int(kTranspose))
	gkRange		= gkEnd - gkStart

	if gkRange == 0 then
		gkRange = 0.01
	endif

	ktrig		trigger	gkGate, 0.5, 0

	if gkLoop == 1 then 
		kdur	= -1
	else
		kdur	= giFileLen * abs(gkRange) / gkSpeed
	endif

	schedkwhen		ktrig, 0, 0, 2, 0, kdur, giFileLen
endin

instr	2
	if gkGate == 0 && gkLoop == 1 then
		turnoff
	endif

	if p4 > 0 then		;BufPlay
		andxrel	phasor 	(1/p4) * gkSpeed / gkRange
		andx		=		andxrel * gkRange + gkStart
		asig		table3	andx, 1, 1
					out		asig

                   chnset	k(andx), "SamplePos"
	endif
endin
</CsInstruments>  
<CsScore>
</CsScore>
</CsoundSynthesizer>
