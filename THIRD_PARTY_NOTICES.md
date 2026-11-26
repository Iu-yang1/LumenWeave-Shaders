# Third-party notices

LumenWeave's shader code and voxel experiment are independently implemented.
Release archives contain LumenWeave shader source, original generated lookup textures and GNU license texts. They do not bundle third-party shaders, game files, or tool binaries. The developer branch retains generation tools and experiments.

- Javier Garduño's [MakeUp Ultra Fast 9.6a](https://github.com/javiergcim/MakeUpUltraFast/tree/65c3ac0818120c97d2b7ad6686b3318f5c14f24e)
  is the audited pipeline reference. Its repository carries LGPL-3.0.
- [Iris](https://github.com/IrisShaders/Iris) is a separately installed loader.
  The preview uses its published shader-pack interface.
- [BSL Shaders](https://modrinth.com/shader/bsl-shaders) is a visual reference.
- [Rethinking Voxels](https://github.com/gri573/rethinking-voxels) is a research
  reference for colored flood-fill lighting.

- [Photon](https://github.com/sixthsurge/photon/tree/2a3d502c17d2e310412c717be47241f014cba7fc) is an architectural reference for atmospheric lookup tables, clouds and light shafts.
- Sébastien Hillaire, [A Scalable and Production Ready Sky and Atmosphere Rendering Technique](https://doi.org/10.1111/cgf.14050), Computer Graphics Forum, 2020, is a reference for decomposed atmospheric LUTs.
- The shipped cloud, atmospheric, End and optional water lookup assets are generated from LumenWeave's own models by tools on `develop`.

- Natural environment V1: original water-wave, weather, exposure, depth-of-field and solar-glare implementation inspired by MakeUp 9.6a (pinned above) and the visual appearance of [SEUS Renewed](https://www.sonicether.com/seus/). No code or texture assets copied from SEUS.
