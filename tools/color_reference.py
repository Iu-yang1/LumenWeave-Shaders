"""Reference values for the scene-linear Overworld display chart."""

import argparse

SWATCHES = tuple((value,) * 3 for value in (0, 0.01, 0.04, 0.18, 0.50, 1, 2, 4, 8)) + (
    (4, 0.10, 0.04),
)
LUMA = (0.2126, 0.7152, 0.0722)


def decode_srgb(encoded):
    if encoded <= 0.04045:
        return encoded / 12.92
    return ((encoded + 0.055) / 1.055) ** 2.4


def encode_srgb(linear):
    if linear <= 0.0031308:
        return linear * 12.92
    return 1.055 * linear ** (1 / 2.4) - 0.055


def display_color(radiance, ev=0):
    exposed = tuple(max(channel, 0) * 2**ev for channel in radiance)
    brightness = sum(channel * coefficient for channel, coefficient in zip(exposed, LUMA))
    mapped = brightness / (1 + brightness)
    color = tuple(channel / (1 + brightness) for channel in exposed)
    peak = max(color)
    if peak > 1:
        scale = (1 - mapped) / (peak - mapped)
        color = tuple(mapped + (channel - mapped) * scale for channel in color)
    return tuple(encode_srgb(min(max(channel, 0), 1)) for channel in color)


def chart_rgb8(ev):
    return [tuple(round(255 * channel) for channel in display_color(swatch, ev)) for swatch in SWATCHES]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ev", type=int, default=0)
    args = parser.parse_args()
    print("swatch,red,green,blue")
    for index, sample in enumerate(chart_rgb8(args.ev)):
        print(index, *sample, sep=",")


if __name__ == "__main__":
    main()
