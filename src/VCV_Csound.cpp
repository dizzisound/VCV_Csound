#include "VCV_Csound.hpp"

Plugin *pluginInstance;

void init(rack::Plugin *p) {
	
	pluginInstance = p;

	p->addModel(modelReverb);
	p->addModel(modelChorus);
	p->addModel(modelVocoder);
	p->addModel(modelMidiVCO10);
	p->addModel(modelVCO10);
	p->addModel(modelFlooper);
	p->addModel(modelYfx);
	p->addModel(modelDelay);
}
