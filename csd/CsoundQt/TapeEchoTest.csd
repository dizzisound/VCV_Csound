<CsoundSynthesizer>
<CsOptions>
-dm0 -iadc -odac -b32 -B1024 -+rtaudio=alsa -+rtmidi=null
</CsOptions>
<CsInstruments>
sr = 48000
ksmps = 64
nchnls = 2
0dbfs = 1

#include "TapeEcho.csd"

gaL init 0
gaR init 0

instr 1
aL, aR diskin2 "ClassicalGuitar.wav", 1
gaL = gaL + 0.75 * aL
gaR = gaL + 0.75 * aR
endin

instr 2
aL, aR ins
aLR = (aL + aR) * 0.5
gaL = gaL + aLR
gaR = gaL + aLR
endin

instr 100
aL = gaL
aR = gaR
kMix = 0.6

kRnd oscili 0.25, 0.125

aoL  TapeEcho4 aL, 0.5, 0.47, 0.6, 7500, 1 + kRnd
aoR  TapeEcho4 aR, 0.75, 0.47, 0.5, 7500, 1 - kRnd

aWetL, aWetR  reverbsc aoL, aoR, 0.7, 10000
     outs kMix * (aoL + 0.35 * aWetL), kMix * (aoR + 0.35 * aWetR)

gaL = 0
gaR = 0
endin
</CsInstruments>
<CsScore>
f0 120000
i 1 0  -1    ; plays file
;i 2 0  -1     ; plays live from input
i 100 0 -1
e
</CsScore>
</CsoundSynthesizer>

