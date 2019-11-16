from random import randrange, randint
from math import sin, pi
from HelperFunctions import get_bpm_wave, get_reasonable_bpm, change_hue, MIN_DIM

class BackForth(object):
    def __init__(self, treemodel):
        self.name = "BackForth"
        self.tree = treemodel
        self.speed = 0.5
        self.bpm = get_reasonable_bpm()
        self.hue = randint(0, 256)
        self.reverse = True

    def next_frame(self):
        while True:
            wave = get_bpm_wave(self.bpm)
            for pixel in self.tree.all_pixels():
                inverse_distance = abs(pixel.fract - wave)
                value = (255 - MIN_DIM) * (1 + sin(inverse_distance * pi)) / 2
                pixel.set_color((self.hue, 255, 255 - value))

            self.hue = change_hue(self.hue)  # Change the colors

            yield self.speed



