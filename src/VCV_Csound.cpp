#include "VCV_Csound.hpp"

Plugin *plugin;

void init(rack::Plugin *p) {
	plugin = p;

	p->slug     = TOSTRING(SLUG);
	p->version  = TOSTRING(VERSION);

    p->website = "http://csound.com";
    p->manual  = "http://csound.com/docs/manual/index.html";

	p->addModel(modelReverb);
	p->addModel(modelVocoder);
	p->addModel(modelMidiVCO10);
	p->addModel(modelVCO10);
	p->addModel(modelFlooper);
	p->addModel(modelYfx);
	p->addModel(modelDelay);
	p->addModel(modelChorus);
}

