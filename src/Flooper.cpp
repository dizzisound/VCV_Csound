#include "VCV_Csound.hpp"
#include "osdialog.h"
#include <csound/csound.hpp>
#include <iostream>

using namespace std;


struct Flooper : Module {
	enum ParamIds {
	START_PARAM,
	END_PARAM,
	TRANSPOSE_PARAM,
	LOOP_PARAM,
	NUM_PARAMS
	};
	enum InputIds {
	START_INPUT,
	END_INPUT,
	TRANSPOSE_INPUT,
	GATE_INPUT,
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

	float start, end, transpose, loop, gate, samplePos;

	string lastPath = "";
	string fileDesc = "";
	string filePath = "";
	
	vector<double> displayBuff;

	static void messageCallback(CSOUND* cs, int attr, const char *format, va_list valist) {
		//vprintf(format, valist);    //if commented -> disable csound message on terminal
		return;
	}

	void csoundCession() {
		//csd sampling-rate override
		string sr_override = "--sample-rate=" + to_string(engineGetSampleRate());

		//sample file load
		string filemacro = "--omacro:Filepath=" + filePath;

		//compile instance of csound
		notReady = csound->Compile(assetPlugin(plugin, "csd/Flooper.csd").c_str(), sr_override.c_str(), filemacro.c_str());
		if(!notReady)
		{
			spout = csound->GetSpout();							//access csound output buffer
			spin  = csound->GetSpin();							//access csound input buffer
			ksmps = csound->GetKsmps();

			fileDesc = stringFilename(filePath)+ "\n";
			fileDesc += std::to_string((int) csound->GetChannel("FileSr", NULL)) + " Hz" + "\n";
			fileDesc += std::to_string(csound->GetChannel("FileLen", NULL)) + " s.";

			//display buffer setting
			double *temp;
			int tableSize = csound->GetTable(temp, 1);

			vector<double>().swap(displayBuff);
			for (int i=0; i < tableSize; i++)
				displayBuff.push_back(temp[i]);
		}
		else {
			cout << "Csound csd compilation error!" << endl;
			fileDesc = "Right click to load \n a aiff, wav, ogg or flac audio file";
		}
	}

	Flooper() : Module(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS) {
		csound = new Csound();									//Create an instance of Csound
		csound->SetMessageCallback(messageCallback);
		csoundCession();
	}

	~Flooper() {
		csound->Stop();
		csound->Cleanup();
		delete csound;											//free Csound object
	}

	void step() override;
	void reset() override;
	void onSampleRateChange() override;
	void loadSample(std::string path);


	// persistence
	json_t *toJson() override {
		json_t *rootJ = json_object();
		// lastPath
		json_object_set_new(rootJ, "lastPath", json_string(lastPath.c_str()));	
		return rootJ;
	}

	void fromJson(json_t *rootJ) override {
		// lastPath
		json_t *lastPathJ = json_object_get(rootJ, "lastPath");
		if (lastPathJ) {
			lastPath = json_string_value(lastPathJ);
			loadSample(lastPath);
		}
	}
};

void Flooper::onSampleRateChange() {
	//csound restart with new sample rate
	notReady = true;
	csound->Reset();
	csoundCession();
};

void Flooper::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	csound->Reset();
	csoundCession();
}

void Flooper::loadSample(std::string path) {
	filePath = path;
	lastPath = path;

	notReady = true;
	csound->Reset();
	csoundCession();
};

void Flooper::step() {
	float out=0.0;

	if(notReady) return;            //output set to zero

	//Process
	if(nbSample == 0)   //param refresh at control rate
	{
		//params
		if(inputs[START_INPUT].active) {
			start = clamp(inputs[START_INPUT].value, 0.0f, 10.0f) * 0.1f;
		} else {
			start = params[START_PARAM].value;
		};

		if(inputs[END_INPUT].active) {
			end = clamp(inputs[END_INPUT].value, 0.0f, 10.0f) * 0.1f;
		} else {
			end = params[END_PARAM].value;
		};

		if(inputs[TRANSPOSE_INPUT].active) {
			transpose = clamp(inputs[TRANSPOSE_INPUT].value, 0.0f, 10.0f) * 2.4f - 12.0f;
		} else {
			transpose = params[TRANSPOSE_PARAM].value;
		};
		
		gate = clamp(inputs[GATE_INPUT].value, 0.0f, 10.0f) * 0.1f;
		loop = params[LOOP_PARAM].value;

		csound->SetChannel("Start", start);
		csound->SetChannel("End", end);
		csound->SetChannel("Transpose", transpose);
		csound->SetChannel("Loop", loop);
		csound->SetChannel("Gate", gate);

		samplePos = csound->GetChannel("SamplePos", NULL);

		result = csound->PerformKsmps();
	}
	if(!result)
	{
		out = spout[nbSample];
		nbSample++;
		if (nbSample == ksmps)			//nchnls = 1
			nbSample = 0;
	}
	outputs[OUT_OUTPUT].value = out*5.0;
}

struct FlooperDisplay : TransparentWidget {			//code from Clement Foulc player module
	Flooper *module;
	shared_ptr<Font> font;

	FlooperDisplay() {
		font = Font::load(assetGlobal("res/fonts/DejaVuSans.ttf"));
	}

	void draw(NVGcontext *vg) override {
		nvgFontSize(vg, 12);
		nvgFontFaceId(vg, font->handle);
		nvgTextLetterSpacing(vg, 1);
		nvgFillColor(vg, nvgRGBA(0xff, 0xff, 0x3e, 0xff));                  //text color
		nvgTextBox(vg, 10, 15, 120, module->fileDesc.c_str(), NULL);

		nvgStrokeColor(vg, nvgRGBA(0xff, 0xff, 0xff, 0x40));                //line color

 		int offset = 5;
 		int start = offset + (module->start) * 160;
 		int end   = offset + (module->end)   * 160;
 		int samplePos = offset + (module->samplePos) * 160;

		// Draw ref line
		{
			nvgBeginPath(vg);
			nvgMoveTo(vg, 5, 90);
			nvgLineTo(vg, 165, 90);
			nvgClosePath(vg);
		}
		nvgStroke(vg);
		// Draw Start line
		{
			nvgBeginPath(vg);
			nvgMoveTo(vg, start, 70);
			nvgLineTo(vg, start, 110);
			nvgClosePath(vg);
		}
		nvgStroke(vg);
		// Draw End line
		{
			nvgBeginPath(vg);
			nvgMoveTo(vg, end, 70);
			nvgLineTo(vg, end, 110);
			nvgClosePath(vg);
		}
		nvgStroke(vg);

		if (module->notReady == false) {
			// Draw play line
			nvgStrokeColor(vg, nvgRGBA(0x28, 0xb0, 0xf3, 0xff));
			nvgStrokeWidth(vg, 0.8);
			{
				nvgBeginPath(vg);
				nvgMoveTo(vg, samplePos, 70);
				nvgLineTo(vg, samplePos, 110);
				nvgClosePath(vg);
			}
			nvgStroke(vg);

			// Draw waveform
			nvgStrokeColor(vg, nvgRGBA(0xff, 0xff, 0x3e, 0xff));				//wave color
			nvgSave(vg);
			Rect b = Rect(Vec(5, 75), Vec(160, 30));
			nvgScissor(vg, b.pos.x, b.pos.y, b.size.x, b.size.y);
			nvgBeginPath(vg);

			for (unsigned int i = 0; i < module->displayBuff.size(); i++) {
				float x, y;
				x = (float)i / (module->displayBuff.size() - 1);
				y = module->displayBuff[i] / 2.0 + 0.5;
				Vec p;
				p.x = b.pos.x + b.size.x * x;
				p.y = b.pos.y + b.size.y * (1.0 - y);
				if (i == 0)
					nvgMoveTo(vg, p.x, p.y);
				else
					nvgLineTo(vg, p.x, p.y);
			}

			nvgLineCap(vg, NVG_ROUND);
			nvgMiterLimit(vg, 2.0);
			nvgStrokeWidth(vg, 0.5);
			//nvgGlobalCompositeOperation(vg, NVG_LIGHTER);
			nvgStroke(vg);			
			nvgResetScissor(vg);
			nvgRestore(vg);	
		}
	}
};

struct FlooperWidget : ModuleWidget {
	FlooperWidget(Flooper *module);
	Menu *createContextMenu() override;
};

FlooperWidget::FlooperWidget(Flooper *module) : ModuleWidget(module) {
	setPanel(SVG::load(assetPlugin(plugin, "res/Flooper.svg")));

	{
		FlooperDisplay *display = new FlooperDisplay();
		display->module = module;
		display->box.pos = Vec(5, 40);
		display->box.size = Vec(130, 250);
		addChild(display);
	}

	addChild(Widget::create<ScrewSilver>(Vec(15, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(Widget::create<ScrewSilver>(Vec(15, 365)));
	addChild(Widget::create<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(ParamWidget::create<csKnob>(Vec(45, 179), module, Flooper::START_PARAM, 0.0f, 1.0f, 0.0f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 179), module, Flooper::END_PARAM, 0.0f, 1.0f, 1.0f));
	addParam(ParamWidget::create<csKnob>(Vec(135, 239), module, Flooper::TRANSPOSE_PARAM, -12.0f, 12.0f, 0.0f));

	addParam(ParamWidget::create<csBefacoSwitch>(Vec(52, 241), module, Flooper::LOOP_PARAM, 0.0f, 1.0f, 0.0f));

	addInput(Port::create<VcInPort>(Vec(10, 184), Port::INPUT, module, Flooper::START_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 184), Port::INPUT, module, Flooper::END_INPUT));
	addInput(Port::create<VcInPort>(Vec(100, 244), Port::INPUT, module, Flooper::TRANSPOSE_INPUT));

	addInput(Port::create<VcInPort>(Vec(33, 297), Port::INPUT, module, Flooper::GATE_INPUT));

	addOutput(Port::create<AudioOutPort>(Vec(121, 297), Port::OUTPUT, module, Flooper::OUT_OUTPUT));
}

struct FlooperItem : MenuItem {
	Flooper *player;
	void onAction(EventAction &e) override {
		std::string dir = assetLocal("/plugins/VCV_Csound/samples");
		char *path = osdialog_file(OSDIALOG_OPEN, dir.c_str(), NULL, NULL);
		if (path) player->loadSample(path);
    	free(path);
	}
};

Menu *FlooperWidget::createContextMenu() {
	Menu *menu = ModuleWidget::createContextMenu();

	MenuLabel *spacerLabel = new MenuLabel();
	menu->addChild(spacerLabel);

	Flooper *player = dynamic_cast<Flooper*>(module);
	assert(player);

	FlooperItem *sampleItem = new FlooperItem();
	sampleItem->text = "Load sample";
	sampleItem->player = player;
	menu->addChild(sampleItem);
	return menu;
}

Model *modelFlooper = Model::create<Flooper, FlooperWidget>("VCV_Csound", "Looper", "File Looper", SAMPLER_TAG);

