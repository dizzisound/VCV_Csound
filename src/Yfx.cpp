#include "VCV_Csound.hpp"
#include "dsp/digital.hpp"          //for SchmittTrigger
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

	string formula;

	SchmittTrigger buttonTrigger;

	static void messageCallback(CSOUND* cs, int attr, const char *format, va_list valist) {
		//vprintf(format, valist);    //if commented -> disable csound message on terminal
		return;
	}

	void csoundCession() {
		//csd sampling-rate override
		string sr_override = "--sample-rate=" + to_string(engineGetSampleRate());

		//compile instance of csound
		notReady = csound->Compile(assetPlugin(plugin, "csd/Yfx.csd").c_str(), sr_override.c_str());
		if(!notReady)
		{
			spout = csound->GetSpout();								//access csound output buffer
			spin  = csound->GetSpin();								//access csound input buffer
			ksmps = csound->GetKsmps();
		}
		else
			cout << "Csound csd compilation error!" << endl;
	}

	Yfx() : Module(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS) {
		csound = new Csound();										//Create an instance of Csound
		csound->SetMessageCallback(messageCallback);
		csoundCession();
	}

	~Yfx()
	{
		csound->Stop();
		csound->Cleanup();
		delete csound;												//free Csound object
	}

	void step() override;
	void reset() override;
	void onSampleRateChange() override;
};

void Yfx::onSampleRateChange() {
	//csound restart with new sample rate
	notReady = true;
	csound->Reset();
	csoundCession();
};

void Yfx::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundCession();
}

void Yfx::step() {
	float out=0.0;

	if(notReady) return;						//outputs set to zero

	//bypass
	if(buttonTrigger.process(params[BYPASS_PARAM].value)) bypass = !bypass;
	lights[BYPASS_LIGHT].value = bypass?10.0:0.0;

	//Process
	float in = clamp(inputs[IN_INPUT].value,-10.0f,10.0f);

	if(!bypass) {
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
		outputs[OUT_OUTPUT].value = out*4.0;
	} else {
		//bypass
		outputs[OUT_OUTPUT].value = in;
	}
}

struct YfxDisplay : TransparentWidget {
	Yfx *module;
	shared_ptr<Font> font;

	YfxDisplay() {
		font = Font::load(assetGlobal("res/fonts/DejaVuSans.ttf"));
	}

	void draw(NVGcontext *vg) override {
		nvgFontSize(vg, 10);
		nvgFontFaceId(vg, font->handle);
		nvgTextLetterSpacing(vg, 1);
		nvgFillColor(vg, nvgRGBA(0xff, 0xff, 0x3e, 0xff));					//textColor
		nvgTextBox(vg, 10, 120, 70, module->formula.c_str(), NULL);			//text
		nvgStroke(vg);
	}
};

struct YfxWidget : ModuleWidget {
	YfxWidget(Yfx *module);
};

YfxWidget::YfxWidget(Yfx *module) : ModuleWidget(module) {
	setPanel(SVG::load(assetPlugin(plugin, "res/Yfx.svg")));

	{
		YfxDisplay *display = new YfxDisplay();
		display->module = module;
		addChild(display);
	}

	addChild(Widget::create<ScrewSilver>(Vec(15, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(15, 365)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(ParamWidget::create<LEDButton>(Vec(35, 246), module, Yfx::BYPASS_PARAM, 0.0f, 10.0f, 0.0f));
	addChild(ModuleLightWidget::create<MediumLight<RedLight>>(Vec(40,250), module, 0));

	addInput(Port::create<AudioInPort>(Vec(10, 297), Port::INPUT, module, Yfx::IN_INPUT));
	addOutput(Port::create<AudioOutPort>(Vec(54, 297), Port::OUTPUT, module, Yfx::OUT_OUTPUT));
}

Model *modelYfx = Model::create<Yfx, YfxWidget>("VCV_Csound", "Yfx", "Y = F(x)", UTILITY_TAG);

