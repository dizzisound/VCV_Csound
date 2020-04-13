#pragma once

#include "VCV_Csound.hpp"
#include <csound/csound.hpp>
#include <iostream>

using namespace std;


struct Vocoder : Module {
	enum ParamIds {
		BANDWIDTH_PARAM,
		BANDSPACING_PARAM,
		BASE_PARAM,
		CARFILTER_PARAM,
		BPF_PARAM,
		HPF_PARAM,
		GATE_PARAM,
		STEPNESS_PARAM,
		NUM_PARAMS
	};
	enum InputIds {
		MOD_INPUT,
		CAR_INPUT,
		BANDWIDTH_INPUT,
		BANDSPACING_INPUT,
		BASE_INPUT,
		NUM_INPUTS
	};
	enum OutputIds {
		OUT_OUTPUT,
		NUM_OUTPUTS
	};

	Csound* csound;

	MYFLT *spin, *spout;

	int nbSample = 0;
	int ksmps, result;
	int const nchnls = 2;				// 2 inputs and 2 outputs in csd

	bool notReady;

	float bandwidth, bandspacing, base, bpGain, hpGain, carFilter, steepness, gate;

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
		notReady = csound->Compile(asset::plugin(pluginInstance, "csd/Vocoder.csd").c_str(), sr_override.c_str());
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

	Vocoder() {
		config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS);
		configParam(BANDWIDTH_PARAM, 0.0f, 1.0f, 0.5f);
		configParam(BANDSPACING_PARAM, 0.0f, 1.0f, 0.648f);
		configParam(BASE_PARAM, 24.0f, 80.0f, 40.0f);
		configParam(BPF_PARAM, 0.0f, 1.0f, 0.945f);
		configParam(HPF_PARAM, 0.0f, 1.0f, 0.849f);
		configParam(STEPNESS_PARAM, 0.0f, 1.0f, 1.0f);
		configParam(CARFILTER_PARAM, 0.0f, 1.0f, 0.0f);
		configParam(GATE_PARAM, 0.0f, 1.0f, 0.0f);
	}

	~Vocoder() {
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

void Vocoder::onAdd() {
	notReady = true;
	if (csound) {
		dispose();
	}
	csound = new Csound(); //Create an instance of Csound
	csound->SetMessageCallback(messageCallback);	
	csoundSession();
}

void Vocoder::onRemove() {
	dispose();
}

void Vocoder::onSampleRateChange() {
	//csound restart with new sample rate
	reset();
};

void Vocoder::onReset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	reset();
}

void Vocoder::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundSession();
}

void Vocoder::dispose() {
	notReady = true;
	if (csound) {
		csound = NULL;
		spin = NULL;
		spout = NULL;
	}
}

void Vocoder::process(const ProcessArgs& args) {
	
	MYFLT out=0.0;

	if(notReady) return;            //outputs set to zero

	//Process
	MYFLT in1 = clamp(inputs[MOD_INPUT].getVoltage(),-5.0f, 5.0f) * 0.2f;
	MYFLT in2 = clamp(inputs[CAR_INPUT].getVoltage(),-5.0f, 5.0f) * 0.2f;

	if (spin && spout) {
		if(nbSample == 0)   //param refresh at control rate
		{
			//params
			if(inputs[BANDWIDTH_INPUT].isConnected()) {
				bandwidth = clamp(inputs[BANDWIDTH_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
			} else {
				bandwidth = params[BANDWIDTH_PARAM].getValue();
			};
			if(inputs[BANDSPACING_INPUT].isConnected()) {
				bandspacing = clamp(inputs[BANDSPACING_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
			} else {
				bandspacing = params[BANDSPACING_PARAM].getValue();
			};
			if(inputs[BASE_INPUT].isConnected()) {
				base = clamp(inputs[BASE_INPUT].getVoltage(), 0.0f, 10.0f) * 5.6f + 24.0f;
			} else {
				base = params[BASE_PARAM].getValue();
			};

			steepness   = params[STEPNESS_PARAM].getValue();
			bpGain      = params[BPF_PARAM].getValue();
			hpGain      = params[HPF_PARAM].getValue();
			carFilter   = params[CARFILTER_PARAM].getValue();
			gate        = params[GATE_PARAM].getValue();

			csound->SetChannel("bw", bandwidth);
			csound->SetChannel("incr", bandspacing);
			csound->SetChannel("base", base);
			csound->SetChannel("BPGain", bpGain);
			csound->SetChannel("HPGain", hpGain);
			csound->SetChannel("carFilter", carFilter);
			csound->SetChannel("steepness", steepness);
			csound->SetChannel("gate", gate);

			result = csound->PerformKsmps();
		}

		if(!result)
		{
			spin[nbSample] = in1;
			out = spout[nbSample];
			nbSample++;
			spin[nbSample] = in2;
			nbSample++;
			if (nbSample == ksmps*nchnls)
				nbSample = 0;
		}
		outputs[OUT_OUTPUT].setVoltage(out*5.0);
	}
}

struct VocoderWidget : ModuleWidget {
	VocoderWidget(Vocoder *module);
};

VocoderWidget::VocoderWidget(Vocoder *module) {
	setModule(module);
	setPanel(APP->window->loadSvg(asset::plugin(pluginInstance, "res/Vocoder.svg")));

	addChild(createWidget<ScrewSilver>(Vec(15, 0)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(createWidget<ScrewSilver>(Vec(15, 365)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(createParam<csKnob>(Vec(45, 59), module, Vocoder::BANDWIDTH_PARAM));
	addParam(createParam<csKnob>(Vec(135, 59), module, Vocoder::BANDSPACING_PARAM));
	addParam(createParam<csKnob>(Vec(45, 119), module, Vocoder::BASE_PARAM));
	addParam(createParam<csKnob>(Vec(45, 179), module, Vocoder::BPF_PARAM));
	addParam(createParam<csKnob>(Vec(135, 179), module, Vocoder::HPF_PARAM));
	addParam(createParam<csBefacoSwitch>(Vec(138, 120), module, Vocoder::STEPNESS_PARAM));
	addParam(createParam<csBefacoSwitch>(Vec(138, 241), module, Vocoder::CARFILTER_PARAM));
	addParam(createParam<csBefacoSwitch>(Vec(52, 241), module, Vocoder::GATE_PARAM));

	addInput(createInput<VcInPort>(Vec(10, 64), module, Vocoder::BANDWIDTH_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 64), module, Vocoder::BANDSPACING_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 124), module, Vocoder::BASE_INPUT));
	addInput(createInput<AudioInPort>(Vec(39, 297), module, Vocoder::MOD_INPUT));
	addInput(createInput<AudioInPort>(Vec(101, 297), module, Vocoder::CAR_INPUT));

	addOutput(createOutput<AudioOutPort>(Vec(142, 297), module, Vocoder::OUT_OUTPUT));
}

Model *modelVocoder = createModel<Vocoder, VocoderWidget>("Csound_Vocoder");