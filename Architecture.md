# Architecture

The stimulus views really don't need to know anything about where the user's face is, or anything about spatial awareness. They really just need to know how to control the things they are displaying. So, for the dot that means two things: "is the stimulus active?", and "how fast should it be moving in terms of pixels per second?". 

So here are the components and what they emit and consume:

Spatial module - emits spatial transforms, frame images, and "face detected" flag

Stimulus module - consumes stimulus-control information and emits stimulus-position information.

Test module - consumes the spatial information from the spatial module, transforms that into stimulus-position information for the stimulus module.

Recorder module - consumes spatial information from the spatial module, consumes stimulus-position information from the stimulus module, and writes the information to disk.

Frame-mapping module - the spatial module and stimulus module both produce data at 60hz (hopefully), but their frames are not synchronized - ideally there is some fixed offset between the time a spatial frame is rendered and the next stimulus frame is rendered. However, this time may not be constant, and either way, we need to create "reconciled" or "mapped" frames that either say "for this spatial frame here is where the stimulus was", or "for this stimulus frame here is the corresponding spatial info", or "for this virtual frame, whose timestamp does not match either frame, here is the spatial and stimulus data". It probably makes the most sense to map stimulus frames onto spatial frames since the stimulus actually doesn't move between stimulus frames, but the user's head does move between spatial frames. So we will probably be able to make a much better guess as to where the stimulus was on the screen than we will be able to interpolate head position. 
