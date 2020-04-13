#pragma once

#include "VCV_Csound.hpp"
#include <csound/csound.hpp>
#include <iostream>

using namespace std;


struct Chorus : Module {
	enum ParamIds {
		DELAYLEFT_PARAM,
		DELAYRIGHT_PARAM,
		DEPTHLEFT_PARAM,
		DEPTHRIGHT_PARAM,
		RATELEFT_PARAM,
		RATERIGHT_PARAM,
		CROSS_PARAM,
		WET_PARAM,
		NUM_PARAMS
	};
	enum InputIds {
		IN1_INPUT,
		IN2_INPUT,
		DELAYLEFT_INPUT,
		DELAYRIGHT_INPUT,
		DEPTHLEFT_INPUT,
		DEPTHRIGHT_INPUT,
		RATELEFT_INPUT,
		RATERIGHT_INPUT,
		CROSS_INPUT,
		WET_INPUT,
		NUM_INPUTS
	};
	enum OutputIds {
		OUT1_OUTPUT,
		OUT2_OUTPUT,
		NUM_OUTPUTS
	};

	Csound* csound;

	MYFLT *spin, *spout;

	int nbSample = 0;
	int ksmps, result;
	int const nchnls = 2;				// 2 inputs and 2 outputs in csd

	bool notReady;

	float delayleft, delayright, depthleft, depthright, rateleft, rateright, cross, wet;

	static void messageCallback(CSOUND* cs, int attr, const char *format, va_list valist) {
		vprintf(format, valist);			//if commented -> disable csound message on terminal
		return;
	}

	void csoundSession() {
		//csd sampling-rate override
		std::string sr_override = "--sample-rate=" + to_string(APP->engine->getSampleRate());
		//compile instance of csound
		csound->SetOption((char*)"-n");
		csound->SetOption((char*)"-d");
		csound->SetHostImplementedAudioIO(1, 0);
		notReady = csound->Compile(asset::plugin(pluginInstance, "csd/Chorus.csd").c_str()); /*,sr_override.c_str()*/
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

	Chorus() {
		config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS);
		configParam(DELAYLEFT_PARAM, 0.5f, 20.0f, 4.95f);
		configParam(DELAYRIGHT_PARAM, 0.5f, 20.0f, 5.57f);
		configParam(DEPTHLEFT_PARAM, 0.0f, 0.99f, 0.53f);
		configParam(DEPTHRIGHT_PARAM, 0.0f, 0.99f, 0.69f);
		configParam(RATELEFT_PARAM, 0.0f, 1.0f, 0.43f);
		configParam(RATERIGHT_PARAM, 0.0f, 1.0f, 0.43f);
		configParam(CROSS_PARAM, 0.0f, 1.0f, 0.0f);
		configParam(WET_PARAM, 0.0f, 1.0f, 1.0f);
	}

	~Chorus() {
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

void Chorus::onAdd() {
	notReady = true;
	if (csound) {
		dispose();
	}
	csound = new Csound(); //Create an instance of Csound
	csound->SetMessageCallback(messageCallback);	
	csoundSession();
}

void Chorus::onRemove() {
	dispose();
}

void Chorus::onSampleRateChange() {
	//csound restart with new sample rate
	reset();
};

void Chorus::onReset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	reset();
}

void Chorus::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundSession();
}

void Chorus::dispose() {
	notReady = true;
	if (csound) {
		csound = NULL;
		spin = NULL;
		spout = NULL;
	}
}

void Chorus::process(const ProcessArgs& args) {
	
	MYFLT out1=0.0, out2=0.0;

	if(notReady) return;            //outputs set to zero

	//Process
	MYFLT in1 = clamp(inputs[IN1_INPUT].getVoltage(),-5.0f, 5.0f) * 0.2f;
	MYFLT in2 = clamp(inputs[IN2_INPUT].getVoltage(),-5.0f, 5.0f) * 0.2f;

	if (spin && spout) {
		if(nbSample == 0)   //param refresh at control rate
		{
			//params
			if(inputs[DELAYLEFT_INPUT].isConnected()) {
				delayleft = clamp(inputs[DELAYLEFT_INPUT].getVoltage(), 0.0f, 10.0f) * 1.95f + 0.5f;
			} else {
				delayleft = params[DELAYLEFT_PARAM].getValue();
			};
			if(inputs[DELAYRIGHT_INPUT].isConnected()) {
				delayright = clamp(inputs[DELAYRIGHT_INPUT].getVoltage(), 0.0f, 10.0f) * 1.95f + 0.5f;
			} else {
				delayright = params[DELAYRIGHT_PARAM].getValue();
			};
			if(inputs[DEPTHLEFT_INPUT].isConnected()) {
				depthleft = clamp(inputs[DEPTHLEFT_INPUT].getVoltage(), 0.0f, 10.0f) * 0.099f;
			} else {
				depthleft = params[DEPTHLEFT_PARAM].getValue();
			};
			if(inputs[DEPTHRIGHT_INPUT].isConnected()) {
				depthright = clamp(inputs[DEPTHRIGHT_INPUT].getVoltage(), 0.0f, 10.0f) * 0.099f;
			} else {
				depthright = params[DEPTHRIGHT_PARAM].getValue();
			};
			if(inputs[RATELEFT_INPUT].isConnected()) {
				rateleft = clamp(inputs[RATELEFT_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
			} else {
				rateleft = params[RATELEFT_PARAM].getValue();
			};
			if(inputs[RATERIGHT_INPUT].isConnected()) {
				rateright = clamp(inputs[RATERIGHT_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
			} else {
				rateright = params[RATERIGHT_PARAM].getValue();
			};
			if(inputs[CROSS_INPUT].isConnected()) {
				cross = clamp(inputs[CROSS_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
			} else {
				cross = params[CROSS_PARAM].getValue();
			};
			if(inputs[WET_INPUT].isConnected()) {
				wet = clamp(inputs[WET_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
			} else {
				wet = params[WET_PARAM].getValue();
			};

			csound->SetChannel("Delay_L",    delayleft);
			csound->SetChannel("Delay_R",    delayright);
			csound->SetChannel("Depth_L",    depthleft);
			csound->SetChannel("Depth_R",    depthright);
			csound->SetChannel("Rate_L",     rateleft);
			csound->SetChannel("Rate_R",     rateright);
			csound->SetChannel("Cross",      cross);
			csound->SetChannel("Wet",        wet);

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
		outputs[OUT1_OUTPUT].setVoltage(out1*5.0);
		outputs[OUT2_OUTPUT].setVoltage(out2*5.0);
	}
}

struct ChorusWidget : ModuleWidget {
	ChorusWidget(Chorus *module);
};

ChorusWidget::ChorusWidget(Chorus *module) {
	setModule(module);
	setPanel(APP->window->loadSvg(asset::plugin(pluginInstance, "res/Chorus.svg")));

	addChild(createWidget<ScrewSilver>(Vec(15, 0)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(createWidget<ScrewSilver>(Vec(15, 365)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(createParam<csKnob>(Vec(45, 59), module, Chorus::DELAYLEFT_PARAM));
	addParam(createParam<csKnob>(Vec(135, 59), module, Chorus::DELAYRIGHT_PARAM));
	addParam(createParam<csKnob>(Vec(45, 119), module, Chorus::DEPTHLEFT_PARAM));
	addParam(createParam<csKnob>(Vec(135, 119), module, Chorus::DEPTHRIGHT_PARAM));
	addParam(createParam<csKnob>(Vec(45, 179), module, Chorus::RATELEFT_PARAM));
	addParam(createParam<csKnob>(Vec(135, 179), module, Chorus::RATERIGHT_PARAM));
	addParam(createParam<csKnob>(Vec(45, 239), module, Chorus::CROSS_PARAM));
	addParam(createParam<csKnob>(Vec(135, 239), module, Chorus::WET_PARAM));

	addInput(createInput<VcInPort>(Vec(10, 64), module, Chorus::DELAYLEFT_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 64), module, Chorus::DELAYRIGHT_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 124), module, Chorus::DEPTHLEFT_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 124), module, Chorus::DEPTHRIGHT_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 184), module, Chorus::RATELEFT_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 184), module, Chorus::RATERIGHT_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 244), module, Chorus::CROSS_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 244), module, Chorus::WET_INPUT));

	addInput(createInput<AudioInPort>(Vec(10, 297), module, Chorus::IN1_INPUT));
	addInput(createInput<AudioInPort>(Vec(52, 297), module, Chorus::IN2_INPUT));

	addOutput(createOutput<AudioOutPort>(Vec(101, 297), module, Chorus::OUT1_OUTPUT));
	addOutput(createOutput<AudioOutPort>(Vec(145, 297), module, Chorus::OUT2_OUTPUT));
}

Model *modelChorus = createModel<Chorus, ChorusWidget>("Csound_Chorus");