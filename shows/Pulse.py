from random import randint
from math import sin, pi
from HelperFunctions import get_bpm_circle, get_reasonable_bpm, get_true_or_false, change_hue


class Pulse(object):
    def __init__(self, treemodel):
        self.name = "Pulse"
        self.tree = treemodel
        self.speed = 0.2
        self.bpm = get_reasonable_bpm()
        self.count = 0
        self.reverse_count = randint(100, 1000)
        self.hue = randint(0, 256)
        self.reverse = get_true_or_false()

    def next_frame(self):
        while True:
            wave = get_bpm_circle(self.bpm)
            if self.reverse:
                wave = 1.0 - wave
            for pixel in self.tree.all_pixels():
                fract = (pixel.fract + wave) % 1.0
                # ToDo: some sort of sinewave squisher
                value = 255 * (1 + sin(fract * pi)) / 2
                pixel.set_color((self.hue, 255, value))

                self.hue = change_hue(self.hue)  # Change the colors

            if self.count % self.reverse_count == 0:
                self.reverse = not self.reverse

            self.count += 1
            yield self.speed



