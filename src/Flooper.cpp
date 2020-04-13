#pragma once

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

	std::string lastPath = "";
	std::string fileDesc = "";
	std::string filePath = "";
	
	vector<double> displayBuff;

	static void messageCallback(CSOUND* cs, int attr, const char *format, va_list valist) {
		vprintf(format, valist);    //if commented -> disable csound message on terminal
		return;
	}

	void csoundSession() {
		//csd sampling-rate override
		std::string sr_override = "--sample-rate=" + to_string(APP->engine->getSampleRate());
		
		//string-replace routine --> https://stackoverflow.com/questions/4643512/replace-substring-with-another-substring-c	
		size_t index = 0;
		while (true) {
			/* Locate the substring to replace. */
			index = filePath.find("\\", index);
			if (index == std::string::npos) break;

			/* Make the replacement. */
			filePath.replace(index, 1, "/");

			/* Advance index forward so the next iteration doesn't pick it up as well. */
			index += 1;
		}	
		
		//sample file load  
		std::string filemacro = "--omacro:Filepath=" + filePath;
		std::cout << "filemacro: " << filemacro << endl;
		
		//compile instance of csound
		csound->SetOption((char*)"-n");
		csound->SetOption((char*)"-d");
		csound->SetHostImplementedAudioIO(1, 0);
		notReady = csound->Compile(asset::plugin(pluginInstance, "csd/Flooper.csd").c_str(), sr_override.c_str(), filemacro.c_str());
		if(!notReady)
		{
			nbSample = 0;
			spout = csound->GetSpout();							//access csound output buffer
			spin  = csound->GetSpin();							//access csound input buffer
			ksmps = csound->GetKsmps();

			fileDesc = string::filename(filePath)+ "\n";
			fileDesc += std::to_string((int) csound->GetChannel("FileSr", NULL)) + " Hz" + "\n";
			fileDesc += std::to_string(csound->GetChannel("FileLen", NULL)) + " s.";

			//display buffer setting
			double /*float*/ *temp;
			int tableSize = csound->GetTable(temp, 1);

			vector<double>().swap(displayBuff);
			for (int i=0; i < tableSize; i++)
				displayBuff.push_back(temp[i]);
		}
		else {
			std::cout << "Csound csd compilation error!" << endl;
			std::cout << "Filepath: " << filePath << endl;
			fileDesc = "Right click to load \n a aiff, wav, ogg or flac audio file";
		}
	}

	Flooper() {
		config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
		configParam(START_PARAM, 0.0f, 1.0f, 0.0f);
		configParam(END_PARAM, 0.0f, 1.0f, 1.0f);
		configParam(TRANSPOSE_PARAM, -12.0f, 12.0f, 0.0f);
		configParam(LOOP_PARAM, 0.0f, 1.0f, 0.0f);
		csound = new Csound(); //Create an instance of Csound
		csound->SetMessageCallback(messageCallback);	
	}

	~Flooper() {
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
	
	void loadSample(std::string path);


	// persistence
	json_t *dataToJson() /*override*/ {
		json_t *rootJ = json_object();
		// lastPath
		json_object_set_new(rootJ, "lastPath", json_string(lastPath.c_str()));	
		return rootJ;
	}

	void dataFromJson(json_t *rootJ) /*override*/ {
		// lastPath
		json_t *lastPathJ = json_object_get(rootJ, "lastPath");
		if (lastPathJ) {
			lastPath = json_string_value(lastPathJ);
			loadSample(lastPath);
		}
	}
};

void Flooper::onAdd() {
	notReady = true;
	if (csound) {
		dispose();
	}
	csound = new Csound(); //Create an instance of Csound
	csound->SetMessageCallback(messageCallback);	
	csoundSession();
}

void Flooper::onRemove() {
	dispose();
}

void Flooper::onSampleRateChange() {
	//csound restart with new sample rate
	reset();
};

void Flooper::onReset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	reset();
}

void Flooper::reset() {
	//menu initialize: csound restart with modified (or not!) csound script csd
	notReady = true;
	if (csound != NULL) csound->Reset();
	csoundSession();
}

void Flooper::dispose() {
	notReady = true;
	if (csound) {
		csound = NULL;
		spin = NULL;
		spout = NULL;
	}
}

void Flooper::loadSample(std::string path) {
	filePath = path;
	lastPath = path;
	reset();
};

void Flooper::process(const ProcessArgs& args) {
	
	MYFLT out=0.0;

	if(notReady) return;            //output set to zero

	//Process
	
	if(nbSample == 0)   //param refresh at control rate
	{
		//params
		if(inputs[START_INPUT].isConnected()) {
			start = clamp(inputs[START_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
		} else {
			start = params[START_PARAM].getValue();
		};

		if(inputs[END_INPUT].isConnected()) {
			end = clamp(inputs[END_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
		} else {
			end = params[END_PARAM].getValue();
		};

		if(inputs[TRANSPOSE_INPUT].isConnected()) {
			transpose = clamp(inputs[TRANSPOSE_INPUT].getVoltage(), 0.0f, 10.0f) * 2.4f - 12.0f;
		} else {
			transpose = params[TRANSPOSE_PARAM].getValue();
		};
		
		gate = clamp(inputs[GATE_INPUT].getVoltage(), 0.0f, 10.0f) * 0.1f;
		loop = params[LOOP_PARAM].getValue();

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
	outputs[OUT_OUTPUT].setVoltage(out*5.0);
}

struct FlooperDisplay : TransparentWidget {			//code from Clement Foulc player module
	Flooper *module;
	shared_ptr<Font> font;

	FlooperDisplay() {
		font = APP->window->loadFont(asset::system("res/fonts/DejaVuSans.ttf"));
	}

	void draw(const DrawArgs& args) override {
		
		if (module) {
			
			nvgFontSize(args.vg, 12);
			nvgFontFaceId(args.vg, font->handle);
			nvgTextLetterSpacing(args.vg, 1);
			nvgFillColor(args.vg, nvgRGBA(0xff, 0xff, 0x3e, 0xff));                  //text color
			nvgTextBox(args.vg, 10, 15, 120, module->fileDesc.c_str(), NULL);

			nvgStrokeColor(args.vg, nvgRGBA(0xff, 0xff, 0xff, 0x40));                //line color

			int offset = 5;
			int start = offset + (module->start) * 160;
			int end   = offset + (module->end)   * 160;
			int samplePos = offset + (module->samplePos) * 160;
			
			// Draw ref line
			{
				nvgBeginPath(args.vg);
				nvgMoveTo(args.vg, 5, 90);
				nvgLineTo(args.vg, 165, 90);
				nvgClosePath(args.vg);
			}
			nvgStroke(args.vg);
			// Draw Start line
			{
				nvgBeginPath(args.vg);
				nvgMoveTo(args.vg, start, 70);
				nvgLineTo(args.vg, start, 110);
				nvgClosePath(args.vg);
			}
			nvgStroke(args.vg);
			// Draw End line
			{
				nvgBeginPath(args.vg);
				nvgMoveTo(args.vg, end, 70);
				nvgLineTo(args.vg, end, 110);
				nvgClosePath(args.vg);
			}
			nvgStroke(args.vg);
			
			if (module->notReady == false) {
				// Draw play line
				nvgStrokeColor(args.vg, nvgRGBA(0x28, 0xb0, 0xf3, 0xff));
				nvgStrokeWidth(args.vg, 0.8);
				{
					nvgBeginPath(args.vg);
					nvgMoveTo(args.vg, samplePos, 70);
					nvgLineTo(args.vg, samplePos, 110);
					nvgClosePath(args.vg);
				}
				nvgStroke(args.vg);

				// Draw waveform
				nvgStrokeColor(args.vg, nvgRGBA(0xff, 0xff, 0x3e, 0xff));				//wave color
				nvgSave(args.vg);
				Rect b = Rect(Vec(5, 75), Vec(160, 30));
				nvgScissor(args.vg, b.pos.x, b.pos.y, b.size.x, b.size.y);
				nvgBeginPath(args.vg);

				for (unsigned int i = 0; i < module->displayBuff.size(); i++) {
					float x, y;
					x = (float)i / (module->displayBuff.size() - 1);
					y = module->displayBuff[i] / 2.0 + 0.5;
					Vec p;
					p.x = b.pos.x + b.size.x * x;
					p.y = b.pos.y + b.size.y * (1.0 - y);
					if (i == 0)
						nvgMoveTo(args.vg, p.x, p.y);
					else
						nvgLineTo(args.vg, p.x, p.y);
				}

				nvgLineCap(args.vg, NVG_ROUND);
				nvgMiterLimit(args.vg, 2.0);
				nvgStrokeWidth(args.vg, 0.5);
				//nvgGlobalCompositeOperation(args.vg, NVG_LIGHTER);
				nvgStroke(args.vg);			
				nvgResetScissor(args.vg);
				nvgRestore(args.vg);	
			}
		}
	}
};

struct FlooperItem : MenuItem {
	Flooper *player;
	void onAction(const event::Action &e) override {
		//std::string dir = asset::user("/plugins/VCV_Csound/samples");
		
		std::string dir = asset::plugin(pluginInstance, "samples/");
		cout << "dir: " << dir << endl;
		
		char *path = osdialog_file(OSDIALOG_OPEN, dir.c_str(), NULL, NULL);
		cout << "path: " << path << endl;
		
		if (path) player->loadSample(path);
    	free(path);
	}
};

struct FlooperWidget : ModuleWidget {
	FlooperWidget(Flooper *module);
	void appendContextMenu(Menu* menu) override;
};

FlooperWidget::FlooperWidget(Flooper *module) {
	setModule(module);
	setPanel(APP->window->loadSvg(asset::plugin(pluginInstance, "res/Flooper.svg")));

	{
		FlooperDisplay *display = new FlooperDisplay();
		display->module = module;
		display->box.pos = Vec(5, 40);
		display->box.size = Vec(130, 250);
		addChild(display);
	}

	addChild(createWidget<ScrewSilver>(Vec(15, 0)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 0)));
	addChild(createWidget<ScrewSilver>(Vec(15, 365)));
	addChild(createWidget<ScrewSilver>(Vec(box.size.x-30, 365)));

	addParam(createParam<csKnob>(Vec(45, 179), module, Flooper::START_PARAM));
	addParam(createParam<csKnob>(Vec(135, 179), module, Flooper::END_PARAM));
	addParam(createParam<csKnob>(Vec(135, 239), module, Flooper::TRANSPOSE_PARAM));
	addParam(createParam<csBefacoSwitch>(Vec(52, 241), module, Flooper::LOOP_PARAM));

	addInput(createInput<VcInPort>(Vec(10, 184), module, Flooper::START_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 184), module, Flooper::END_INPUT));
	addInput(createInput<VcInPort>(Vec(100, 244), module, Flooper::TRANSPOSE_INPUT));
	addInput(createInput<VcInPort>(Vec(33, 297), module, Flooper::GATE_INPUT));

	addOutput(createOutput<AudioOutPort>(Vec(121, 297), module, Flooper::OUT_OUTPUT));
}

void FlooperWidget::appendContextMenu(Menu* menu) {
	MenuLabel *spacerLabel = new MenuLabel();
	menu->addChild(spacerLabel);

	Flooper *player = dynamic_cast<Flooper*>(this->module);
	assert(player);

	FlooperItem *sampleItem = new FlooperItem();
	sampleItem->text = "Load sample";
	sampleItem->player = player;
	menu->addChild(sampleItem);
}

Model *modelFlooper = createModel<Flooper, FlooperWidget>("Csound_Looper");