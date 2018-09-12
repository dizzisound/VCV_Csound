#include "rack.hpp"

#if defined _WIN32 || defined __CYGWIN__
	#ifdef __GNUC__
		#define DLL_EXPORT __attribute__ ((dllexport))
	#else
		#define DLL_EXPORT __declspec(dllexport)
	#endif
#endif

using namespace rack;

extern Plugin *plugin;

extern Model *modelReverb;
extern Model *modelVocoder;
extern Model *modelMidiVCO10;
extern Model *modelVCO10;
extern Model *modelFlooper;
extern Model *modelYfx;
extern Model *modelDelay;
extern Model *modelChorus;

#if defined _WIN32 || defined CYGWIN
	DLL_EXPORT void init(rack::Plugin *p);
#else //for linux
	void init(rack::Plugin *p);
#endif

struct csKnob : RoundKnob {
	csKnob() : RoundKnob()
	{
		setSVG(SVG::load(assetPlugin(plugin,"res/Knob.svg")));
	}
};

struct csBefacoSwitch : SVGSwitch, ToggleSwitch {
	csBefacoSwitch() {
		addFrame(SVG::load(assetPlugin(plugin, "res/csBefacoSwitch_0.svg")));
		addFrame(SVG::load(assetPlugin(plugin, "res/csBefacoSwitch_1.svg")));
		addFrame(SVG::load(assetPlugin(plugin, "res/csBefacoSwitch_2.svg")));
	}
};

struct AudioInPort : SVGPort {
	AudioInPort() {
		background->svg = SVG::load(assetPlugin(plugin, "res/AudioInPort.svg"));
		background->wrap();
		box.size = background->box.size;
	}
};

struct AudioOutPort : SVGPort {
	AudioOutPort() {
		background->svg = SVG::load(assetPlugin(plugin, "res/AudioOutPort.svg"));
		background->wrap();
		box.size = background->box.size;
	}
};

struct VcInPort : SVGPort {
	VcInPort() {
		background->svg = SVG::load(assetPlugin(plugin, "res/VcInPort.svg"));
		background->wrap();
		box.size = background->box.size;
	}
};

struct VcOutPort : SVGPort {
	VcOutPort() {
		background->svg = SVG::load(assetPlugin(plugin, "res/VcOutPort.svg"));
		background->wrap();
		box.size = background->box.size;
	}
};


