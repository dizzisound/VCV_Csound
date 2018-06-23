Reverb written by Iain McCurdy, 2012
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

instr   1   ;Reverb
    kfblvl  chnget		"feedback"
    kfco    chnget		"cutoff"
    kfco    expcurve	kfco, 4	                ;Create a mapping curve to give a non linear response
    kfco    scale	    kfco,20000,20	        ;Rescale 0 - 1 to 20 - 20000

    ainL, ainR		ins
	aLeft, aRight	reverbsc	ainL, ainR, kfblvl, kfco, sr, 1.0
                    outs        aLeft, aRight
endin
</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>
