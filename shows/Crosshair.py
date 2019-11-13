from random import randint
from HelperFunctions import calc_packet, get_bpm_wave, get_reasonable_bpm, change_hue


class Crosshair(object):
    def __init__(self, treemodel):
        self.name = "Crosshair"
        self.tree = treemodel
        self.speed = 0.2
        self.x_bpm = get_reasonable_bpm() / 3.0
        self.y_bpm = get_reasonable_bpm() / 3.0
        self.x_hue = randint(0, 256)
        self.y_hue = randint(0, 256)
        self.reverse = True

    def next_frame(self):

        while True:
            x_wave = (get_bpm_wave(self.x_bpm) * 2) - 1
            y_wave = (get_bpm_wave(self.y_bpm) * 2) - 1

            for pixel in self.tree.all_pixels():
                inverse_distance = 1.0 - abs(pixel.x - x_wave)
                x_value = calc_packet(inverse_distance, 1.0, fract_x=0.8, smooth=True)

                inverse_distance = 1.0 - abs(pixel.y - y_wave)
                y_value = calc_packet(inverse_distance, 1.0, fract_x=0.8, smooth=True)

                if x_value > y_value:
                    pixel.set_color((self.x_hue, 255, x_value))
                else:
                    pixel.set_color((self.y_hue, 255, y_value))

            # Change the colors
            self.x_hue = change_hue(self.x_hue, rate=5)
            self.y_hue = change_hue(self.y_hue, rate=10)

            yield self.speed
