module io.fs.io.console.screen.colorpalette;

import data.color;

// dfmt off
immutable Color[16] vgaColorPalette = [
	// Normal
	Color(0, 0, 0),       // black
	Color(170, 0, 0),     // red
	Color(0, 170, 0),     // green
	Color(170, 85, 0),    // yellow
	Color(0, 0,170),      // blue
	Color(170, 0, 170),   // magenta
	Color(0, 170, 170),   // cyan
	Color(170, 170, 170), // white

	// Bright
	Color(85, 85, 85),
	Color(255, 85, 85),
	Color(85, 255, 85),
	Color(255, 255, 85),
	Color(85, 85, 255),
	Color(255, 85, 255),
	Color(85, 255, 255),
	Color(255, 255, 255)
];
// dfmt on
