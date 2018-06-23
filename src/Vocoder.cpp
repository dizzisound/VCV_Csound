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
    int const nchnls = 2;       // 2 inputs and 2 outputs in csd

    bool notReady;

    float bandwidth, bandspacing, base, bpGain, hpGain, carFilter, steepness, gate;



    static void messageCallback(CSOUND* cs, int attr, const char *format, va_list valist)
    {
        //vprintf(format, valist);    //if commented -> disable csound message on terminal
        return;
    }

    void csoundCession() {
        //csd sampling-rate override
        string sr_override = "--sample-rate=" + to_string(engineGetSampleRate());

        //compile instance of csound
        notReady = csound->Compile(assetPlugin(plugin, "csd/Vocoder.csd").c_str(), (char *) sr_override.c_str());
	    if(!notReady)
	    {
            spout = csound->GetSpout();                                     //access csound output buffer
            spin  = csound->GetSpin();                                      //access csound input buffer
            ksmps = csound->GetKsmps();
        }
	    else
	        cout << "Csound csd compilation error!" << endl;
    }

	Vocoder() : Module(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS)
	{
        csound = new Csound();                                          //Create an instance of Csound
        csound->SetMessageCallback(messageCallback);
        csoundCession();
	}

    ~Vocoder()
    {
        delete csound;                  //free Csound object
    }

	void step() override;
	void reset() override;
	void onSampleRateChange() override;
};

void Vocoder::onSampleRateChange() {
    //csound restart with new sample rate
    notReady = true;
    csound->Reset();
    csoundCession();
};

void Vocoder::reset() {
    //menu initialize: csound restart with modified (or not!) csound script csd
    notReady = true;
    csound->Reset();
    csoundCession();
}

void Vocoder::step() {
    float out=0.0;

    if(notReady) return;            //outputs set to zero

    //Process
    float in1 = clamp(inputs[MOD_INPUT].value,-10.0f,10.0f);
    float in2 = clamp(inputs[CAR_INPUT].value,-10.0f,10.0f);

    if(nbSample == 0)   //param refresh at control rate
    {
        //params
        if(inputs[BANDWIDTH_INPUT].active) {
    		bandwidth = clamp(inputs[BANDWIDTH_INPUT].value*0.125f, 0.0f, 1.0f);
     	} else {
       		bandwidth = params[BANDWIDTH_PARAM].value;
       	};

       	if(inputs[BANDSPACING_INPUT].active) {
       		bandspacing = clamp(inputs[BANDSPACING_INPUT].value*0.125f, 0.0f, 1.0f);
       	} else {
       		bandspacing = params[BANDSPACING_PARAM].value;
       	};

       	if(inputs[BASE_INPUT].active) {
       		base = clamp(inputs[BASE_INPUT].value*8.0f, 24.0f, 80.0f);
       	} else {
       		base = params[BASE_PARAM].value;
       	};

        steepness   = params[STEPNESS_PARAM].value;
   		bpGain      = params[BPF_PARAM].value;
   		hpGain      = params[HPF_PARAM].value;
        carFilter   = params[CARFILTER_PARAM].value;
        gate        = params[GATE_PARAM].value;

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
    outputs[OUT_OUTPUT].value = out*4.0;
}

struct VocoderWidget : ModuleWidget {
	VocoderWidget(Vocoder *module);
};

VocoderWidget::VocoderWidget(Vocoder *module) : ModuleWidget(module) {
	setPanel(SVG::load(assetPlugin(plugin, "res/Vocoder.svg")));

	addChild(Widget::create<ScrewSilver>(Vec(15, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(15, 365)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(ParamWidget::create<csKnob>(Vec(45, 59), module, Vocoder::BANDWIDTH_PARAM, 0.0f, 1.0f, 0.5f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 59), module, Vocoder::BANDSPACING_PARAM, 0.0f, 1.0f, 0.648f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 119), module, Vocoder::BASE_PARAM, 24.0f, 80.0f, 40.0f));
	addParam(ParamWidget::create<csKnob>(Vec(45, 179), module, Vocoder::BPF_PARAM, 0.0f, 1.0f, 0.945f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 179), module, Vocoder::HPF_PARAM, 0.0f, 1.0f, 0.849f));

	addParam(ParamWidget::create<csBefacoSwitch>(Vec(138, 120), module, Vocoder::STEPNESS_PARAM, 0.0f, 1.0f, 1.0f));
	addParam(ParamWidget::create<csBefacoSwitch>(Vec(138, 241), module, Vocoder::CARFILTER_PARAM, 0.0f, 1.0f, 0.0f));
	addParam(ParamWidget::create<csBefacoSwitch>(Vec(52, 241), module, Vocoder::GATE_PARAM, 0.0f, 1.0f, 0.0f));

	addInput(Port::create<VcInPort>(Vec(10, 64), Port::INPUT, module, Vocoder::BANDWIDTH_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 64), Port::INPUT, module, Vocoder::BANDSPACING_INPUT));
	addInput(Port::create<VcInPort>(Vec(10, 124), Port::INPUT, module, Vocoder::BASE_INPUT));

	addInput(Port::create<AudioInPort>(Vec(39, 297), Port::INPUT, module, Vocoder::MOD_INPUT));
	addInput(Port::create<AudioInPort>(Vec(101, 297), Port::INPUT, module, Vocoder::CAR_INPUT));

	addOutput(Port::create<AudioOutPort>(Vec(142, 297), Port::OUTPUT, module, Vocoder::OUT_OUTPUT));
}

Model *modelVocoder = Model::create<Vocoder, VocoderWidget>("VCV_Csound", "Vocoder", "32 bands Vocoder", VOCODER_TAG);

