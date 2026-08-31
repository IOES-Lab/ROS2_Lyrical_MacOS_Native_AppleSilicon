# Analysis correction

The v3 runtime capture itself completed 20 messages on all eight topics. Its
first post-capture verdict was wrong because the script assumed all descriptors
were 8 Hz. The embedded descriptors specify five at 8 Hz, two at 12 Hz, and
one at 7 Hz; the observed median periods are 0.125, 0.083, and 0.142 seconds.
`analyze_capture.py` reads those rates from the committed test world and is the
valid verdict generator. No runtime sample was changed or discarded.
