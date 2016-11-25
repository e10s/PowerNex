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

Color xterm256ColorPalette(uint colorCode) {
	if (colorCode < 16) {
		// dfmt off
		immutable Color[16] color = [
			Color(0, 0, 0),
			Color(128, 0, 0),
			Color(0, 128, 0),
			Color(128, 128, 0),
			Color(0, 0, 128),
			Color(128, 0, 128),
			Color(0, 128, 128),
			Color(192, 192, 192),

			Color(128, 128, 128),
			Color(255, 0, 0),
			Color(0, 255, 0),
			Color(255, 255, 0),
			Color(0, 0, 255),
			Color(255, 0, 255),
			Color(0, 255, 255),
			Color(255, 255, 255)
		];
		// dfmt on

		return color[colorCode];
	} else if (colorCode < 232) { // 216 colors
		immutable ubyte[6] level = [0, 95, 135, 175, 215, 255];
		immutable r = (colorCode - 16) / 36;
		immutable g = (colorCode - 16) % 36 / 6;
		immutable b = (colorCode - 16) % 6;
		return Color(level[r], level[g], level[b]);
	} else { // grayscale
		immutable ubyte level = cast(ubyte)((colorCode - 232) * 10 + 8);
		return Color(level, level, level);
	}
}
