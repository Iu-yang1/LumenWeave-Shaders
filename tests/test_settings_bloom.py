import sys
import unittest
from collections import Counter
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from check_shaders import menu_options,preview_profiles
from compatibility import TARGETS,adapt_members
from package import PREVIEW,shader_members


class SettingsBloomTests(unittest.TestCase):
    def test_unique_menu_ownership_and_locales(self):
        rows=(PREVIEW/"shaders.properties").read_text().splitlines()
        config=dict(tuple(part.strip() for part in row.split("=",1))
                    for row in rows if row.startswith("screen") and "=" in row)
        options,_=menu_options(config)
        counts=Counter(token for key,value in config.items() if not key.endswith(".columns")
                       for token in value.split() if token in options)
        self.assertEqual(set(counts),options)
        self.assertTrue(all(count==1 for count in counts.values()))
        self.assertIn("[GLOW]",config["screen"])
        self.assertIn("[REFLECTIONS]",config["screen"])
        self.assertIn("LOCAL_GLOW_STRENGTH",config["screen.GLOW"])
        self.assertIn("BLOOM_FILTER",config["screen.BLOOM_SETTINGS"])
        self.assertIn("GI_REUSE_MODE",config["screen.TEMPORAL_SETTINGS"])
        sliders=next(row.split("=",1)[1].split() for row in rows if row.startswith("sliders ="))
        self.assertEqual(len(sliders),len(set(sliders)))
        self.assertTrue(set(sliders)<=options)
        for locale in ("zh_cn","en_us"):
            text=(PREVIEW/f"lang/{locale}.lang").read_text()
            for key in ("screen.GLOW","screen.TEMPORAL_SETTINGS","option.BLOOM_FILTER.comment",
                        "value.BLOOM_FILTER.0","value.BLOOM_FILTER.1","value.BLOOM_FILTER.2"):
                self.assertIn(key+"=",text)

    def test_profile_defaults_and_switch(self):
        profiles=preview_profiles(PREVIEW)
        expected={"Potato":("false","0","0.04"),"Low":("false","0","0.04"),
                  "Medium":("true","0","0.04"),"High":("true","1","0.08"),
                  "Ultra":("true","1","0.08"),"Extreme":("true","1","0.12")}
        for name,settings in expected.items():
            profile=profiles["profile."+name]
            self.assertEqual(tuple(profile[k] for k in ("BLOOM","BLOOM_FILTER","BLOOM_STRENGTH")),settings)
        for profile in profiles.values():
            self.assertEqual(tuple(profile[k] for k in ("EMISSION_STRENGTH","LOCAL_GLOW_STRENGTH","DARK_AMBIENT")),
                             ("1.5","1.7","0.65"))
            self.assertEqual(profile["GI_REUSE_MODE"],"1")
            self.assertEqual(profile["BLOOM_THRESHOLD"],"1.5")

    def test_all_version_packs_same_settings(self):
        original=shader_members(PREVIEW)
        for target in TARGETS:
            pack=adapt_members(original,target)
            for name in ("shaders/shaders.properties","shaders/lang/en_us.lang",
                         "shaders/lang/zh_cn.lang","shaders/lib/quality.glsl"):
                self.assertEqual(pack[name],original[name],(target,name))

    def test_bloom_constant_field_and_weights(self):
        # Normalized filters preserve uniform HDR radiance and hue.
        weights=((1.,),(.25,)*4,tuple((2-abs(x))*(2-abs(y))/16
                                     for y in range(-1,2) for x in range(-1,2)))
        for kernel in weights:
            self.assertAlmostEqual(sum(kernel),1.)
            for channel in (0.0,.18,1.,12.):
                self.assertAlmostEqual(sum(channel*w for w in kernel),channel)
        final=(PREVIEW/"programs/shared/final.fsh.glsl").read_text()
        extraction=(PREVIEW/"programs/shared/composite3.fsh.glsl").read_text()
        self.assertIn("#if BLOOM_FILTER == 0",final)
        self.assertIn("#if BLOOM_FILTER == 1",final)
        self.assertIn("#if BLOOM_FILTER == 2",extraction)
        self.assertIn("scene+=bloom*BLOOM_STRENGTH",final)
        self.assertIn("0.50*max(sampleColor.r",extraction)
        self.assertIn("/* RENDERTARGETS: 11 */",extraction)
        self.assertIn("const int colortex11Format = RGBA16F",extraction)
