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
		//vprintf(format, valist);			//if commented -> disable csound message on terminal
		return;
	}

	void csoundCession() {
		//csd sampling-rate override
		string sr_override = "--sample-rate=" + to_string(engineGetSampleRate());

		//compile instance of csound
		notReady = csound->Compile(assetPlugin(plugin, "csd/Delay.csd").c_str(), sr_override.c_str());
		if(!notReady)
		{
			spout = csound->GetSpout();								//access csound output buffer
			spin  = csound->GetSpin();								//access csound input buffer
			ksmps = csound->GetKsmps();
		}
		else
			cout << "Csound csd compilation error!" << endl;
	}

	Delay() : Module(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS)
	{
		csound = new Csound();                                          //Create an instance of Csound
		csound->SetMessageCallback(messageCallback);
		csoundCession();
	}

	~Delay()
	{
		csound->Stop();
		csound->Cleanup();
		delete csound;													//free Csound object
    }

	void step() override;
	void reset() override;
	void onSampleRateChange() override;
};

void Delay::onSampleRateChange() {
	//csound restart with new sample rate
	notReady = true;
	csound->Reset();
	csoundCession();
};

void Delay::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundCession();
}

void Delay::step() {
	float out1=0.0, out2=0.0;

	if(notReady) return;            //outputs set to zero

	//Process
	float in1 = clamp(inputs[IN1_INPUT].value,-5.0f, 5.0f) * 0.2f;
	float in2 = clamp(inputs[IN2_INPUT].value,-5.0f, 5.0f) * 0.2f;

	if(nbSample == 0)   //param refresh at control rate
	{
		//params
		if(inputs[TIMELEFT_INPUT].active) {
			timeleft = clamp(inputs[TIMELEFT_INPUT].value, 0.0f, 10.0f) * 60.0f;
		} else {
			timeleft = params[TIMELEFT_PARAM].value;
		};
		if(inputs[TIMERIGHT_INPUT].active) {
			timeright = clamp(inputs[TIMERIGHT_INPUT].value, 0.0f, 10.0f) * 60.0f;
		} else {
			timeright = params[TIMERIGHT_PARAM].value;
		};
		if(inputs[TIMEFINELEFT_INPUT].active) {
			timefineleft = clamp(inputs[TIMEFINELEFT_INPUT].value, 0.0f, 10.0f) * 0.5f;
		} else {
			timefineleft = params[TIMEFINELEFT_PARAM].value;
		};
		if(inputs[TIMEFINERIGHT_INPUT].active) {
			timefineright = clamp(inputs[TIMEFINERIGHT_INPUT].value, 0.0f, 10.0f) * 0.5f;
		} else {
			timefineright = params[TIMEFINERIGHT_PARAM].value;
		};
		if(inputs[CUTOFF_INPUT].active) {
			cutoff = clamp(inputs[CUTOFF_INPUT].value, 0.0f, 10.0f) * 0.1f;
		} else {
			cutoff = params[CUTOFF_PARAM].value;
		};
		if(inputs[FEEDBACK_INPUT].active) {
			feedback = clamp(inputs[FEEDBACK_INPUT].value, 0.0f, 10.0f) * 0.1f;
		} else {
			feedback = params[FEEDBACK_PARAM].value;
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
	outputs[OUT1_OUTPUT].value = out1*5.0;
	outputs[OUT2_OUTPUT].value = out2*5.0;
}

struct DelayWidget : ModuleWidget {
	DelayWidget(Delay *module);
};

DelayWidget::DelayWidget(Delay *module) : ModuleWidget(module) {
	setPanel(SVG::load(assetPlugin(plugin, "res/Delay.svg")));

	addChild(Widget::create<ScrewSilver>(Vec(15, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(15, 365)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(ParamWidget::create<csKnob>(Vec(45, 59), module, Delay::TIMELEFT_PARAM, 0.0f, 600.0f, 300.0f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 59), module, Delay::TIMERIGHT_PARAM, 0.0f, 600.0f, 600.0f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 119), module, Delay::TIMEFINELEFT_PARAM, 0.0f, 5.0f, 1.5f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 119), module, Delay::TIMEFINERIGHT_PARAM, 0.0f, 5.0f, 3.0f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 179), module, Delay::CUTOFF_PARAM, 0.0f, 1.0f, 0.4f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 179), module, Delay::FEEDBACK_PARAM, 0.0f, 1.0f, 0.24f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 239), module, Delay::CROSS_PARAM, 0.0f, 1.0f, 0.23f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 239), module, Delay::WET_PARAM, 0.0f, 1.0f, 0.19f));

	addInput(Port::create<VcInPort>(Vec(10, 64), Port::INPUT, module, Delay::TIMELEFT_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 64), Port::INPUT, module, Delay::TIMERIGHT_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 124), Port::INPUT, module, Delay::TIMEFINELEFT_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 124), Port::INPUT, module, Delay::TIMEFINERIGHT_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 184), Port::INPUT, module, Delay::CUTOFF_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 184), Port::INPUT, module, Delay::FEEDBACK_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 244), Port::INPUT, module, Delay::CROSS_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 244), Port::INPUT, module, Delay::WET_INPUT));

	addInput(Port::create<AudioInPort>(Vec(10, 297), Port::INPUT, module, Delay::IN1_INPUT));
	addInput(Port::create<AudioInPort>(Vec(52, 297), Port::INPUT, module, Delay::IN2_INPUT));

	addOutput(Port::create<AudioOutPort>(Vec(101, 297), Port::OUTPUT, module, Delay::OUT1_OUTPUT));
	addOutput(Port::create<AudioOutPort>(Vec(145, 297), Port::OUTPUT, module, Delay::OUT2_OUTPUT));
}

Model *modelDelay = Model::create<Delay, DelayWidget>("VCV_Csound", "Delay", "Stereo Delay", DELAY_TAG);

