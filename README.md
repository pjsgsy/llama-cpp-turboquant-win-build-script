Full build script for my Win11/VisualStudio/CUDA12.9 setup and Tom's llama fork with turboquant support from here https://github.com/TheTom/llama-cpp-turboquant

I had a fair few issues trying to build this and had to employ some agentic assistance!  
I figured I would share the script in case anyone else on Win wanted to try this, but got
overwhelmed by building from source.

This script will fetch/update the source directly from Tom's GitHub and compile, so it is an all-in-one build from nothing script.
I have Visual studio 2022 & Insiders edition installed on My Win11 machine, as well as the Cuda 12 toolkit/developers kit.
You should be able to just run it and update at any time when the author updates their source.
It will possibly take an hour or more for the first build, if you are hardware-constrained, like me! (a good time to have a good coffee supply...)
Attempts to check for some prerequisites first. You need Git, CMake, VS, CUDA, etc. You likely (hopefully have all these).

My hardware GPU is Ampere, but this script should auto-detect. Mine is just sm_86

Good luck.

