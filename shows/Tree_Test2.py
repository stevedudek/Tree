from color import random_color, random_color_range

class Tree_Test2(object):
	def __init__(self, treemodel):
		self.name = "Tree_Test2"
		self.tree = treemodel
		self.speed = 0.9  # known flickering color
		self.color = (34, 255, 255)  #random_color() #34  # known flickering color  random_color()
		self.count = 0

	def next_frame(self):

		while (True):
			self.tree.black_all_cells()
			self.tree.set_cell((2,0,0,0,self.count % 20), self.color)

			self.count += 1

			yield self.speed