#!/usr/bin/python3.8

import argparse
import os
#import /home/daniel/.local/lib/python3.8/site-packages/ConfigParser
import configparser
import subprocess
from time import sleep
from zaber.serial import AsciiSerial, AsciiDevice, AsciiCommand


microstep_in_mm=0.000047625
step_max=4199475
no_of_steps_for_mm=20997.375

# Command line parameters 
clparser = argparse.ArgumentParser()
#uncomment the following line to pass the software path to run during pixel calibration
#clparser.add_argument("command", help="command to execute after each movement")
clparser.add_argument("-mmx", "--step_size_x", help="step size [mm]", default=None)
clparser.add_argument("-mmy", "--step_size_y", help="step size [mm]", default=None)
#clparser.add_argument("-scx", "--step_count_x", help="step count x (grid size x)", default=None)
#clparser.add_argument("-scy", "--step_count_y", help="step count y (grid size y)", default=None)
clargs = clparser.parse_args()

def main():
	mmx = clargs.step_size_x
	mmy = clargs.step_size_y
	if mmx is None or mmy is None:
		print("You must specify step sizes! \n")
		print("Example:     move_led_abs.py -mmx 100 -mmy 80")	
		#print "Example:     move_led_abs.py command -mmx 100 -mmy 80"
		return -1
	#if scx is None or scy is None:
		#print "You must specify step counts! \n"
		#print "Example:     move_led_abs.py command -mmx 100 -mmy 80 -scx 2.88 -scy 2.88"	
		#return -1


	mmx=float(mmx)
	mmy=float(mmy)
	
	# Uncomment the lines below to to have a continuous acquisition
	#ssx = int(ssx)
	#ssy = int(ssy)
	#scx=int(scx)
	#scy=int(scy)

	# Setup the engines
	port = AsciiSerial("/dev/ttyUSB0")
	device = AsciiDevice(port, 1)
	device2 = AsciiDevice(port, 2)
	axis1 = device.axis(1)
	axis2 = device2.axis(1)

	mmx_declared = mmx*no_of_steps_for_mm
	mmy_declared = mmy*no_of_steps_for_mm
        #x_step_declared = scx*no_of_steps_for_mm
	#y_step_declared = scy*no_of_steps_for_mm

	movex = int(round(mmx_declared))
	movey = int(round(mmy_declared))
	#x_step = int(round(x_step_declared))
	#y_step = int(round(y_step_declared))
	

	if movex > step_max or movey > step_max:
		print("You are trying to exceed the maximum lenght of 200 mm!")
		return -1

	#print movex
	#print movey
	#print mmx_declared
	#print mmy_declared
	

	axis1.move_rel(movex)
	axis2.move_rel(movey)
	#axis1.send("home")
	#axis2.send("home")


	#for iy in xrange(scy):
	#	# Move to y position
	#	axis2.move_rel(int(round(ssy/microstep_in_mm)))
	#	for ix in xrange(scx):
			# Move to x position
			#axis1.move_rel(int(round(ssx/microstep_in_mm)))
			# Execute command
			#subprocess.call(clargs.command, shell=True)



if __name__ == '__main__':
	main()
