from color import random_color, random_color_range, randint

from HelperFunctions import Faders, Branch, one_in

class InOutBranches(object):
    def __init__(self, treemodel):
        self.name = "InOutBranches"
        self.tree = treemodel
        self.speed = 0.1
        self.tree_speed = randint(1, 4)
        self.color = random_color()
        self.branches = list()  # array of branches
        self.faders = Faders(self.tree)

    def next_frame(self):

        self.tree.clear()

        while True:

            if one_in(4):
                self.branches.append(Branch(self.tree,
                                            random_color_range(self.color, shift_range=0.05),
                                            tree_speed=self.tree_speed,
                                            start_center=False))

            for branch in self.branches:
                for _ in range(branch.tree_speed):
                    self.faders.add_fader(branch.color, branch.get_coord(), intense=1.0, growing=False, change=0.1)
                    if not branch.move_tree():
                        if not branch.moving_outward:
                            self.branches.append(Branch(self.tree,
                                                        branch.color,
                                                        tree_speed=self.tree_speed,
                                                        start_center=True))
                        self.branches.remove(branch)
                        break

            self.faders.cycle_faders()

            yield self.speed

