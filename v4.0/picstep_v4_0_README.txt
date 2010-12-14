PICStep V3.1 Building Instructions
----------------------------------

- Overview and thoughts

Firstly thanks for looking at my design, it was started from the ground up for
the community to share and use. I've released all code and designs under GPL,
which means it's free to use for any purpose as long as my copyright is
retained and any modifications are also released publicly. Any commercial
interest must be approved by ME! :)

PICStep is a micro-stepping step motor controller that uses a special set of
driver ICs (LMD18245) to control the motor coils current to such a degree that
you can divide the magnetic steps of a step motor to 1/2, 1/4 or even 1/8th
their original size! Of course resolution suffers a little in 1/8th mode as not
all steps are mechanically identical from one to another; the difference
is negligible, but the increased smoothness and efficiency is dramatic!

PICStep uses a single layer board and about 30 components and a few wire links
to make it all happen.

The LMD18245 are rated at 55V @ 3amps but I've not tested it up to that range
and there are special requirements that need to be met to deal with back EMF
at this range. I'd suggest reading the LMD18245 data-sheet (which is available
freely on the net') if you wish to use these drivers at or near this voltage.

I've tested PICStep at 40VDC @ 2.5A without any modification or problems, but your
mileage may vary! :)

I use a simple 24V toroidal transformer and bridge rectifier for my PSU. 24V
RMS works out to about 35VDC when rectified. Plus I've provided massive amounts 
of filtering by using a very large electrolytic capacitor to filter out the humps 
and bumps. It works very well and can supply my three drivers without a problem.


- Building

1. Start by checking the boards for any shorts or malformed tracks. Fix if
anything looks funny.

2. Cut and shape the 20 wire links. Carefully solder them into place. I find
to get them to sit nice and flat I poke one end into one hole and bend it at
90 degrees to the board, then I poke the other end into the other hole and
grip it with a pair of needle nose pliers. Pulling gently on it the wire link
will straighten and look much neater! Be careful not to pull to hard or you'll
snap it :)

3. Insert R5->R9 these are 10K pull up resistors and can be any value as long
as they aren't below about 5K. They simply stop the board from oscillating if
the control connector is disconnected while the board it powered.

4. Insert R1 and R3. These are 20K resistors and their values are critical.
They set the frequency of the LMD's chopper system, increasing or reducing
these values will mess up the chopper timing.

5. Break apart some "socket strip" (IC socket pins in a single strip length) so 
you end up with a four single pins. Solder these pins into the holes of R2 and
R4. Doing this will allow you to easily plug in resistors to adjust the
current limit of the LMD's to the amounted needed by your motor. You can see
examples of these "socket pins" in the photos of my boards.

R2 and R4 are used to set the current limit of the motor. The motor controller
can NEVER be powered without these resistors in place else the ruin of the
LMD's will result. Plus NEVER specify a resistor value LESS than 6.6K (which
is 3 amps drive current), pushing the LMD past 3 amps will be to their doom.

Use this equation to work out the resistors you need for your motor's current
limits :-

	<resistor in ohms> = 20000 / <current in amps>

Some example values are:-

	Resistor	Current
	200K		0.1A
	40K		0.5A
	20K		1A
	10K		2A
	8K		2.5A
	6.6K		3A

6. Mount capacitors C1 and C3. These are 2.2nF MKT type capacitors and their
values are critical. They set the frequency of the LMD's chopper system,
increasing or reducing these values will mess up the chopper timing.

7. Mount capacitors C2 and C4. These are 500pF ceramic type capacitors. Their
values aren't critical but they should be a small value. They provide a small
amount of filtering to the current limit to help smooth the switch transition.

8. Mount capacitors C10 and C11. These are 10nF MKT type capacitors. Their
values aren't critical, they provide the necessary high frequency power
filtering the PIC and the LMD's require. A value at or near 10nF will be
adequate.

9. Mount capacitors C5 and C7. These are 1uF MKT type capacitors. They provide
the needed high frequency filtering for the LMD's. They aren't a critical value
but they must be at or around 1uF to provide adequate filtering. They should
also be rated at the supply voltage you are going to use.

10. Mount capacitor C9. This is a simple filter capacitor on the 5v supply
line to filter out any humps and bumps. Any electro over 10uF will do.

11. Mount capacitors C6 and C8. These are 470uF Electrolytic capacitors. They
provide the low frequency filtering the LMD's require to regulate and by-pass the 
supply voltage. They must be rated to more than the supply voltage. Their
values aren't critical but you must provide at least 100uF per amp of load you
intend to use!

12. Mount X1 the 20MHz resonator. If you wish to use the 4MHz version of the
firmware you can safely leave this component off the board. But you really
should use the 20MHz version if you can, it will provide much higher RPM!

13. Mount U1 the PIC16F628A. You can use a 18way IC socket if you wish to be
able to remove the chip.

14. Mount CONN1, CONN2, and M1 sockets

16. Mount U2 and U3. The LMD's should be flush with each other and must not
have their bent pins touching the board. You should end up with enough pin
poking through the board to allow soldering. They DON'T need trimming with
wire snippers!

17. Now visually inspect the board to make sure there are no shorts and
everything is in place. If all is good, you're done! And now you can see if
your creation works!

Have fun!

Alan.



Copyright Apr 2005 - Alan Garfield <alan@fromorbit.com>
