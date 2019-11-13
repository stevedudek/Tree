from random import randint
from HelperFunctions import calc_packet, get_bpm_circle, get_reasonable_bpm, get_reasonable_speed, get_true_or_false, \
    change_hue


class Pulse2(object):
    def __init__(self, treemodel):
        self.name = "Pulse2"
        self.tree = treemodel
        self.wave_max = self.tree.MAX_GENERATIONS + 1
        self.speed = 0.1
        self.bpm = get_reasonable_bpm()
        self.count = 0
        self.reverse_count = get_reasonable_speed()
        self.hue = randint(0, 256)
        self.reverse = get_true_or_false()

    def next_frame(self):
        while True:
            wave = get_bpm_circle(self.bpm) * self.wave_max
            if self.reverse:
                wave = self.wave_max - wave
            for pixel in self.tree.all_pixels():
                inverse_distance = self.wave_max - abs((pixel.fract + pixel.gen) - wave)
                value = calc_packet(inverse_distance, self.wave_max, fract_x=0.8, smooth=True)
                pixel.set_color((self.hue, 255, value))

            self.hue = change_hue(self.hue)  # Change the colors

            self.count += 1
            yield self.speed



