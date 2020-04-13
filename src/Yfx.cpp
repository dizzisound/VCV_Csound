#pragma once

#include "VCV_Csound.hpp"
#include <csound/csound.hpp>
#include <iostream>

using namespace std;


struct Yfx : Module {
	enum ParamIds {
		BYPASS_PARAM,
		NUM_PARAMS
	};
	enum InputIds {
		IN_INPUT,
		NUM_INPUTS
	};
	enum OutputIds {
		OUT_OUTPUT,
		NUM_OUTPUTS
	};
	enum LightIds {
		BYPASS_LIGHT,
		NUM_LIGHTS
	};

	Csound* csound;

	MYFLT *spin, *spout;

	int nbSample = 0;
	int ksmps, result;
	//int const nchnls = 1;       // 1 input and 1 output in csd

	bool bypass = false;
	bool notReady;

	std::string formula;

	dsp::SchmittTrigger buttonTrigger;

	static void messageCallback(CSOUND* cs, int attr, const char *format, va_list valist) {
		vprintf(format, valist);    //if commented -> disable csound message on terminal
		return;
	}

	void csoundSession() {
		//csd sampling-rate override
		std::string sr_override = "--sample-rate=" + to_string(APP->engine->getSampleRate());
		//compile instance of csound
		csound->SetOption((char*)"-n");
		csound->SetOption((char*)"-d");
		csound->SetHostImplementedAudioIO(1, 0);
		notReady = csound->Compile(asset::plugin(pluginInstance, "csd/Yfx.csd").c_str(), sr_override.c_str());
		if(!notReady)
		{
			nbSample = 0;
			spout = csound->GetSpout();								//access csound output buffer
			spin  = csound->GetSpin();								//access csound input buffer
			ksmps = csound->GetKsmps();
		}
		else
			cout << "Csound csd compilation error!" << endl;
	}

	Yfx() {
		config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
		configParam(BYPASS_PARAM, 0.0f, 10.0f, 0.0f);
	}

	~Yfx() {
		notReady = true;
		if (csound) {
			dispose();
		}
	}

	void process(const ProcessArgs& args) override;
	void onAdd() override;
	void onRemove() override;
	void onSampleRateChange() override;
	void onReset() override;
	void reset();
	void dispose();
};

void Yfx::onAdd() {
	notReady = true;
	if (csound) {
		dispose();
	}
	csound = new Csound(); //Create an instance of Csound
	csound->SetMessageCallback(messageCallback);	
	csoundSession();
}

void Yfx::onRemove() {
	dispose();
}

void Yfx::onSampleRateChange() {
	//csound restart with new sample rate
	reset();
};

void Yfx::onReset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	reset();
}

void Yfx::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundSession();
}

void Yfx::dispose() {
	notReady = true;
	if (csound) {
		csound = NULL;
		spin = NULL;
		spout = NULL;
	}
}

void Yfx::process(const ProcessArgs& args) {
	
	MYFLT out=0.0;

	if(notReady) return;						//outputs set to zero

	//bypass
	if(buttonTrigger.process(params[BYPASS_PARAM].getValue())) bypass = !bypass;
	lights[BYPASS_LIGHT].value = bypass?10.0:0.0;

	//Process
	MYFLT in = clamp(inputs[IN_INPUT].getVoltage(),-5.0f, 5.0f) * 0.2f;

	if(!bypass && spin && spout) {
		if(nbSample == 0)						//param refresh at control rate
		{
			csound->GetStringChannel("Formula", (char *) formula.c_str());
			result = csound->PerformKsmps();
		}

		if(!result)
		{
			spin[nbSample] = in;
			out = spout[nbSample];
			nbSample++;
			if (nbSample == ksmps)			//nchnls = 1
				nbSample = 0;
		}
		outputs[OUT_OUTPUT].setVoltage(out*5.0f);
	} else {
		//bypass
		outputs[OUT_OUTPUT].setVoltage(in*5.0f);
	}
}

struct YfxDisplay : TransparentWidget {
	Yfx *module;
	shared_ptr<Font> font;

	YfxDisplay() {
		font = APP->window->loadFont(asset::system("res/fonts/DejaVuSans.ttf"));
	}

	void draw(const DrawArgs& args) override {
		if (module!=NULL) {
			nvgFontSize(args.vg, 10);
			nvgFontFaceId(args.vg, font->handle);
			nvgTextLetterSpacing(args.vg, 1);
			nvgFillColor(args.vg, nvgRGBA(0xff, 0xff, 0x3e, 0xff));					//textColor
			nvgTextBox(args.vg, 10, 120, 70, module->formula.c_str(), NULL);			//text
			nvgStroke(args.vg);
		}
	}
};

struct YfxWidget : ModuleWidget {
	YfxWidget(Yfx *module);
};

YfxWidget::YfxWidget(Yfx *module) {
	setModule(module);
	setPanel(APP->window->loadSvg(asset::plugin(pluginInstance, "res/Yfx.svg")));

	{
		YfxDisplay *display = new YfxDisplay();
		display->module = module;
		addChild(display);
	}

	addChild(createWidget<ScrewSilver>(Vec(15, 0)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(createWidget<ScrewSilver>(Vec(15, 365)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(createParam<LEDButton>(Vec(35, 246), module, Yfx::BYPASS_PARAM));
	
	addChild(createLight<MediumLight<RedLight>>(Vec(40,250), module, 0));

	addInput(createInput<AudioInPort>(Vec(10, 297), module, Yfx::IN_INPUT));
	
	addOutput(createOutput<AudioOutPort>(Vec(54, 297), module, Yfx::OUT_OUTPUT));
}

Model *modelYfx = createModel<Yfx, YfxWidget>("Csound_Yfx");