"""
Reworking LED code to use a Pixel class

A LED-contraption object, like a Tree, is composed of Pixel objects
A Pixel knows its color, state, current frame, and next frame
"""

from math import atan, sqrt, pi


class Pixel(object):
    """Pixel colors are hsv [0-255] triples (very simple)"""
    def __init__(self, coord, id, number, gen, fract, x, y):
        self.coord = coord
        self.number = number
        self.id = id
        self.gen = gen
        self.fract = fract  # 0.0 - 1.0
        self.x = (x - 12250) / 12249.0  # 0.0 - 1.0 from min -12249, max 12157
        self.y = (y - 10007) / 11438.0  # 0.0 - 1.0 from min -10007, max 11438
        self.d = sqrt((self.x * self.x) + (self.y * self.y)) / sqrt(2)  # 0.0 - 1.0
        self.theta = self.get_angle()
        self.curr_frame = (0,255,0)  # Always make saturation = 255
        self.next_frame = (0,255,0)  # Always make saturation = 255

    def get_angle(self):
        """Get the 0-2pi angle from the x,y coordinate. arctans are weird."""
        if self.y == 0:
            angle = 0 if self.x > 0 else pi
        else:
            angle = atan(self.x / self.y)

        if self.y >= 0:
            if self.x < 0:
                angle += (2 * pi)
        else:
            angle += pi

        return angle

    def get_coord(self):
        return self.x, self.y

    def get_number(self):
        return self.number

    def get_next_color(self):
        return self.next_frame

    def has_changed(self):
        return not (self.curr_frame[0] == self.next_frame[0] and
                    self.curr_frame[1] == self.next_frame[1] and
                    self.curr_frame[2] == self.next_frame[2])

    def set_color(self, color):
        self.next_frame = color

    def set_next_frame(self, color):
        self.next_frame = color

    def set_curr_frame(self, color):
        self.curr_frame = color

    def set_black(self):
        self.next_frame = (0,255,0)  # Always make saturation = 255

    def force_black(self):
        self.curr_frame = (0,255,1)  # Always make saturation = 255
        self.set_black()

    def update_frame(self):
        self.set_curr_frame(color=self.next_frame)