from color import random_color, random_color_range
from HelperFunctions import one_in

class Tree_Test(object):
	def __init__(self, treemodel):
		self.name = "Tree_Test"
		self.tree = treemodel
		self.speed = 0.5
		self.color = random_color()

	def next_frame(self):
		while (True):

			self.tree.set_all_cells(self.color)

			# Change the colors
			if one_in(10):
				self.color = random_color_range(self.color, 0.02)

			yield self.speed