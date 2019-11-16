from random import randint, randrange
from color import gradient_wheel, random_color
from math import sqrt, sin, pi
from time import time

#
# Constants
#
MAX_DISTANCE = 12
MAX_COLOR = 1536
MAX_DIR = 8
NUM_PIXELS = 144

MIN_DIM = 64

#
# Common random functions
#
def one_in(chance):
    """Random chance. True if 1 in Number"""
    return randint(1, chance) == 1


def plus_or_minus():
    """Return either 1 or -1"""
    return (randint(0,1) * 2) - 1


def up_or_down(value, amount, min, max):
    """Increase or Decrease a counter with a range"""
    value += (amount * plus_or_minus())
    return bounds(value, min, max)


def get_true_or_false():
    return randint(0, 1) == 1


def inc(value, increase, min, max):
    """Increase/Decrease a counter within a range"""
    value += increase
    return bounds(value, min, max)


def bounds(value, minimum, maximum):
    """Keep value between min and max"""
    return max([minimum, min([value, maximum]) ])


#
# Directions
#
def rand_dir():
    """Get a random direction"""
    return randint(0, MAX_DIR)


def rand_straight_dir():
    return randint(0, 3) * 2


def turn_left(direction):
    """Return the left direction"""
    return (MAX_DIR + direction - 1) % MAX_DIR


def turn_right(direction):
    """Return the right direction"""
    return (direction + 1) % MAX_DIR


def turn_left_or_right(direction):
    """Randomly turn left, straight, or right"""
    return (MAX_DIR + direction + randint(-1, 1)) % MAX_DIR


#
# Colors
#
def rand_color(reds=False):
    """return a random, saturated hsv color. reds are 192-32"""
    _hue = randint(192, 287) % 255 if reds else randint(0, 255)
    return _hue, 255, 255


def byte_clamp(value, wrap=False):
    """Convert value to int and clamp between 0-255"""
    if wrap:
        return int(value) % 255
    else:
        return max([ min([int(value), 255]), 0])


#
# Frequency functions
#
def calc_packet(x, max_x, fract_x=0.8, smooth=True):
    """Convert x, between min_x to max_x to 0-255"""
    assert 0.0 <= fract_x <= 1.0, "{} must be between 0-1".format(x)
    min_x = max_x * fract_x
    if x <= min_x:
        return 0
    if x >= max_x:
        return 255
    fract = float(x - min_x) / (max_x - min_x)
    fract = smooth_interpolation(fract) if smooth else fract
    return int(255 * fract)


def smooth_interpolation(x):
    """Smooth a 0.0-1.0 interpolation by a sine wave"""
    assert 0.0 <= x <= 1.0, "{} must be between 0-1".format(x)
    return sin(x * pi * 0.5)


def get_bpm_circle(bpm):
    """Return a float 0.0-1.0 circle"""
    whole_beat_time = 60.0 / bpm
    return (time() % whole_beat_time) / whole_beat_time


def get_bpm_wave(bpm):
    """Return an oscillating 0.0-1.0 wave"""
    return sin(pi * get_bpm_circle(bpm))


def oscillate(min_x, max_x, bpm):
    """Oscillate at bpm between min_x and max_x"""
    return (get_bpm_circle(bpm) * (max_x - min_x)) + min_x


def get_reasonable_bpm():
    """Set bpm's slow enough to make patterns soothing"""
    return randint(2, 10)  # Check experimentally


def get_reasonable_speed():
    """Set speed slow enough to make patterns soothing"""
    return randint(10, 40)  # Check experimentally


def change_hue(hue, rate=10):
    """Change hue at a reasonable rate"""
    if one_in(rate):
        hue += (randrange(-1, 2) % 256)
    return hue


def min_dim(value):
    """Raise a 0-255 value above MIN_DIM"""
    return int((value * (255 - MIN_DIM) / 255) + MIN_DIM)


#
# Distance Functions
#
def distance(coord1, coord2):
    """Get the cartesian distance between two coordinates"""
    (x1, y1) = coord1
    (x2, y2) = coord2
    return sqrt( (x2-x1)*(x2-x1) + (y2-y1)*(y2-y1) )


#
# Fader class and its collection: the Faders class
#
class Faders(object):
    def __init__(self, treemodel):
        self.tree = treemodel
        self.fader_array = []

    def __del__(self):
        del self.fader_array

    def add_fader(self, color, pos, intense=1.0, growing=False, change=0.25):
        new_fader = Fader(self.tree, color, pos, intense, growing, change)
        self.fader_array.append(new_fader)

    def cycle_faders(self, refresh=True):
        if refresh:
            self.tree.black_all_cells()

        # Draw, update, and kill all the faders
        for f in self.fader_array:
            if f.is_alive():
                f.draw_fader()
                f.fade_fader()
            else:
                f.black_cell()
                self.fader_array.remove(f)

    def num_faders(self):
        return len(self.fader_array)

    def fade_all(self):
        for f in self.fader_array:
            f.black_cell()
            self.fader_array.remove(f)  # Look for a delete object method


class Fader(object):
    def __init__(self, treemodel, color, pos, intense=1.0, growing=False, change=0.25):
        self.tree = treemodel
        self.pos = pos
        self.color = color
        self.intense = intense
        self.growing = growing
        self.decrease = change

    def draw_fader(self):
        self.tree.set_cell(self.pos, gradient_wheel(self.color, self.intense))

    def fade_fader(self):
        if self.growing:
            self.intense += self.decrease
            if self.intense > 1.0:
                self.intense = 1.0
                self.growing = False
        else:
            self.intense -= self.decrease
            if self.intense < 0:
                self.intense = 0

    def is_alive(self):
        return self.intense > 0

    def black_cell(self):
        self.tree.black_cell(self.pos)


class Branch(object):
    def __init__(self, treemodel, color, tree_speed, start_center=True):
        self.tree = treemodel
        self.color = color  # (h,s,v)
        self.tree_speed = tree_speed
        self.coord = self.pick_center() if start_center else self.pick_edge()
        self.moving_outward = start_center

    def pick_center(self):
        """Pick one of the trunks and start there"""
        return [randint(0, self.tree.num_trunks - 1), 0]

    def pick_edge(self):
        """Pick the edge of a branch"""
        coord = [randint(0, self.tree.num_trunks - 1)] + \
                [randint(0, self.tree.num_branches - 1) for _ in range(self.tree.num_generations)] + \
                [self.tree.get_generation_length(self.tree.num_generations) - 1]
        return coord

    def get_coord(self):
        """Get the branch coord"""
        return tuple(self.coord)

    def draw_branch_pixel(self):
        """Draw the single branch pixel"""
        pixel = self.tree.get_pixel(tuple(self.coord))
        assert pixel , "Cannot find a pixel at {}".format(self.coord)
        pixel.set_color(self.color)

    def move_tree(self):
        if self.moving_outward:
            return self.move_tree_outward()
        else:
            return self.move_tree_inward()

    def move_tree_outward(self):
        end_coord = self.get_end_coord()
        end_coord += 1
        if end_coord < self.tree.get_generation_length(self.get_generation()) - 1:
            self.set_end_coord(end_coord)
            return True
        else:
            generation = self.get_generation()
            generation += 1
            if generation < self.tree.num_generations + 1:
                self.set_end_coord(randint(0, self.tree.num_branches - 1))
                self.coord.append(0)
                return True
            return False

    def move_tree_inward(self):
        end_coord = self.get_end_coord()
        end_coord -= 1
        if end_coord > 0:
            self.set_end_coord(end_coord)
            return True
        else:
            generation = self.get_generation()
            generation -= 1
            if generation >= 0:
                self.coord = self.coord[:-1]  # Lop off furthest branch
                self.set_end_coord(self.tree.get_generation_length(self.get_generation()) - 1)
                return True
            return False

    def switch_direction(self):
        self.moving_outward = not self.moving_outward
        self.color = random_color()

    def get_end_coord(self):
        return self.coord[len(self.coord) - 1]

    def set_end_coord(self, value):
        self.coord[len(self.coord) - 1] = value

    def get_generation(self):
        return len(self.coord) - 2

