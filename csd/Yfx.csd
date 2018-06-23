<CsoundSynthesizer>
<CsOptions>
-n -dm0 -+rtaudio=null -+rtmidi=null -b1024 -B4096
</CsOptions>
<CsInstruments>
sr      = 44100
ksmps   = 32
nchnls  = 1     ;1 in + 1 out
0dbfs   = 1

turnon  1       ;start instr 1

instr   1

    Sformula = "Y = \n sqrt(x*x)"          ;Put your formula here, to be displayed on Rack module display

            chnset  Sformula, "Formula"
    ain     in
    aout    =       sqrt(ain * ain)         ;Put your formula here
            out     aout
endin
</CsInstruments>
<CsScore>
</CsScore>
</CsoundSynthesizer>

