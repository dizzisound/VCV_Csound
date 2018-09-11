



/*
TO DO:
    Vérif echelles avec clamp, valeurs init, echelles entrées etc...
    Csound messages actifs
    enlever les printk2 dans le csd

    doc a faire



*/

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

	void csoundCession() {
		//csd sampling-rate override
		string sr_override = "--sample-rate=" + to_string(engineGetSampleRate());

		//compile instance of csound
		notReady = csound->Compile(assetPlugin(plugin, "csd/Chorus.csd").c_str(), sr_override.c_str());
		if(!notReady)
		{
			spout = csound->GetSpout();								//access csound output buffer
			spin  = csound->GetSpin();								//access csound input buffer
			ksmps = csound->GetKsmps();
		}
		else
			cout << "Csound csd compilation error!" << endl;
	}

	Chorus() : Module(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS)
	{
		csound = new Csound();                                          //Create an instance of Csound
		csound->SetMessageCallback(messageCallback);
		csoundCession();
	}

	~Chorus()
	{
		csound->Stop();
		csound->Cleanup();
		delete csound;													//free Csound object
    }

	void step() override;
	void reset() override;
	void onSampleRateChange() override;
};

void Chorus::onSampleRateChange() {
	//csound restart with new sample rate
	notReady = true;
	csound->Reset();
	csoundCession();
};

void Chorus::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundCession();
}

void Chorus::step() {
	float out1=0.0, out2=0.0;

	if(notReady) return;            //outputs set to zero

	//Process
	float in1 = clamp(inputs[IN1_INPUT].value,-5.0f, 5.0f) * 0.2f;
	float in2 = clamp(inputs[IN2_INPUT].value,-5.0f, 5.0f) * 0.2f;

	if(nbSample == 0)   //param refresh at control rate
	{
		//params
		if(inputs[DELAYLEFT_INPUT].active) {
			delayleft = clamp(inputs[DELAYLEFT_INPUT].value, 0.0f, 10.0f) * 1.95f + 0.5f;
		} else {
			delayleft = params[DELAYLEFT_PARAM].value;
		};
		if(inputs[DELAYRIGHT_INPUT].active) {
			delayright = clamp(inputs[DELAYRIGHT_INPUT].value, 0.0f, 10.0f) * 1.95f + 0.5f;
		} else {
			delayright = params[DELAYRIGHT_PARAM].value;
		};
		if(inputs[DEPTHLEFT_INPUT].active) {
			depthleft = clamp(inputs[DEPTHLEFT_INPUT].value, 0.0f, 10.0f) * 0.099f;
		} else {
			depthleft = params[DEPTHLEFT_PARAM].value;
		};
		if(inputs[DEPTHRIGHT_INPUT].active) {
			depthright = clamp(inputs[DEPTHRIGHT_INPUT].value, 0.0f, 10.0f) * 0.099f;
		} else {
			depthright = params[DEPTHRIGHT_PARAM].value;
		};
		if(inputs[RATELEFT_INPUT].active) {
			rateleft = clamp(inputs[RATELEFT_INPUT].value, 0.0f, 10.0f) * 0.1f;
		} else {
			rateleft = params[RATELEFT_PARAM].value;
		};
		if(inputs[RATERIGHT_INPUT].active) {
			rateright = clamp(inputs[RATERIGHT_INPUT].value, 0.0f, 10.0f) * 0.1f;
		} else {
			rateright = params[RATERIGHT_PARAM].value;
		};
		if(inputs[CROSS_INPUT].active) {
			cross = clamp(inputs[CROSS_INPUT].value, 0.0f, 10.0f) * 0.1f;
		} else {
			cross = params[CROSS_PARAM].value;
		};
		if(inputs[WET_INPUT].active) {
			wet = clamp(inputs[WET_INPUT].value, 0.0f, 10.0f) * 0.1f;
		} else {
			wet = params[WET_PARAM].value;
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
	outputs[OUT1_OUTPUT].value = out1*5.0;
	outputs[OUT2_OUTPUT].value = out2*5.0;
}

struct ChorusWidget : ModuleWidget {
	ChorusWidget(Chorus *module);
};

ChorusWidget::ChorusWidget(Chorus *module) : ModuleWidget(module) {
	setPanel(SVG::load(assetPlugin(plugin, "res/Chorus.svg")));

	addChild(Widget::create<ScrewSilver>(Vec(15, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(15, 365)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(ParamWidget::create<csKnob>(Vec(45, 59), module, Chorus::DELAYLEFT_PARAM, 0.5f, 20.0f, 4.95f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 59), module, Chorus::DELAYRIGHT_PARAM, 0.5f, 20.0f, 5.57f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 119), module, Chorus::DEPTHLEFT_PARAM, 0.0f, 0.99f, 0.53f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 119), module, Chorus::DEPTHRIGHT_PARAM, 0.0f, 0.99f, 0.69f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 179), module, Chorus::RATELEFT_PARAM, 0.0f, 1.0f, 0.43f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 179), module, Chorus::RATERIGHT_PARAM, 0.0f, 1.0f, 0.43f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 239), module, Chorus::CROSS_PARAM, 0.0f, 1.0f, 0.0f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 239), module, Chorus::WET_PARAM, 0.0f, 1.0f, 1.0f));

	addInput(Port::create<VcInPort>(Vec(10, 64), Port::INPUT, module, Chorus::DELAYLEFT_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 64), Port::INPUT, module, Chorus::DELAYRIGHT_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 124), Port::INPUT, module, Chorus::DEPTHLEFT_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 124), Port::INPUT, module, Chorus::DEPTHRIGHT_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 184), Port::INPUT, module, Chorus::RATELEFT_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 184), Port::INPUT, module, Chorus::RATERIGHT_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 244), Port::INPUT, module, Chorus::CROSS_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 244), Port::INPUT, module, Chorus::WET_INPUT));

	addInput(Port::create<AudioInPort>(Vec(10, 297), Port::INPUT, module, Chorus::IN1_INPUT));
	addInput(Port::create<AudioInPort>(Vec(52, 297), Port::INPUT, module, Chorus::IN2_INPUT));

	addOutput(Port::create<AudioOutPort>(Vec(101, 297), Port::OUTPUT, module, Chorus::OUT1_OUTPUT));
	addOutput(Port::create<AudioOutPort>(Vec(145, 297), Port::OUTPUT, module, Chorus::OUT2_OUTPUT));
}

Model *modelChorus = Model::create<Chorus, ChorusWidget>("VCV_Csound", "Chorus", "Stereo Chorus", CHORUS_TAG);

