#include "VCV_Csound.hpp"
#include "dsp/digital.hpp"				//for SchmittTrigger
#include <csound/csound.hpp>
#include <iostream>

using namespace std;


struct Reverb : Module {
	enum ParamIds {
	FEEDBACK_PARAM,
	CUTOFF_PARAM,
	BYPASS_PARAM,
	NUM_PARAMS
	};
	enum InputIds {
	IN1_INPUT,
	IN2_INPUT,
	FEEDBACK_INPUT,
	CUTOFF_INPUT,
	NUM_INPUTS
	};
	enum OutputIds {
	OUT1_OUTPUT,
	OUT2_OUTPUT,
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
	int const nchnls = 2;       // 2 inputs and 2 outputs in csd

	bool bypass = false;
	bool notReady;

	float feedback, cutoff; 

	SchmittTrigger buttonTrigger;

	static void messageCallback(CSOUND* cs, int attr, const char *format, va_list valist) {
		//vprintf(format, valist);    //if commented -> disable csound message on terminal
		return;
	}

	void csoundCession() {
		//csd sampling-rate override
		string sr_override = "--sample-rate=" + to_string(engineGetSampleRate());

		//compile instance of csound
		notReady = csound->Compile(assetPlugin(plugin, "csd/Reverb.csd").c_str(), sr_override.c_str());
 		if(!notReady)
 		{
 			spout = csound->GetSpout();										//access csound output buffer
 			spin  = csound->GetSpin();										//access csound input buffer
 			ksmps = csound->GetKsmps();
 		}
 		else
			cout << "Csound csd compilation error!" << endl;
	}

	Reverb() : Module(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS) {
		csound = new Csound();												//Create an instance of Csound
		csound->SetMessageCallback(messageCallback);
		csoundCession();
	}

	~Reverb()
	{
		csound->Stop();
		csound->Cleanup();
		delete csound;														//free Csound object
    }

	void step() override;
	void reset() override;
	void onSampleRateChange() override;
};

void Reverb::onSampleRateChange() {
	//csound restart with new sample rate
	notReady = true;
	csound->Reset();
	csoundCession();
};

void Reverb::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundCession();
}

void Reverb::step() {
	float out1=0.0, out2=0.0;

	if(notReady) return;            //outputs set to zero

	//bypass
	if(buttonTrigger.process(params[BYPASS_PARAM].value)) bypass = !bypass;
	lights[BYPASS_LIGHT].value = bypass?10.0:0.0;

	//Process
	float in1 = clamp(inputs[IN1_INPUT].value,-5.0f, 5.0f) * 0.2f;
	float in2 = clamp(inputs[IN2_INPUT].value,-5.0f, 5.0f) * 0.2f;

	if(!bypass) {
		if(nbSample == 0)   //param refresh at control rate
		{
			//params
			if(inputs[FEEDBACK_INPUT].active) {
				feedback = clamp(inputs[FEEDBACK_INPUT].value, 0.0f, 10.0f) * 0.1f;
			} else {
				feedback = params[FEEDBACK_PARAM].value;
			};

			if(inputs[CUTOFF_INPUT].active) {
				cutoff = clamp(inputs[CUTOFF_INPUT].value, 0.0f, 10.0f) * 0.1f;
			} else {
				cutoff = params[CUTOFF_PARAM].value;
			};

			csound->SetChannel("feedback", feedback);
			csound->SetChannel("cutoff", cutoff);

			result = csound->PerformKsmps();
		}

		if(!result)
		{
			spin[nbSample] = in1;
			out1 = spout[nbSample];
			nbSample++;
			spin[nbSample] = in2;
			out2 = spout[nbSample];
			nbSample++;
			if (nbSample == ksmps*nchnls)
				nbSample = 0;
		}
		outputs[OUT1_OUTPUT].value = out1*5.0;
		outputs[OUT2_OUTPUT].value = out2*5.0;
	} else {
		//bypass
		outputs[OUT1_OUTPUT].value = in1*5.0;;
		outputs[OUT2_OUTPUT].value = in2*5.0;;
	}
}

struct ReverbWidget : ModuleWidget {
	ReverbWidget(Reverb *module);
};

ReverbWidget::ReverbWidget(Reverb *module) : ModuleWidget(module) {
	setPanel(SVG::load(assetPlugin(plugin, "res/Reverb.svg")));

	addChild(Widget::create<ScrewSilver>(Vec(15, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(15, 365)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(ParamWidget::create<csKnob>(Vec(45, 119), module, Reverb::FEEDBACK_PARAM, 0.0f, 1.0f, 0.8f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 179), module, Reverb::CUTOFF_PARAM, 0.0f, 1.0f, 0.6f));

	addParam(ParamWidget::create<LEDButton>(Vec(35, 246), module, Reverb::BYPASS_PARAM, 0.0f, 10.0f, 0.0f));
	addChild(ModuleLightWidget::create<MediumLight<RedLight>>(Vec(40,250), module, 0));

	addInput(Port::create<VcInPort>(Vec(10, 124), Port::INPUT, module, Reverb::FEEDBACK_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 184), Port::INPUT, module, Reverb::CUTOFF_INPUT));

	addInput(Port::create<AudioInPort>(Vec(10, 55), Port::INPUT, module, Reverb::IN1_INPUT));
	addInput(Port::create<AudioInPort>(Vec(54, 55), Port::INPUT, module, Reverb::IN2_INPUT));

	addOutput(Port::create<AudioOutPort>(Vec(10, 297), Port::OUTPUT, module, Reverb::OUT1_OUTPUT));
	addOutput(Port::create<AudioOutPort>(Vec(54, 297), Port::OUTPUT, module, Reverb::OUT2_OUTPUT));
}

Model *modelReverb = Model::create<Reverb, ReverbWidget>("VCV_Csound", "Reverb", "Stereo Reverb", REVERB_TAG);

