#pragma once

#include "VCV_Csound.hpp"
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
		notReady = csound->Compile(asset::plugin(pluginInstance, "csd/Reverb.csd").c_str()); /*,sr_override.c_str()*/
 		if(!notReady)
 		{
			nbSample = 0;
 			spout = csound->GetSpout();	//access csound output buffer
 			spin  = csound->GetSpin();  //access csound input buffer
 			ksmps = csound->GetKsmps();
 		}
 		else
			cout << "Csound csd compilation error!" << endl;
	}

	Reverb() {
		config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
		configParam(FEEDBACK_PARAM, 0.0f, 1.0f, 0.8f);
		configParam(CUTOFF_PARAM, 0.0f, 1.0f, 0.6f);
		configParam(BYPASS_PARAM, 0.0f, 10.0f, 0.0f);
	}

	~Reverb() {
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

void Reverb::onAdd() {
	notReady = true;
	if (csound) {
		dispose();
	}
	csound = new Csound(); //Create an instance of Csound
	csound->SetMessageCallback(messageCallback);	
	csoundSession();
}

void Reverb::onRemove() {
	dispose();
}

void Reverb::onSampleRateChange() {
	//csound restart with new sample rate
	reset();
};

void Reverb::onReset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	reset();
}

void Reverb::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundSession();
}

void Reverb::dispose() {
	notReady = true;
	if (csound) {
		csound = NULL;
		spin = NULL;
		spout = NULL;
	}
}

void Reverb::process(const ProcessArgs& args) {
	
	MYFLT out1=0.0, out2=0.0;

	if(notReady) return;            //outputs set to zero

	//bypass
	if(buttonTrigger.process(params[BYPASS_PARAM].getValue())) bypass = !bypass;
	lights[BYPASS_LIGHT].value = bypass?10.0:0.0;

	//Process
	MYFLT in1 = clamp(inputs[IN1_INPUT].getVoltage(),-5.0f, 5.0f) * 0.2f;
	MYFLT in2 = clamp(inputs[IN2_INPUT].getVoltage(),-5.0f, 5.0f) * 0.2f;

	if (!bypass && spin && spout) {
		if(nbSample == 0)   //param refresh at control rate
		{
			//params
			if(inputs[FEEDBACK_INPUT].isConnected()) {
				feedback = clamp(inputs[FEEDBACK_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
			} else {
				feedback = params[FEEDBACK_PARAM].getValue();
			};

			if(inputs[CUTOFF_INPUT].isConnected()) {
				cutoff = clamp(inputs[CUTOFF_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
			} else {
				cutoff = params[CUTOFF_PARAM].getValue();
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
			if (nbSample == ksmps*nchnls) {
				nbSample = 0;
			}
		}
		outputs[OUT1_OUTPUT].setVoltage(out1*5.0);
		outputs[OUT2_OUTPUT].setVoltage(out2*5.0);
	} else {
		//bypass
		outputs[OUT1_OUTPUT].setVoltage(in1*5.0);;
		outputs[OUT2_OUTPUT].setVoltage(in2*5.0);;
	}
}

struct ReverbWidget : ModuleWidget {
	ReverbWidget(Reverb *module);
};

ReverbWidget::ReverbWidget(Reverb *module) {
	setModule(module);
	setPanel(APP->window->loadSvg(asset::plugin(pluginInstance, "res/Reverb.svg")));
	
	addChild(createWidget<ScrewSilver>(Vec(15, 0)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(createWidget<ScrewSilver>(Vec(15, 365)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(createParam<csKnob>(Vec(45, 119), module, Reverb::FEEDBACK_PARAM));
	addParam(createParam<csKnob>(Vec(45, 179), module, Reverb::CUTOFF_PARAM));
	addParam(createParam<LEDButton>(Vec(35, 246), module, Reverb::BYPASS_PARAM));
	
	addChild(createLight<MediumLight<RedLight>>(Vec(40,250), module, 0));

	addInput(createInput<VcInPort>(Vec(10, 124), module, Reverb::FEEDBACK_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 184), module, Reverb::CUTOFF_INPUT));

	addInput(createInput<AudioInPort>(Vec(10, 55), module, Reverb::IN1_INPUT));
	addInput(createInput<AudioInPort>(Vec(54, 55), module, Reverb::IN2_INPUT));

	addOutput(createOutput<AudioOutPort>(Vec(10, 297), module, Reverb::OUT1_OUTPUT));
	addOutput(createOutput<AudioOutPort>(Vec(54, 297), module, Reverb::OUT2_OUTPUT));
}

Model *modelReverb = createModel<Reverb, ReverbWidget>("Csound_Reverb");