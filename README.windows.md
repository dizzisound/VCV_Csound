# VCV_Csound - for Windows -

**A quick note about this repo**

This forked repo aims to store those minimal slight changes to the original code, so as to fix the following:
- issues preventing the plugin to compile and/or run on the Windows platform;
- special issues raising exclusively on the Windows platform.

In brief, the relevant points:
- all Csound script (*.csd) files live in a separate special _/csd/_ folder, that was added to the distributables, as an extra resource folder;
- added conditional `dllexport` attribute implementation, as per [this issue](https://github.com/Djack13/VCV-Rack-Csound-Modules/issues/3);
- modified the _Makefile_ adding a Windows conditional block, and including options for the installed Csound headers and library custom paths to be passed via command line. 

About the last point, when building from source, one should call `make` command passing in the CSOUND_INCLUDE and CSOUND_LIBRARY path parameters. More on that in the _"How to build"_ section below.


**Pre-requirements**

The Csound software needs to be installed in your system. You can find it [here](https://csound.com/)
The full installer features a complete setup procedure, that will install documentation, examples, extras and the CsoundQt front-end to Csound engine.
On the website and on the Csound Github [release page](https://github.com/csound/csound/releases) there are also simple binaries releases or minimal releases, simply featuring the core Csound engine and command-line front-end.

Csound it's currently at version 6.11, so this is the "de facto" required version.
In my tests, the plugin could build and run against either the 6.10 or the 6.11 version.

Other important requirements:
- you will need to add your installed Csound _/bin/_ directory to your system path (the full installer should take this step for you)
- create an OPCODE6DIR64 system variable that points to your installed Csound _/plugins64/_ folder.


**How to build**

First steps:
- from the mingw64 shell, set current directory in the Rack/plugins folder, as usual when we clone Rack plugins sources from Github
- clone this repo: 
$ `git clone https://github.com/dizzisound/VCV_Csound.git`
You can optionally specify a different target folder on your machine into which the repo will be cloned, e.g. with:
$ `git clone https://github.com/dizzisound/VCV_Csound.git VCV_Csound-Win-build`
- set current directory where you created the cloned local copy, e.g. `cd VCV_Csound` or `cd VCV_Csound-Win-build`

The _Makefile_ assumes you have your Csound installed in the _/usr/local/csound_ location, related to your MSYS2 folder. 
Simply, that's where I installed it in the first instance. In brief, the first good reason to have it there, is to avoid blank spaces in pathnames. Another good reason is to have it there, next to where other local libraries and headers could possibly live, after the MinGW paradigm. Also, it aims to resemble the assumed Linux default location expected in the original code of this plugin (you can take a look at [this](https://github.com/Djack13/VCV-Rack-Csound-Modules/issues/2) for reference).
So, if you have to go with a fresh install of Csound to build the plugin, I would recommend you to put it there.
In this circumstance, you could then run make command as this:
$ `make CSOUND_INCLUDE=/usr/local/csound/include/csound CSOUND_LIBRARY=/usr/local/csound/lib/`

But probably the most common use case is to have Csound already installed in a different location.
The default location suggested from the installer, for example, is: `C:\Program Files\Csound6_x64`
Furthermore, in a more general case, you could have customized the default installer location to one of your choice, let's say: _C:\Program Files\csound-windows-x64_
In this case you have to deal with blank spaces and a generic location outside the MinGW "comfort zone".

To stay with the last supposed use case, the following example will assume one has the following setup:
- Csound installed in: _C:\Program Files\csound-windows-x64_
- the Csound headers living in: _C:\Program Files\csound-windows-x64\include\csound_
- the Csound object library (csound64.lib) living in: _C:\Program Files\csound-windows-x64\lib_
- the Csound binaries folder being this: _C:\Program Files\csound-windows-x64\bin_
With these assunptions, you should run the make command this way:
$ `make CSOUND_INCLUDE="/c/Program\ Files/csound-windows-x64/include" CSOUND_LIBRARY="/c/Program\ Files/csound-windows-x64/lib/"`

Finally, when not passing arguments to make, they default to the standard locations deriving from the inpreferred installed Csound location suggested above (_/usr/local/csound_).


**Build issues**

If you run in a `<csound/csound.hpp>: No such file or directory` type error, double check the paths you're passing with the CSOUND_INCLUDE and CSOUND_LIBRARY arguments
If you get a bunch of unreferenced symbols, double check you have your installed Csound /bin/ directory added to the system variable PATH. You can check from MinGW shell with the `env` command. If this it's your case, before running `make` you can try to add the _Csound/bin_ path on-the-fly like this (adjust to your real _Csound/bin_ path):
$ `export PATH=$PATH:/C/"Program Files"/csound-windows-x64/bin`
(note the quotes again, not to break things with blank space)
You can check if the _Csound/bin_ path was correctly appended to the pre-existing path, typing newly the `env` command.

If the plugin loads, but you see an OPCODE6DIR6 related folder error, you should add the OPCODE6DIR64 environment variable (see also the _Pre-requirements_ section). You can reveal it by typing either `env` or `$OPCODE6DIR64` from the MinGW shell. If it's not setup, you can set it from the shell like this (adjust to your real _Csound/plugins64_) path:
$ export OPCODE6DIR64="C:\\Program\ Files\\csound-windows-x64\\plugins64\\"
Check the value you set with `env` (`$OPCODE6DIR64` breaks the output you get, but the var should have been correctly set).


**Running Rack from shell**

When you test the plugin running Rack in development mode, e.g. directly from the shell with a `make run` command, verify beforehand you have your _Csound/bin_ path exposed to the system path, typing a `env` command, and possibly add it as described above in the _Build issues_ section. Otherwise, the plugin fails to load and exit with error code 126.
When running the Windows installed Rack, if you let the installer add Csound to your system path (when you first installed Csound) the path to Csound dynamic library should be resolved in the background by the OS.


**Closing notes and credits**

This release was tested exclusively under Windows 7 / 8.1 x64.
Building against different Linux distros or Mac platform wasn't tested, but it should work as in the original (same constraints and same issues).
Testers, improvements and contributions are welcome, so to evaluate the chance of maintaining a continued sync to the original project.
Thanks to [René Djack](https://github.com/Djack13) and [Rory Walsh](https://github.com/rorywalsh) for the original code and compilation tips.
All credits for the original code goes to René Djack.

