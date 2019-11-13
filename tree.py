"""
Model to communicate with a Tree simulator over a TCP socket

"""
from color import gradient_wheel
from random import choice, randint
from math import sin, cos, pi
from pixel import Pixel

"""
July 2019 Changes
1. Implement Pixel class in place of hash table

Nov 2018 Changes
1. No more fades to black, so removed "fract" variable below
2. Added send_intensity()

Parameters for each Tree: (X, Y)
"""


def load_tree(model):
    return Tree(model)


class Tree(object):
    """
    Tree object (= tree model) represents all LEDs (so all 4 giant tree)
    Each Tree is composed of Pixel objects

    Tree coordinates are stored in a hash table.
    Keys are (r,p,d) coordinate triples
    Values are (strip, pixel) triples
    
    Frames implemented to shorten messages:
    Send only the pixels that change color
    Frames are hash tables where keys are (r,p,d) coordinates
    and values are (r,g,b) colors
    """
    def __init__(self, model):
        """Most below are pseudo-global variable for one-time Tree coordinate determination"""
        # Initial starting coordinate
        self.x = 12250
        self.y = 10007
        self.pixel = 0
        self.angle = 0  # Initial start angle, in radians
        self.cellmap = {}  # dictionary of { coord: pixel object }

        # Constants
        self.NUMBER_TRUNKS = 3
        self.MAX_GENERATIONS = 3
        self.NUMBER_BRANCHES = 2
        self.PIXEL_SIZE = 100  # For scaling the coordinate space

        self._grow_tree()
        # print([(pixel.id, coord) for coord, pixel in self.cellmap.items()])

        self.model = model

    def __repr__(self):
        return "Tree: {} pixels".format(self.num_pixels)

    def all_cells(self):
        """Get all valid coordinates"""
        return self.cellmap.keys()

    def all_pixels(self):
        """Get all pixel objects"""
        return self.cellmap.values()

    def cell_exists(self, coord):
        """True if the coordinate is valid"""
        return coord in self.cellmap

    def get_pixel(self, coord):
        """Get the pixel object associated with the coordinate"""
        return self.cellmap.get(coord)

    def inbounds(self, coord):
        """Is the coordinate inbounds?"""
        # ToDo: Fix!
        return True
        # (x,y) = coord
        # return 0 <= x < self.width and 0 <= y < self.height

    def set_cell(self, coord, color):
        """Set the pixel at coord to color hsv"""
        if self.cell_exists(coord):
            self.get_pixel(coord).set_next_frame(color)
        else:
            print("Can't find coord {}".format(coord))

    def set_pixel(self, pixel, color):
        """Set the pixel to color hsv"""
        pixel.set_next_frame(color)

    def set_cells(self, coords, color):
        """Set the pixels at coords to color hsv"""
        for coord in coords:
            self.set_cell(coord, color)

    def set_all_cells(self, color):
        """Set all cells to color hsv"""
        for pixel in self.all_pixels():
            pixel.set_next_frame(color)

    def black_cell(self, coord):
        """Blacken the pixel at coord"""
        if self.cell_exists(coord):
            self.get_pixel(coord).set_black()

    def black_all_cells(self):
        """Blacken all pixels"""
        for pixel in self.all_pixels():
            pixel.set_black()

    def clear(self):
        """Force all cells to black"""
        for pixel in self.all_pixels():
            pixel.force_black()
        self.go()

    #
    # Sending messages to the model: delay, intensity, frame
    #
    def go(self):
        """Push the frame to the model"""
        self.send_frame()
        self.model.go()

    def send_delay(self, delay):
        """Send the delay signal"""
        self.model.send_delay(delay)

    def send_intensity(self, intensity):
        """Send the intensity signal"""
        self.model.send_intensity(intensity)

    def send_frame(self):
        """If a pixel has changed, send its coord + color, then update the pixel's frame"""
        for pixel in self.all_pixels():
            if pixel.has_changed():
                self.model.set_cell(pixel.id, pixel.get_next_color())
                pixel.update_frame()

    #
    # Setting up the Tree
    #
    def _grow_tree(self):
        """One-time function call to set up tree pixel coordinates"""
        generation = 0
        coord = []

        # Rotate and draw each trunk
        for trunk in range(self.NUMBER_TRUNKS):
            self.angle += (2 * pi / self.NUMBER_TRUNKS)

            old_x, old_y = self.x, self.y  # push matrix
            old_angle = self.angle

            self.draw_pixel_line(coord + [trunk], generation)
            self.draw_branch(coord + [trunk], generation + 1)

            self.x, self.y = old_x, old_y  # pop matrix
            self.angle = old_angle

    def draw_branch(self, coord, gen):
        if gen > self.MAX_GENERATIONS:
            return  # end recursion
        self.angle += pi + ((2 * pi / self.NUMBER_BRANCHES + 1) / 2)  # Trial and error

        for branch in range(self.NUMBER_BRANCHES):
            old_x, old_y = self.x, self.y
            old_angle = self.angle

            self.draw_pixel_line(coord + [branch], gen)  # push matrix
            self.draw_branch(coord + [branch], gen + 1)  # further recursion

            self.x, self.y = old_x, old_y  # pop matrix
            self.angle = old_angle

            self.angle += (2 * pi / 3)

    def get_branch_length(self, generation):
        return self.get_generation_length(generation) * self.PIXEL_SIZE

    def draw_pixel_line(self, coord, gen):
        """Draw a line of pixels, length determined by generation"""
        gen_length = self.get_generation_length(gen)
        for i in range(gen_length):
            self.drop_pixel(coord=coord + [i], i=i, gen=gen, fraction=float(i)/gen_length)
            self.move(self.PIXEL_SIZE)

    @staticmethod
    def get_generation_length(generation):
        return [56, 38, 28, 20][generation]

    def move(self, distance):
        # Move (x,y) distance in the direction of angle
        self.x += (distance * sin(self.angle))
        self.y += (distance * cos(self.angle))

    def drop_pixel(self, coord, i, gen, fraction):
        """Record the current pixel's coordinate as (float x, float y)"""
        self.cellmap[tuple(coord)] = Pixel(coord=tuple(coord),
                                           id=len(self.cellmap),
                                           number=i,
                                           gen=gen,
                                           fract=fraction,
                                           x=self.x,
                                           y=self.y
                                      )
        self.pixel += 1

    @property
    def num_trunks(self):
        return self.NUMBER_TRUNKS

    @property
    def num_branches(self):
        return self.NUMBER_BRANCHES

    @property
    def num_generations(self):
        return self.MAX_GENERATIONS

    @property
    def num_pixels(self):
        return len(self.cellmap)

    def rand_cell(self):
        """Pick a random coordinate"""
        return choice(self.cellmap.keys())
