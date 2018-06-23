#include "rack.hpp"

using namespace rack;

extern Plugin *plugin;

extern Model *modelReverb;
extern Model *modelVocoder;
extern Model *modelMidiVCO10;
extern Model *modelVCO10;
extern Model *modelFlooper;
extern Model *modelYfx;


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


