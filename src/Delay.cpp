#pragma once

#include "VCV_Csound.hpp"
#include <csound/csound.hpp>
#include <iostream>

using namespace std;


struct Delay : Module {
	enum ParamIds {
		TIMELEFT_PARAM,
		TIMERIGHT_PARAM,
		TIMEFINELEFT_PARAM,
		TIMEFINERIGHT_PARAM,
		CUTOFF_PARAM,
		FEEDBACK_PARAM,
		CROSS_PARAM,
		WET_PARAM,
		NUM_PARAMS
	};
	enum InputIds {
		IN1_INPUT,
		IN2_INPUT,
		TIMELEFT_INPUT,
		TIMERIGHT_INPUT,
		TIMEFINELEFT_INPUT,
		TIMEFINERIGHT_INPUT,
		CUTOFF_INPUT,
		FEEDBACK_INPUT,
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

	float timeleft, timeright, timefineleft, timefineright, cutoff, feedback, cross, wet;

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
		notReady = csound->Compile(asset::plugin(pluginInstance, "csd/Delay.csd").c_str(), sr_override.c_str());
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

	Delay() {
		config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS);
		configParam(TIMELEFT_PARAM, 0.0f, 600.0f, 300.0f);
		configParam(TIMERIGHT_PARAM, 0.0f, 600.0f, 600.0f);
		configParam(TIMEFINELEFT_PARAM, 0.0f, 5.0f, 1.5f);
		configParam(TIMEFINERIGHT_PARAM, 0.0f, 5.0f, 3.0f);
		configParam(CUTOFF_PARAM, 0.0f, 1.0f, 0.4f);
		configParam(FEEDBACK_PARAM, 0.0f, 1.0f, 0.24f);
		configParam(CROSS_PARAM, 0.0f, 1.0f, 0.23f);
		configParam(WET_PARAM, 0.0f, 1.0f, 0.19f);
	}

	~Delay() {
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

void Delay::onAdd() {
	notReady = true;
	if (csound) {
		dispose();
	}
	csound = new Csound(); //Create an instance of Csound
	csound->SetMessageCallback(messageCallback);	
	csoundSession();
}

void Delay::onRemove() {
	dispose();
}

void Delay::onSampleRateChange() {
	//csound restart with new sample rate
	reset();
};

void Delay::onReset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	reset();
}

void Delay::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundSession();
}

void Delay::dispose() {
	notReady = true;
	if (csound) {
		csound = NULL;
		spin = NULL;
		spout = NULL;
	}
}

void Delay::process(const ProcessArgs& args) {
	
	float out1=0.0, out2=0.0;

	if(notReady) return;            //outputs set to zero

	//Process
	MYFLT in1 = clamp(inputs[IN1_INPUT].getVoltage(),-5.0f, 5.0f) * 0.2f;
	MYFLT in2 = clamp(inputs[IN2_INPUT].getVoltage(),-5.0f, 5.0f) * 0.2f;

	if (spin && spout) {
		if(nbSample == 0)   //param refresh at control rate
		{
			//params
			if(inputs[TIMELEFT_INPUT].isConnected()) {
				timeleft = clamp(inputs[TIMELEFT_INPUT].getVoltage(), 0.0f, 10.0f) * 60.0f;
			} else {
				timeleft = params[TIMELEFT_PARAM].getValue();
			};
			if(inputs[TIMERIGHT_INPUT].isConnected()) {
				timeright = clamp(inputs[TIMERIGHT_INPUT].getVoltage(), 0.0f, 10.0f) * 60.0f;
			} else {
				timeright = params[TIMERIGHT_PARAM].getValue();
			};
			if(inputs[TIMEFINELEFT_INPUT].isConnected()) {
				timefineleft = clamp(inputs[TIMEFINELEFT_INPUT].getVoltage(), 0.0f, 10.0f) * 0.5f;
			} else {
				timefineleft = params[TIMEFINELEFT_PARAM].getValue();
			};
			if(inputs[TIMEFINERIGHT_INPUT].isConnected()) {
				timefineright = clamp(inputs[TIMEFINERIGHT_INPUT].getVoltage(), 0.0f, 10.0f) * 0.5f;
			} else {
				timefineright = params[TIMEFINERIGHT_PARAM].getValue();
			};
			if(inputs[CUTOFF_INPUT].isConnected()) {
				cutoff = clamp(inputs[CUTOFF_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
			} else {
				cutoff = params[CUTOFF_PARAM].getValue();
			};
			if(inputs[FEEDBACK_INPUT].isConnected()) {
				feedback = clamp(inputs[FEEDBACK_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
			} else {
				feedback = params[FEEDBACK_PARAM].getValue();
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

			csound->SetChannel("Time_L",    timeleft);
			csound->SetChannel("Time_R",    timeright);
			csound->SetChannel("Fine_L",    timefineleft);
			csound->SetChannel("Fine_R",    timefineright);
			csound->SetChannel("Cutoff",    cutoff);
			csound->SetChannel("Feedback",  feedback);
			csound->SetChannel("Cross",     cross);
			csound->SetChannel("Wet",       wet);

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

struct DelayWidget : ModuleWidget {
	DelayWidget(Delay *module);
};

DelayWidget::DelayWidget(Delay *module) {
	setModule(module);
	setPanel(APP->window->loadSvg(asset::plugin(pluginInstance, "res/Delay.svg")));

	addChild(createWidget<ScrewSilver>(Vec(15, 0)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(createWidget<ScrewSilver>(Vec(15, 365)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(createParam<csKnob>(Vec(45, 59), module, Delay::TIMELEFT_PARAM));
	addParam(createParam<csKnob>(Vec(135, 59), module, Delay::TIMERIGHT_PARAM));
	addParam(createParam<csKnob>(Vec(45, 119), module, Delay::TIMEFINELEFT_PARAM));
	addParam(createParam<csKnob>(Vec(135, 119), module, Delay::TIMEFINERIGHT_PARAM));
	addParam(createParam<csKnob>(Vec(45, 179), module, Delay::CUTOFF_PARAM));
	addParam(createParam<csKnob>(Vec(135, 179), module, Delay::FEEDBACK_PARAM));
	addParam(createParam<csKnob>(Vec(45, 239), module, Delay::CROSS_PARAM));
	addParam(createParam<csKnob>(Vec(135, 239), module, Delay::WET_PARAM));

	addInput(createInput<VcInPort>(Vec(10, 64), module, Delay::TIMELEFT_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 64), module, Delay::TIMERIGHT_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 124), module, Delay::TIMEFINELEFT_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 124), module, Delay::TIMEFINERIGHT_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 184), module, Delay::CUTOFF_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 184), module, Delay::FEEDBACK_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 244), module, Delay::CROSS_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 244), module, Delay::WET_INPUT));

	addInput(createInput<AudioInPort>(Vec(10, 297), module, Delay::IN1_INPUT));
	addInput(createInput<AudioInPort>(Vec(52, 297), module, Delay::IN2_INPUT));

	addOutput(createOutput<AudioOutPort>(Vec(101, 297), module, Delay::OUT1_OUTPUT));
	addOutput(createOutput<AudioOutPort>(Vec(145, 297), module, Delay::OUT2_OUTPUT));
}

Model *modelDelay = createModel<Delay, DelayWidget>("Csound_Delay");