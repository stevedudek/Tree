"""
Model to communicate with a Tree simulator over a TCP socket

"""
import socket
from color import hsv_to_rgb
from HelperFunctions import byte_clamp


class SimulatorModel(object):
    def __init__(self, hostname, channel, port=4444):
        self.server = (hostname, port)
        self.channel = channel  # Which of 2 channels
        self.debug = False
        self.sock = None
        self.dirty = {}  # { coord: color } map to be sent on the next call to "go"
        self.connect()

    def connect(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect(self.server)

    def __repr__(self):
        return "Tree Model Channel {} ({}, port={}, debug={})".format(self.channel,
                                                                      self.server[0],
                                                                      self.server[1],
                                                                      self.debug)

    def get_channel(self):
        return self.channel

    # Model basics

    def set_cell(self, cell, color):
        """Set the model's coord to a color"""
        self.dirty[cell] = color

    def go(self):
        """Send all of the buffered commands"""
        self.send_start()
        for (cell, color) in self.dirty.items():
            # h, s, v = byte_clamp(color[0], wrap=True), byte_clamp(color[1]), byte_clamp(color[2])
            r, g, b = hsv_to_rgb((byte_clamp(color[0], wrap=True), byte_clamp(color[1]), byte_clamp(color[2])))
            # msg = "{}{},{},{},{}".format(self.channel, cell, h,s,b)
            msg = "{}{},{},{},{}".format(self.channel, cell, r, g, b)

            if self.debug:
                print (msg)
            self.sock.send(msg)
            self.sock.send('\n')

        self.dirty = {}  # Restart the dirty dictionary

    def send_start(self):
        """send a start signal"""
        msg = "{}X".format(self.channel)  # tell processing that commands are coming

        if self.debug:
            print (msg)
        self.sock.send(msg)
        self.sock.send('\n')

    def send_delay(self, delay):
        """send a morph amount in milliseconds"""
        msg = "{}D{}".format(self.channel, str(int(delay * 1000)))

        if self.debug:
            print (msg)
        self.sock.send(msg)
        self.sock.send('\n')

    def send_intensity(self, intensity):
        """send an intensity amount (0-255)"""
        msg = "{}I{}".format(self.channel, str(intensity))

        if self.debug:
            print (msg)
        self.sock.send('\n')
        self.sock.send(msg)
        self.sock.send('\n')
