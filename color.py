import colorsys
from random import random, randint

"""
Color

JULY 2019

REWROTE and SIMPLIFIED
1. Make HSV [0-255]
2. Colors are now just triples of (hue, sat, value)

JULY 2019
Consider rewriting this API to use less memory
Remove unused functions
Try to keep the surrounding API
"""


def _float_to_byte(f):
    """Convert a [0.0-1.0] float to a [0-255] byte"""
    return int(f * 255) % 256


def _float_to_byte_triple(triple):
    """Convert 3 [0.0-1.0] floats to 3 [0-255] bytes"""
    return _float_to_byte(triple[0]), _float_to_byte(triple[1]), _float_to_byte(triple[2]) 

    
def _byte_to_float(b):
    """Convert a [0-255] byte to a [0.0-1.0] float"""
    return (int(b) % 256) / 255.0


def _byte_to_float_triple(triple):
    """Convert 3 [0-255] bytes to 3 [0.0-1.0] floats"""
    return _byte_to_float(triple[0]), _byte_to_float(triple[1]), _byte_to_float(triple[2])


def rgb_to_hsv(rgb):
    """convert a rgb[0-255] tuple to hsv[0-255]"""
    _r, _g, _b = _byte_to_float_triple(rgb)
    return _float_to_byte_triple(colorsys.rgb_to_hsv(_r, _g, _b))


def hsv_to_rgb(hsv):
    """convert a hsv[0-255] tuple to rgb[0-255]"""
    _h, _s, _v = _byte_to_float_triple(hsv)
    return _float_to_byte_triple(colorsys.hsv_to_rgb(_h, _s, _v))


def random_color(reds=False):
    """return a random, saturated hsv color. reds are 192-32"""
    _hue = randint(192, 287) % 255 if reds else randint(0, 255)
    return _hue, 255, 255


def random_color_range(hsv, shift_range=0.3):
    """Returns a random color around a given color within a particular range
       Function is good for selecting blues, for example"""
    _delta_h = (random() - 0.5) * min([0.5, shift_range]) * 2
    _new_h = _float_to_byte( _byte_to_float(hsv[0]) + _delta_h)
    return _new_h, hsv[1], hsv[2]


def gradient_wheel(hsv, intensity):
    """Dim an hsv color with v=intensity [0.0-1.0]"""
    intensity = max([min([intensity, 1]), 0])
    return hsv[0], hsv[1], _float_to_byte(intensity)


def change_color(hsv, amount):
    """Change color by a 0.0-1.0 range. Amount can be negative"""
    return (hsv[0] + _float_to_byte(amount)), hsv[1], hsv[2]


def restrict_color(hsv, hue, hue_range=0.05):
    """restrict a color with 0-1.0 starting hue to hue +/- range. Use this to set reds, blues, etc."""

    # red = 0.0
    # orange = 0.083
    # yellow = 0.17
    # green = 0.29
    # light blue = 0.5
    # dark blue = 0.58
    # blue purple = 0.66
    # purple = 0.79
    # red purple = 0.92

    hue_range = _float_to_byte(min[(hue_range, 0.5)])
    _new_h = (hue - hue_range) + (hsv[0] * 2 * hue_range)
    return _new_h % 255, hsv[1], hsv[2]


def dim_color(hsv, amount):
    """dim an hsv color by a 0-1.0 range"""
    amount = max([min([amount, 1]), 0])
    return hsv[0], hsv[1], int(hsv[2] * amount)
