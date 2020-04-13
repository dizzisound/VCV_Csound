#pragma once

#include "rack.hpp"

#if defined _WIN32 || defined __CYGWIN__
	#ifdef __GNUC__
		#define DLL_EXPORT __attribute__ ((dllexport))
	#else
		#define DLL_EXPORT __declspec(dllexport)
	#endif
#endif

using namespace rack;

extern Plugin *pluginInstance;

extern Model *modelReverb;
extern Model *modelChorus;
extern Model *modelVocoder;
extern Model *modelMidiVCO10;
extern Model *modelVCO10;
extern Model *modelFlooper;
extern Model *modelYfx;
extern Model *modelDelay;

#if defined _WIN32 || defined CYGWIN
	DLL_EXPORT void init(rack::Plugin *p);
#else //for linux
	void init(rack::Plugin *p);
#endif

struct csKnob : RoundKnob {
	csKnob() : RoundKnob()
	{
		setSVG(APP->window->loadSvg(asset::plugin(pluginInstance,"res/Knob.svg")));
	}
};

struct csBefacoSwitch : SVGSwitch /*, ToggleSwitch*/ {
	csBefacoSwitch() {
		addFrame(APP->window->loadSvg(asset::plugin(pluginInstance, "res/csBefacoSwitch_0.svg")));
		addFrame(APP->window->loadSvg(asset::plugin(pluginInstance, "res/csBefacoSwitch_1.svg")));
		addFrame(APP->window->loadSvg(asset::plugin(pluginInstance, "res/csBefacoSwitch_2.svg")));
	}
};

struct AudioInPort : SVGPort {
	AudioInPort() {
		/*background->svg = APP->window->loadSvg(asset::plugin(pluginInstance, "res/AudioInPort.svg"));
		background->wrap();
		box.size = background->box.size;*/
		setSvg(APP->window->loadSvg(asset::plugin(pluginInstance, "res/AudioInPort.svg")));
	}
};

struct AudioOutPort : SVGPort {
	AudioOutPort() {
		/*background->svg = APP->window->loadSvg(asset::plugin(pluginInstance, "res/AudioOutPort.svg"));
		background->wrap();
		box.size = background->box.size;*/
		setSvg(APP->window->loadSvg(asset::plugin(pluginInstance, "res/AudioOutPort.svg")));
	}
};

struct VcInPort : SVGPort {
	VcInPort() {
		/*background->svg = APP->window->loadSvg(asset::plugin(pluginInstance, "res/VcInPort.svg"));
		background->wrap();
		box.size = background->box.size;*/
		setSvg(APP->window->loadSvg(asset::plugin(pluginInstance, "res/VcInPort.svg")));
	}
};

struct VcOutPort : SVGPort {
	VcOutPort() {
		/*background->svg = APP->window->loadSvg(asset::plugin(pluginInstance, "res/VcOutPort.svg"));
		background->wrap();
		box.size = background->box.size;*/
		setSvg(APP->window->loadSvg(asset::plugin(pluginInstance, "res/VcOutPort.svg")));
	}
};
