from random import randint
from HelperFunctions import change_hue, MIN_DIM

class Light_One_Up(object):
	def __init__(self, treemodel):
		self.name = "Light_One_Up"
		self.tree = treemodel
		self.speed = randint(1,5) * 0.1
		self.size = randint(1, 10)
		self.count = 0
		self.hue = randint(0, 256)

	def next_frame(self):
		# self.hue, self.speed, self.size = 34, 0.90, 2  # This causes flickering
		while True:
			color = (self.hue, 255, 255)
			for pixel in self.tree.all_pixels():
				dist_1 = abs((self.count % 20 / 20.0) - pixel.fract)
				dist_2 = abs((((self.count + self.size) % 20) / 20.0) - pixel.fract)
				if dist_1 < 0.05 or dist_2 < 0.05:
					pixel.set_color(color)
				else:
					pixel.set_color((self.hue, 255, MIN_DIM))

			self.hue = change_hue(self.hue)  # Change the colors

			self.count += 1

			yield self.speed