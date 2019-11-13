from color import random_color, random_color_range

from HelperFunctions import Faders, Branch, get_reasonable_speed


class MultipleBranches(object):
    def __init__(self, treemodel):
        self.name = "MultipleBranches"
        self.tree = treemodel
        self.speed = 0.2
        self.color = random_color()
        self.branches = list()  # array of branches
        self.faders = Faders(self.tree)

    def next_frame(self):

        self.tree.clear()

        while True:

            if not self.branches:
                self.color = random_color_range(self.color, shift_range=0.05)
                tree_speed = get_reasonable_speed()
                self.branches = [Branch(self.tree, self.color, tree_speed, start_center=True) for _ in range(3,6)]

            for branch in self.branches:
                for _ in range(branch.tree_speed):
                    self.faders.add_fader(branch.color, branch.get_coord(), intense=1.0, growing=False, change=0.05)
                    if not branch.move_tree():
                        self.branches.remove(branch)
                        break

            self.faders.cycle_faders()

            yield self.speed

