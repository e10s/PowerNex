module io.fs.io.console.screen.virtualconsolescreen;

import io.fs;
import io.fs.io.console.screen;
import data.address;
import data.color;
import data.utf;

abstract class VirtualConsoleScreen : FileNode {
public:
	this(size_t width, size_t height, FormattedChar clearChar) {
		super(NodePermissions.defaultPermissions, 0);
		_width = width;
		_height = height;
		_clearChar = clearChar;
		_screen = new FormattedChar[width * height];
		for (size_t i = 0; i < _screen.length; i++)
			_screen[i] = _clearChar;

		_lineStarts = new size_t[height];
	}

	~this() {
		_screen.destroy;
	}

	override bool open() {
		if (_inUse)
			return false;
		return _inUse = true;
	}

	override void close() {
		_inUse = false;
	}

	/++
		TODO: Change how this works!
		XXX: Casting FormattedChar to a ubyte array is crazy!
	+/
	override ulong read(ubyte[] buffer, ulong offset) {
		ubyte[] scr_b = cast(ubyte[])_screen;

		size_t maxBytes = (buffer.length < scr_b.length) ? buffer.length : scr_b.length;

		for (size_t i = 0; i < maxBytes; i++)
			buffer[i] = scr_b[i];

		return maxBytes;
	}

	/+
	override ulong write(ubyte[] buffer, ulong offset) {
		UTF8Range str = UTF8Range(buffer);

		if (active)
			updateChar(_curX, _curY); // Remove cursor rendering

		foreach (dchar ch; _prepareData(str)) {
			switch (ch) {
			case '\n':
				_curY++;
				_curX = 0;
				break;
			case '\r':
				_curX = 0;
				break;
			case '\b':
				if (_curX)
					_curX--;
				break;
			case '\t':
				size_t goal = (_curX + 8) & ~7;
				if (goal > _width)
					goal = _width;
				for (; _curX < goal; _curX++) {
					_screen[_curY * _width + _curX] = _clearChar;
					if (active)
						updateChar(_curX, _curY);
				}
				if (_curX >= _width) {
					_curY++;
					_curX = 0;
				}
				break;
			default:
				_screen[_curY * _width + _curX] = FormattedChar(ch, Color(255, 255, 0), Color(0, 0, 0), CharStyle.none);
				if (active)
					updateChar(_curX, _curY);
				_curX++;
				if (_curX >= _width) {
					_curY++;
					_curX = 0;
				}
				break;
			}
		}
		if (active)
			updateCursor();
		return buffer.length;
	}
+/

	// FIXME: When attempts to move to somewhere after put just one character at the bottom right corner, scrolling should not occur.
	override ulong write(ubyte[] buffer, ulong offset) {
		auto parser = new ANSIEscapeParser;

		// TODO: Append more handlers
		auto onPrint = delegate void(dchar ch) {
			_screen[_curY * _width + _curX] = FormattedChar(ch, _fgColor, _bgColor, CharStyle.none);
			if (active)
				updateChar(_curX, _curY);
			_curX++;
			if (_curX >= _width) {
				_curY++;
				_curX = 0;
			}
		};
		parser.onPrint = onPrint;
		auto onExecute = delegate void(dchar ch) {
			switch (ch) {
			case '\n':
				_curY++;
				_curX = 0;
				break;
			case '\r':
				_curX = 0;
				break;
			case '\b':
				if (_curX)
					_curX--;
				break;
			case '\t':
				size_t goal = (_curX + 8) & ~7;
				if (goal > _width)
					goal = _width;
				for (; _curX < goal; _curX++) {
					_screen[_curY * _width + _curX] = _clearChar;
					if (active)
						updateChar(_curX, _curY);
				}
				if (_curX >= _width) {
					_curY++;
					_curX = 0;
				}
				break;
			default:
				onPrint(ch); // try to print anyway!
				break;
			}
		};
		parser.onExecute = onExecute;
		parser.onCSIDispatch = delegate void(in CollectProcessor collectProcessor, in ParamProcessor paramProcessor, dchar ch) {
			// TODO: Add more functions
			if (collectProcessor.collection.length) {
				return;
			}

			switch (ch) {
			case '@': // ICH
				size_t n = paramProcessor.collection[0];
				if (n == 0) {
					n = 1;
				}

				immutable dstX = _curX + n > _width ? _width : _curX + n;
				immutable srcX = dstX - n;
				immutable dstOffset = FormattedChar.sizeof * (_curY * _width + dstX);
				immutable srcOffset = FormattedChar.sizeof * (_curY * _width + srcX);
				immutable size = FormattedChar.sizeof * (_width - dstX);
				memmove((_screen.VirtAddress + dstOffset).ptr, (_screen.VirtAddress + srcOffset).ptr, size);
				_screen[_curY * _width + _curX .. _curY * _width + dstX] = _clearChar;
				foreach (x; _curX .. _width) {
					updateChar(x, _curY);
				}
				break;
			case 'A': // CUU
			case 'k': // VPB
				size_t dy = paramProcessor.collection[0];
				if (dy == 0) {
					dy = 1;
				}

				if (_curY >= dy) {
					_curY -= dy;
				} else {
					_curY = 0;
				}
				break;
			case 'B': // CUD
			case 'e': // VPR
				size_t dy = paramProcessor.collection[0];
				if (dy == 0) {
					dy = 1;
				}

				if (_curY + dy <= _height - 1) {
					_curY += dy;
				} else {
					_curY = _height - 1;
				}
				break;
			case 'C': // CUF
			case 'a': // HPR
				size_t dx = paramProcessor.collection[0];
				if (dx == 0) {
					dx = 1;
				}

				if (_curX + dx <= _width - 1) {
					_curX += dx;
				} else {
					_curX = _width - 1;
				}
				break;
			case 'D': // CUB
			case 'j': // HPB
				size_t dx = paramProcessor.collection[0];
				if (dx == 0) {
					dx = 1;
				}

				if (_curX >= dx) {
					_curX -= dx;
				} else {
					_curX = 0;
				}
				break;
			case 'E': // CNL
				_curX = 0;
				goto case 'B';
			case 'F': // CPL
				_curX = 0;
				goto case 'A';
			case 'G': // CHA
			case '`': // HPA
				size_t x = paramProcessor.collection[0];
				if (x > 0) {
					x--;
				}

				_curX = x < _width ? x : _width - 1;
				break;
			case 'H': // CUP
			case 'f': // HVP
				size_t y = paramProcessor.collection[0];
				if (y > 0) {
					y--;
				}

				size_t x;
				if (paramProcessor.collection.length > 1) {
					x = paramProcessor.collection[1];
					if (x > 0) {
						x--;
					}
				}

				_curY = y < _height ? y : _height - 1;
				_curX = x < _width ? x : _width - 1;
				break;
			case 'I': // CHT
				size_t n = paramProcessor.collection[0];
				if (n == 0) {
					n = 1;
				}

				immutable goal = (_curX + 8 * n) & ~7;
				_curX = goal < _width ? goal : _width - 1;
				break;
			case 'J': // ED
				switch (paramProcessor.collection[0]) {
				case 0:
					for (size_t i = _curY * _width + _curX; i < _height * _width; i++) {
						_screen[i] = _clearChar;
						updateChar(i % _width, i / _width);
					}
					break;
				case 1:
					for (size_t i = 0; i <= _curY * _width + _curX; i++) {
						_screen[i] = _clearChar;
						updateChar(i % _width, i / _width);
					}
					break;
				case 2:
					immutable x = _curX, y = _curY;
					_scroll(_height);
					_curX = x;
					_curY = y;

					if (active)
						updateCursor();
					break;
				default:
					break;
				}
				break;
			case 'K': // EL
				switch (paramProcessor.collection[0]) {
				case 0:
					_screen[_curY * _width + _curX .. _curY * _width + _width] = _clearChar;
					foreach (x; _curX .. _width) {
						updateChar(x, _curY);
					}
					break;
				case 1:
					_screen[_curY * _width .. _curY * _width + _curX + 1] = _clearChar;
					foreach (x; 0 .. _curX + 1) {
						updateChar(x, _curY);
					}
					break;
				case 2:
					_screen[_curY * _width .. _curY * _width + _width] = _clearChar;
					foreach (x; 0 .. _width) {
						updateChar(x, _curY);
					}
					break;
				default:
					break;
				}
				break;
			case 'P': // DCH
				size_t n = paramProcessor.collection[0];
				if (n == 0) {
					n = 1;
				}

				immutable srcX = _curX + n > _width ? _width : _curX + n;
				immutable dstOffset = FormattedChar.sizeof * (_curY * _width + _curX);
				immutable srcOffset = FormattedChar.sizeof * (_curY * _width + srcX);
				immutable size = FormattedChar.sizeof * (_width - srcX);
				memmove((_screen.VirtAddress + dstOffset).ptr, (_screen.VirtAddress + srcOffset).ptr, size);
				_screen[_curY * _width + _width - (srcX - _curX) .. _curY * _width + _width] = _clearChar;
				foreach (x; _curX .. _width) {
					updateChar(x, _curY);
				}
				break;
			case 'X': // ECH
				size_t n = paramProcessor.collection[0];
				if (n == 0) {
					n = 1;
				}

				immutable dstX = _curX + n > _width ? _width : _curX + n;
				_screen[_curY * _width + _curX .. _curY * _width + dstX] = _clearChar;
				foreach (x; _curX .. dstX) {
					updateChar(x, _curY);
				}
				break;
			case 'Z': // CBT
				size_t n = paramProcessor.collection[0];
				if (n == 0) {
					n = 1;
				}

				_curX = _curX > 0 ? (_curX - 1) / n & ~7 : 0;
				break;
			case 'm': // SGR
				// TODO: Be more sophisticated!
				bool inSeq;
				int seqRemains;
				foreach (i, e; paramProcessor.collection) {
					if (inSeq) {
						if (seqRemains > 0) {
							seqRemains--;
							continue;
						} else {
							inSeq = false;
						}
					}

					switch (e) {
					case 0:
						_fgColor = Color(255, 255, 255);
						_bgColor = Color();
						// In addition reset style
						break;
					case 30: .. case 37:
						_fgColor = vgaColorPalette[e - 30];
						break;
					case 38:
						if (paramProcessor.collection.length > i + 4 && paramProcessor.collection[i + 1] == 2) {
							inSeq = true;
							seqRemains = 4;
							foreach (j, channel; paramProcessor.collection[i + 2 .. i + 5]) {
								switch (j) {
								case 0:
									_fgColor.r = channel > 255 ? 255 : cast(ubyte)channel;
									break;
								case 1:
									_fgColor.g = channel > 255 ? 255 : cast(ubyte)channel;
									break;
								case 2:
									_fgColor.b = channel > 255 ? 255 : cast(ubyte)channel;
									break;
								default:
									break;
								}
							}
						} else if (paramProcessor.collection.length > i + 2 && paramProcessor.collection[i + 1] == 5) {
							inSeq = true;
							seqRemains = 2;
							immutable n = paramProcessor.collection[i + 2];
							if (n < 256) {
								_fgColor = xterm256ColorPalette(n);
							}
						}
						break;
					case 39:
						_fgColor = Color(255, 255, 255);
						break;
					case 40: .. case 47:
						_bgColor = vgaColorPalette[e - 40];
						break;
					case 48:
						if (paramProcessor.collection.length > i + 4 && paramProcessor.collection[i + 1] == 2) {
							inSeq = true;
							seqRemains = 4;
							auto bgColor = _bgColor;
							foreach (j, channel; paramProcessor.collection[i + 2 .. i + 5]) {
								switch (j) {
								case 0:
									bgColor.r = channel > 255 ? 255 : cast(ubyte)channel;
									break;
								case 1:
									bgColor.g = channel > 255 ? 255 : cast(ubyte)channel;
									break;
								case 2:
									bgColor.b = channel > 255 ? 255 : cast(ubyte)channel;
									break;
								default:
									break;
								}
							}
							_bgColor = bgColor;
						} else if (paramProcessor.collection.length > i + 2 && paramProcessor.collection[i + 1] == 5) {
							inSeq = true;
							seqRemains = 2;
							immutable n = paramProcessor.collection[i + 2];
							if (n < 256) {
								_bgColor = xterm256ColorPalette(n);
							}
						}
						break;
					case 49:
						_bgColor = Color();
						break;
					case 90: .. case 97:
						_fgColor = vgaColorPalette[e - 90 + 8];
						break;
					case 100: .. case 107:
						_bgColor = vgaColorPalette[e - 100 + 8];
						break;
					default:
						break;
					}
				}
				break;
			default:
				break;
			}
		};

		// -------------------------------

		UTF8Range str = UTF8Range(buffer);

		if (active)
			updateChar(_curX, _curY); // Remove cursor rendering

		foreach (dchar ch; str) {
			parser.eat(ch);

			if (_curY >= _height) {
				auto tmp = _curY - _height + 1;
				_curY -= tmp;
				_scroll(tmp);
				_curY += tmp;
			}
		}
		if (active)
			updateCursor();
		return buffer.length;
	}

	void clear() { //TODO:REMOVE
		_clear();
	}

	@property bool active() {
		return _active;
	}

	@property bool active(bool active) {
		if (active && !_active) {
			for (size_t h = 0; h < _height; h++)
				for (size_t w = 0; w < _width; w++)
					updateChar(w, h);
			updateCursor();
		}
		_active = active;
		return _active;
	}

protected:
	FormattedChar[] _screen;
	FormattedChar _clearChar;
	size_t _width;
	size_t _height;
	size_t _curX;
	size_t _curY;

	Color _fgColor = Color(255, 255, 255);

	@property ref Color _bgColor(Color bgColor) {
		__bgColor = bgColor;
		_clearChar.bg = bgColor; // main purpose!!
		return __bgColor;
	}

	@property ref Color _bgColor() {
		return __bgColor;
	}

	// abstract void OnNewText(size_t startIdx, size_t length); //TODO: Use this instead of updateChar?
	abstract void onScroll(size_t lineCount);
	abstract void updateCursor();
	abstract void updateChar(size_t x, size_t y);

private:
	Color __bgColor;
	bool _inUse;
	bool _active;

	size_t[] _lineStarts;

	ref UTF8Range _prepareData(ref return UTF8Range str) {
		size_t charCount = _curX;
		size_t lines;

		//size_t[] _lineStarts = new size_t[_height];
		size_t lsIdx;

		// Calc the number line

		size_t escapeCode;
		dchar escapeValue;
		size_t idx;
		foreach (dchar ch; str) {
			if (escapeCode) {
				if (escapeCode == 3) {
					if (ch != '[')
						goto parse;
				} else if (escapeCode == 2)
					escapeValue = ch;
				else {
					switch (ch) {
					case 'J':
						if (escapeValue == '2') {
							str.popFrontN(idx + 1);
							_clear();
							return _prepareData(str);
						}
						break;
					default:
						break;
					}
				}

				escapeCode--;
				idx++;
				continue;
			}
		parse:
			if (ch == '\x1B') {
				escapeCode = 3;
			} else if (ch == '\n') {
				lines++;
				charCount = 0;
				lsIdx = (lsIdx + 1) % _height;
				_lineStarts[lsIdx] = idx + 1; // Next char is the start of *new* the line
			} else if (ch == '\r') {
				charCount = 0;
				_lineStarts[lsIdx] = idx + 1; // Update the lineStart on the current one
			} else if (ch == '\b') {
				if (charCount)
					charCount--;
			} else if (ch == '\t') {
				charCount = (charCount + 8) & ~7;
				if (charCount > _width)
					charCount = _width;
			} else
				charCount++;

			while (charCount >= _width) {
				lines++;
				charCount -= _width;
				lsIdx = (lsIdx + 1) % _height;
				_lineStarts[lsIdx] = idx + 1; // The current char is the start of *new* the line
			}

			idx++;
		}

		if (_curY + lines >= _height) {
			_scroll(_curY + lines - _height + 1);

			// Skip the beginning of the data, that would never be shown on the _screen.
			if (lines >= _height) {
				if (_lineStarts[(lsIdx + 1) % _height] < str.length) {
					//XXX: Fix hack
					str.popFrontN(_lineStarts[(lsIdx + 1) % _height] + 1);
					//str = str[_lineStarts[(lsIdx + 1) % _height] + 1 .. $];
				} else
					str = UTF8Range([]);
			}

		}

		//_lineStarts.destroy;
		return str;
	}

	void _scroll(size_t lineCount) {
		if (lineCount > _height)
			lineCount = _height;

		if (active)
			updateChar(_curX, _curY); // Remove cursor rendering

		if (active)
			onScroll(lineCount);

		size_t offset = FormattedChar.sizeof * lineCount * _width;
		memmove(_screen.ptr, (_screen.VirtAddress + offset).ptr, _screen.length * FormattedChar.sizeof - offset);
		for (size_t i = _screen.length - (lineCount * _width); i < _screen.length; i++)
			_screen[i] = _clearChar;

		ssize_t tmp = _curY - lineCount;
		if (tmp < 0)
			_curY = _curX = 0;
		else
			_curY = tmp;
	}

	void _clear() {
		_scroll(_height);
		_curX = _curY = 0;
		if (active)
			updateCursor();
	}
}
