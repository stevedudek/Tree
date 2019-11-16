from random import randint
from math import pi
from HelperFunctions import one_in, up_or_down, calc_packet, change_hue, min_dim


class Radar(object):
    def __init__(self, treemodel):
        self.name = "Radar"
        self.tree = treemodel
        self.speed = 0.1
        self.freq = randint(1, 4)
        self.thresh = 200
        self.count = 0
        self.hue = randint(0, 256)
        self.two_pi = 2 * pi

    def next_frame(self):
        while True:
            angle = self.two_pi * (self.count % 360) / 360
            for pixel in self.tree.all_pixels():
                angle_diff = self.two_pi - abs(angle - pixel.theta)
                value = calc_packet(angle_diff, self.two_pi, fract_x=0.5, smooth=True)
                pixel.set_color((self.hue, 255, min_dim(value)))

            self.hue = change_hue(self.hue)  # Change the colors

            if one_in(50):
                self.freq = up_or_down(self.freq, 1, 1, 4)

            self.count += self.freq

            yield self.speed

