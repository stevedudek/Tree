from color import random_color, random_color_range
from HelperFunctions import get_reasonable_speed, Faders, one_in


class Sparkles(object):
    def __init__(self, treemodel):
        self.name = "Sparkles"
        self.tree = treemodel
        self.sparkles = Faders(treemodel)
        self.speed = 0.3
        self.color = random_color()
        self.spark_num = self.tree.num_pixels / 20
        self.count = 0

    def next_frame(self):

        self.tree.black_all_cells()

        while True:

            while self.sparkles.num_faders() < self.spark_num:
                self.sparkles.add_fader(color=random_color_range(self.color, 0.05),
                                        pos=self.tree.rand_cell(),
                                        intense=0.01,
                                        growing=True,
                                        change=1.0 / get_reasonable_speed()
                                        )
            self.sparkles.cycle_faders()

            # Change the colors
            if one_in(100):
                self.color = random_color_range(self.color, 0.1)

            self.count += 1

            yield self.speed