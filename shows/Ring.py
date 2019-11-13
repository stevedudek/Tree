from random import randint
from HelperFunctions import calc_packet, get_bpm_circle, get_reasonable_bpm, get_reasonable_speed, get_true_or_false, \
    change_hue


class Ring(object):
    def __init__(self, treemodel):
        self.name = "Ring"
        self.tree = treemodel
        self.speed = 0.2
        self.bpm = get_reasonable_bpm()
        self.count = 0
        self.reverse_count = get_reasonable_speed()
        self.hue = randint(0, 256)
        self.reverse = get_true_or_false()

    def next_frame(self):

        while True:
            wave = get_bpm_circle(self.bpm)
            if self.reverse:
                wave = 1.0 - wave
            for pixel in self.tree.all_pixels():
                inverse_distance = 1.0 - abs(pixel.d - wave)
                value = calc_packet(inverse_distance, 1.0, fract_x=0.6, smooth=True)
                pixel.set_color((self.hue, 255, value))

            self.hue = change_hue(self.hue)  # Change the colors

            self.count += 1
            yield self.speed
