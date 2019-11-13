from color import random_color, random_color_range

from HelperFunctions import Faders, Branch, one_in, get_reasonable_speed


class OutwardBranch(object):
    def __init__(self, treemodel):
        self.name = "OutwardBranch"
        self.tree = treemodel
        self.speed = 0.2
        self.color = random_color()
        self.branches = list()  # array of branches
        self.faders = Faders(self.tree)

    def next_frame(self):

        self.tree.clear()

        while True:

            if one_in(4):
                self.branches.append(Branch(self.tree,
                                            random_color_range(self.color, shift_range=0.1),
                                            tree_speed=get_reasonable_speed(),
                                            start_center=True))

            for branch in self.branches:
                for _ in range(branch.tree_speed):
                    self.faders.add_fader(branch.color, branch.get_coord(), intense=1.0, growing=False, change=0.02)
                    if not branch.move_tree():
                        self.branches.remove(branch)
                        break

            self.faders.cycle_faders()

            yield self.speed

