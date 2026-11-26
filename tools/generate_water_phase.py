#!/usr/bin/env python3
"""Generate optional periodic cosine texture for the water A/B experiment."""
import math
import struct
from pathlib import Path

if __name__=="__main__":
    path=Path(__file__).resolve().parents[1]/"shaders/textures/water_phase.r16f"
    path.write_bytes(b"".join(struct.pack("<e",math.cos(i*2*math.pi/256)) for i in range(257)))
