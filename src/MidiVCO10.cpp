#pragma once

#include "VCV_Csound.hpp"
#include <csound/csound.hpp>
#include <iostream>

using namespace std;


struct MidiVCO10 : Module {
	enum ParamIds {
		WAVEFORM_PARAM,
		OCTAVE_PARAM,
		SEMITONE_PARAM,
		HARM_PARAM,
		PWM_PARAM,
		PMDEPTH_PARAM,
		PMRATE_PARAM,
		NOISEBW_PARAM,
		NUM_PARAMS
	};
	enum InputIds {
		WAVEFORM_INPUT,
		OCTAVE_INPUT,
		SEMITONE_INPUT,
		HARM_INPUT,
		PWM_INPUT,
		PMDEPTH_INPUT,
		PMRATE_INPUT,
		NOISEBW_INPUT,
		NUM_INPUTS
	};
	enum OutputIds {
		GATE_OUTPUT,
		OUT_OUTPUT,
		NUM_OUTPUTS
	};
	enum LightIds {
		NUM_LIGHTS
	};

	Csound* csound;
	
	MYFLT *spin, *spout;

	int nbSample = 0;
	int ksmps, result;
	bool notReady;
	//int const nchnls = 1;			// 1 output in csd
	
	float waveform, octave, semitone, harm, pwm, pmdepth, pmrate, noisebw, gate;

	std::string waveDesc;
	std::string waveType[10]={"SAWTOOTH", "SQUARE \n PWM", "RAMP \n PWM", "PULSE", "PARABOLA", "SQUARE", "TRIANGLE", "USER WAVE \n Trapezoid", "BUZZ", "PINK NOISE \n Band Width"};

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
		notReady = csound->Compile(asset::plugin(pluginInstance, "csd/MidiVCO10.csd").c_str(), sr_override.c_str());
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

	MidiVCO10() {
		config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
		configParam(WAVEFORM_PARAM, 0.0f, 9.0f, 0.0f);
		configParam(OCTAVE_PARAM, -5.0f, 5.0f, 0.0f);
		configParam(SEMITONE_PARAM, -12.0f, 12.0f, 0.0f);
		configParam(HARM_PARAM, 0.0f, 1.0f, 0.5f);
		configParam(PWM_PARAM, 0.0f, 1.0f, 0.5f);
		configParam(PMDEPTH_PARAM, 0.0f, 1.0f, 0.2f);
		configParam(PMRATE_PARAM, 0.001f, 50.0f, 4.0f);
		configParam(NOISEBW_PARAM, 0.0f, 10.0f, 2.0f);
	}

	~MidiVCO10() {
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

void MidiVCO10::onAdd() {
	notReady = true;
	if (csound) {
		dispose();
	}
	csound = new Csound(); //Create an instance of Csound
	csound->SetMessageCallback(messageCallback);	
	csoundSession();
}

void MidiVCO10::onRemove() {
	dispose();
}

void MidiVCO10::onSampleRateChange() {
	//csound restart with new sample rate
	reset();
};

void MidiVCO10::onReset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	reset();
}

void MidiVCO10::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundSession();
}

void MidiVCO10::dispose() {
	notReady = true;
	if (csound) {
		csound = NULL;
		spin = NULL;
		spout = NULL;
	}
}

void MidiVCO10::process(const ProcessArgs& args) {
	
	MYFLT out=0.0;

	if(notReady) return;            //output set to zero

	//Process
	if(nbSample == 0)   //param refresh at control rate
	{
		//params
		if(inputs[WAVEFORM_INPUT].isConnected()) {
			waveform = clamp(inputs[WAVEFORM_INPUT].getVoltage(), 0.0f, 9.0f);
		} else {
			waveform = round(params[WAVEFORM_PARAM].getValue());
		};
		waveDesc = waveType[(int) waveform];

		if(inputs[OCTAVE_INPUT].isConnected()) {
			octave = clamp(inputs[OCTAVE_INPUT].getVoltage(), 0.0f, 10.0f) - 5.0f;
		} else {
			octave = params[OCTAVE_PARAM].getValue();
		};
		if(inputs[SEMITONE_INPUT].isConnected()) {
			semitone = clamp(inputs[SEMITONE_INPUT].getVoltage(), 0.0f, 10.0f) * 2.4f - 12.0f; 
		} else {
			semitone = params[SEMITONE_PARAM].getValue();
		};
		if(inputs[HARM_INPUT].isConnected()) {
			harm = clamp(inputs[HARM_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
		} else {
			harm = params[HARM_PARAM].getValue();
		};
		if(inputs[PWM_INPUT].isConnected()) {
			pwm = clamp(inputs[PWM_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
		} else {
			pwm = params[PWM_PARAM].getValue();
		};
		if(inputs[PMDEPTH_INPUT].isConnected()) {
			pmdepth = clamp(inputs[PMDEPTH_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
		} else {
			pmdepth = params[PMDEPTH_PARAM].getValue();
		};
		if(inputs[PMRATE_INPUT].isConnected()) {
			pmrate = clamp(inputs[PMRATE_INPUT].getVoltage(), 0.0f, 10.0f) * 4.9999f + 0.001f;
		} else {
			pmrate = params[PMRATE_PARAM].getValue();
		};
		if(inputs[NOISEBW_INPUT].isConnected()) {
			noisebw = clamp(inputs[NOISEBW_INPUT].getVoltage(), 0.0f, 10.0f);
		} else {
			noisebw = params[NOISEBW_PARAM].getValue();
		};

		csound->SetChannel("Waveform", waveform);
 		csound->SetChannel("Octave", octave);
 		csound->SetChannel("Semitone", semitone);
 		csound->SetChannel("Harmonics", harm);
 		csound->SetChannel("PulseWidth", pwm);
 		csound->SetChannel("PhaseDepth", pmdepth);
 		csound->SetChannel("PhaseRate", pmrate);
 		csound->SetChannel("NoiseBW", noisebw);

		gate = csound->GetChannel("Gate", NULL);
		outputs[GATE_OUTPUT].setVoltage(gate ? 10.f : 0.f);

		result = csound->PerformKsmps();
	}
	if(!result)
	{
		out = spout[nbSample];
		nbSample++;
		if (nbSample == ksmps)			//nchnls = 1
			nbSample = 0;
	}
	outputs[OUT_OUTPUT].setVoltage(out*5.0);
}

struct MidiVCO10Display : TransparentWidget {
	MidiVCO10 *module;
	shared_ptr<Font> font;

	MidiVCO10Display() {
		font = APP->window->loadFont(asset::system("res/fonts/DejaVuSans.ttf"));
	}
	
	void draw(const DrawArgs& args) override {
		if (module) {
			nvgFontSize(args.vg, 10);
			nvgFontFaceId(args.vg, font->handle);
			nvgTextLetterSpacing(args.vg, 1);
			nvgFillColor(args.vg, nvgRGBA(0xff, 0xff, 0x3e, 0xff));              //textColor
			nvgTextBox(args.vg, 15, 75, 88, module->waveDesc.c_str(), NULL);     //text
			nvgStroke(args.vg);
		}
	}
};

struct MidiVCO10Widget : ModuleWidget {
	MidiVCO10Widget(MidiVCO10 *module);
};

MidiVCO10Widget::MidiVCO10Widget(MidiVCO10 *module) {
	setModule(module);
	setPanel(APP->window->loadSvg(asset::plugin(pluginInstance, "res/MidiVCO10.svg")));

	{
		MidiVCO10Display *display = new MidiVCO10Display();
		display->module = module;
		addChild(display);
	}

	addChild(createWidget<ScrewSilver>(Vec(15, 0)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(createWidget<ScrewSilver>(Vec(15, 365)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(createParam<csKnob>(Vec(135, 59), module, MidiVCO10::WAVEFORM_PARAM));
	addParam(createParam<csKnob>(Vec(45, 119), module, MidiVCO10::OCTAVE_PARAM));
	addParam(createParam<csKnob>(Vec(135, 119), module, MidiVCO10::SEMITONE_PARAM));
	addParam(createParam<csKnob>(Vec(45, 179), module, MidiVCO10::HARM_PARAM));
	addParam(createParam<csKnob>(Vec(135, 179), module, MidiVCO10::PWM_PARAM));
	addParam(createParam<csKnob>(Vec(45, 239), module, MidiVCO10::PMDEPTH_PARAM));
	addParam(createParam<csKnob>(Vec(135, 239), module, MidiVCO10::PMRATE_PARAM));
	addParam(createParam<csKnob>(Vec(45, 299), module, MidiVCO10::NOISEBW_PARAM));

	addInput(createInput<VcInPort>(Vec(100, 64), module, MidiVCO10::WAVEFORM_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 124), module, MidiVCO10::OCTAVE_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 124), module, MidiVCO10::SEMITONE_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 184), module, MidiVCO10::HARM_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 184), module, MidiVCO10::PWM_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 244), module, MidiVCO10::PMDEPTH_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 244), module, MidiVCO10::PMRATE_INPUT));
	addInput(createInput<VcInPort>(Vec(10, 304), module, MidiVCO10::NOISEBW_INPUT));

	addOutput(createOutput<VcOutPort>(Vec(101, 297), module, MidiVCO10::GATE_OUTPUT));
	addOutput(createOutput<AudioOutPort>(Vec(137, 297), module, MidiVCO10::OUT_OUTPUT));
}

Model *modelMidiVCO10 = createModel<MidiVCO10, MidiVCO10Widget>("Csound_MidiVCO10");