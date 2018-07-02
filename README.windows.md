# VCV_Csound
**A quick note about this repo**

This forked repo stores a few slight changes to the original _Makefile_ and _VCV_Csound.hpp_, so as to fix issues preventing the plugin to compile and/or run on the Windows platform.

In brief, the relevant points:
- all Csound script (*.csd) files live in a separate special _/csd/_ folder, that was added to the distributables, as an extra resource folder;
- added conditional `dllexport` attribute implementation, as per this issue: https://github.com/Djack13/VCV-Rack-Csound-Modules/issues/3;
- modified the _Makefile_ adding a Windows conditional block, and including options for the installed Csound headers and library custom paths to be passed via command line. 

About the last point, when building from source, one should call `make` command passing in the CSOUND_INCLUDE and CSOUND_LIBRARY path parameters. Here an example of `make` command, based on the default installation path of the Csound program under Windows:

$ `make CSOUND_INCLUDE="c:/Program Files/Csound6_x64/include" CSOUND_LIBRARY="c:/Program Files/Csound6_x64/lib/"`

When not passing arguments, they default to the standard locations highlighted by developer Djack13 in this issue: https://github.com/Djack13/VCV-Rack-Csound-Modules/issues/2

This release was tested exclusively under Windows 7 / 8.1 x64.

Building against different Linux distros or Mac platform wasn't tested, but it should work as in the original (same constraints and same issues).

Testers, improvements and contributions are welcome, so to evaluate the chance of maintaining a continued sync to the original project.

Thanks to René Djack and Rory Walsh for the original code and compilation tips.
All credits for the original code goes to René Djack.

