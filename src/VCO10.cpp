#include "VCV_Csound.hpp"
#include <csound/csound.hpp>
#include <iostream>

using namespace std;


struct VCO10 : Module {
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
	//int const nchnls = 1;       // 1 output in csd
	float waveform, octave, semitone, harm, pwm, pmdepth, pmrate, noisebw;

	string waveDesc;
	string waveType[10]={"SAWTOOTH", "SQUARE \n PWM", "RAMP \n PWM", "PULSE", "PARABOLA", "SQUARE", "TRIANGLE", "USER WAVE \n Trapezoid", "BUZZ", "PINK NOISE \n Band Width"};

	static void messageCallback(CSOUND* cs, int attr, const char *format, va_list valist) {
		//vprintf(format, valist);    //if commented -> disable csound message on terminal
		return;
	}

	void csoundCession() {
		//csd sampling-rate override
		string sr_override = "--sample-rate=" + to_string(engineGetSampleRate());

		//compile instance of csound
		notReady = csound->Compile(assetPlugin(plugin, "csd/VCO10.csd").c_str(), sr_override.c_str());
		if(!notReady)
		{
			spout = csound->GetSpout();								//access csound output buffer
			spin  = csound->GetSpin();								//access csound input buffer
			ksmps = csound->GetKsmps();
		}
		else
			cout << "Csound csd compilation error!" << endl;
	}

	VCO10() : Module(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS) {
		csound = new Csound();										//Create an instance of Csound
		csound->SetMessageCallback(messageCallback);
		csoundCession();
	}

	~VCO10()
	{
 		csound->Stop();
 		csound->Cleanup();
		delete csound;												//free Csound object
	}

	void step() override;
	void reset() override;
	void onSampleRateChange() override;
};

void VCO10::onSampleRateChange() {
	//csound restart with new sample rate
	notReady = true;
	csound->Reset();
	csoundCession();
};

void VCO10::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundCession();
}

void VCO10::step() {
	float out=0.0;

	if(notReady) return;						//output set to zero

	//Process
	if(nbSample == 0)							//param refresh at control rate
	{
		//params
		if(inputs[WAVEFORM_INPUT].active) {
			waveform = clamp(inputs[WAVEFORM_INPUT].value*0.125f, 0.0f, 1.0f);
		} else {
			waveform = round(params[WAVEFORM_PARAM].value);
		};
			waveDesc = waveType[(int) waveform];
		if(inputs[OCTAVE_INPUT].active) {
			octave = clamp(inputs[OCTAVE_INPUT].value*0.125f, 0.0f, 1.0f);
		} else {
			octave = params[OCTAVE_PARAM].value;
		};
		if(inputs[SEMITONE_INPUT].active) {
			semitone = clamp(inputs[SEMITONE_INPUT].value*0.125f, 0.0f, 1.0f);
		} else {
			semitone = params[SEMITONE_PARAM].value;
		};
		if(inputs[HARM_INPUT].active) {
			harm = clamp(inputs[HARM_INPUT].value*0.125f, 0.0f, 1.0f);
		} else {
			harm = params[HARM_PARAM].value;
		};
		if(inputs[PWM_INPUT].active) {
			pwm = clamp(inputs[PWM_INPUT].value*0.125f, 0.0f, 1.0f);
		} else {
			pwm = params[PWM_PARAM].value;
		};
		if(inputs[PMDEPTH_INPUT].active) {
			pmdepth = clamp(inputs[PMDEPTH_INPUT].value*0.125f, 0.0f, 1.0f);
		} else {
			pmdepth = params[PMDEPTH_PARAM].value;
		};
		if(inputs[PMRATE_INPUT].active) {
			pmrate = clamp(inputs[PMRATE_INPUT].value*0.125f, 0.0f, 1.0f);
		} else {
			pmrate = params[PMRATE_PARAM].value;
		};
		if(inputs[NOISEBW_INPUT].active) {
			noisebw = clamp(inputs[NOISEBW_INPUT].value*0.125f, 0.0f, 1.0f);
		} else {
			noisebw = params[NOISEBW_PARAM].value;
		};

		csound->SetChannel("Waveform", waveform);
		csound->SetChannel("Octave", octave);
		csound->SetChannel("Semitone", semitone);
		csound->SetChannel("Harmonics", harm);
		csound->SetChannel("PulseWidth", pwm);
		csound->SetChannel("PhaseDepth", pmdepth);
		csound->SetChannel("PhaseRate", pmrate);
		csound->SetChannel("NoiseBW", noisebw);

		result = csound->PerformKsmps();
	}
	if(!result)
	{
		out = spout[nbSample];
		nbSample++;
		if (nbSample == ksmps)      //nchnls = 1
			nbSample = 0;
	}
	outputs[OUT_OUTPUT].value = out*4.0;
}

struct VCO10Display : TransparentWidget {
	VCO10 *module;
	shared_ptr<Font> font;

	VCO10Display() {
		font = Font::load(assetGlobal("res/fonts/DejaVuSans.ttf"));
	}

	void draw(NVGcontext *vg) override {
		nvgFontSize(vg, 10);
		nvgFontFaceId(vg, font->handle);
		nvgTextLetterSpacing(vg, 1);
		nvgFillColor(vg, nvgRGBA(0xff, 0xff, 0x3e, 0xff));						//textColor
		nvgTextBox(vg, 15, 75, 88, module->waveDesc.c_str(), NULL);				//text
		nvgStroke(vg);
	}
};

struct VCO10Widget : ModuleWidget {
	VCO10Widget(VCO10 *module);
};

VCO10Widget::VCO10Widget(VCO10 *module) : ModuleWidget(module) {
	setPanel(SVG::load(assetPlugin(plugin, "res/VCO10.svg")));

	{
		VCO10Display *display = new VCO10Display();
		display->module = module;
		addChild(display);
	}

	addChild(Widget::create<ScrewSilver>(Vec(15, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(15, 365)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(ParamWidget::create<csKnob>(Vec(135, 59), module, VCO10::WAVEFORM_PARAM, 0.0f, 9.0f, 0.0f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 119), module, VCO10::OCTAVE_PARAM, -5.0f, 5.0f, 0.0f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 119), module, VCO10::SEMITONE_PARAM, -12.0f, 12.0f, 0.0f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 179), module, VCO10::HARM_PARAM, 0.0f, 1.0f, 0.5f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 179), module, VCO10::PWM_PARAM, 0.0f, 1.0f, 0.5f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 239), module, VCO10::PMDEPTH_PARAM, 0.0f, 1.0f, 0.2f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 239), module, VCO10::PMRATE_PARAM, 0.001f, 50.0f, 4.0f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 299), module, VCO10::NOISEBW_PARAM, 0.0f, 10.0f, 2.0f));

	addInput(Port::create<VcInPort>(Vec(100, 64), Port::INPUT, module, VCO10::WAVEFORM_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 124), Port::INPUT, module, VCO10::OCTAVE_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 124), Port::INPUT, module, VCO10::SEMITONE_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 184), Port::INPUT, module, VCO10::HARM_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 184), Port::INPUT, module, VCO10::PWM_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 244), Port::INPUT, module, VCO10::PMDEPTH_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 244), Port::INPUT, module, VCO10::PMRATE_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 304), Port::INPUT, module, VCO10::NOISEBW_INPUT));

	addOutput(Port::create<AudioOutPort>(Vec(121, 297), Port::OUTPUT, module, VCO10::OUT_OUTPUT));
}

Model *modelVCO10 = Model::create<VCO10, VCO10Widget>("VCV_Csound", "VCO10", "VCO 10 Waves", OSCILLATOR_TAG);

