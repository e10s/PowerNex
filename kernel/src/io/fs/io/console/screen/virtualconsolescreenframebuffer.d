module io.fs.io.console.screen.virtualconsolescreenframebuffer;

import io.fs;
import io.fs.io.console.screen;
import io.fs.io.framebuffer;

import data.color;
import data.font;

final class VirtualConsoleScreenFramebuffer : VirtualConsoleScreen {
public:
	this(Framebuffer fb, Font font) {
		super(fb.width / font.width, fb.height / font.height, FormattedChar(' ', Color(0xFF, 0xFF, 0xFF), Color(0x00,
				0x00, 0x00), CharStyle.none));
		_fb = fb;
		_font = font;
		setCursorVisibility(true);
		setCursorStyle(CursorShape.block, true);
	}

protected:
	override void onScroll(size_t lineCount) {
		size_t dstRow = _font.height * _topMargin;
		size_t srcRow = _font.height * (_topMargin + lineCount);
		size_t rows = _font.height * (_bottomMargin + 1) - srcRow;

		_fb.moveRegion(0, dstRow, 0, srcRow, _fb.width, rows);
		_fb.renderRect(0, dstRow + rows, _fb.width, srcRow - dstRow, _clearChar.bg);
	}

	override void onReverseScroll(size_t lineCount) {
		size_t dstRow = _font.height * (_topMargin + lineCount);
		size_t srcRow = _font.height * _topMargin;
		size_t rows = _font.height * (_bottomMargin + 1) - dstRow;

		_fb.moveRegion(0, dstRow, 0, srcRow, _fb.width, rows);
		_fb.renderRect(0, srcRow, _fb.width, dstRow - srcRow, _clearChar.bg);
	}

	override void setCursorVisibility(bool visible) {
		if (visible == _cursorVisible) {
			return;
		}

		_cursorVisible = visible;
		updateCursor();
	}

	override void setCursorStyle(CursorShape cursorShape, bool shouldBlink) { // `shouldBlink` is ignored.
		_cursorShape = cursorShape;
		updateCursor();
	}

	override void updateCursor() {
		FormattedChar ch = _screen[_curY * _width + _curX];

		if (!_cursorVisible) {
			_renderFormattedChar(ch, _curX * _font.width, _curY * _font.height);
			return;
		}

		switch (_cursorShape) {
		case CursorShape.block:
			Color tmp = ch.fg;
			ch.fg = ch.bg;
			ch.bg = tmp;
			_renderFormattedChar(ch, _curX * _font.width, _curY * _font.height);
			break;
		case CursorShape.underline:
			_renderFormattedChar(ch, _curX * _font.width, _curY * _font.height);

			enum size_t underlineHeight = 2;
			_fb.renderRect(_curX * _font.width, (_curY + 1) * _font.height - underlineHeight, _font.width, underlineHeight, ch.fg);
			break;
		case CursorShape.bar:
			_renderFormattedChar(ch, _curX * _font.width, _curY * _font.height);

			if (!_atRightOfRightmost) {
				_fb.renderLine(_curX * _font.width, _curY * _font.height, _curX * _font.width, (_curY + 1) * _font.height - 1, ch.fg);
			}
			break;
		default:
			assert(0);
			break;
		}

	}

	override void updateChar(size_t x, size_t y) {
		auto ch = _screen[y * _width + x];
		_renderFormattedChar(ch, x * _font.width, y * _font.height);
	}

	@property override bool active(bool active) {
		_fb.active = active;
		return super.active(active);
	}

private:
	CursorShape _cursorShape;
	bool _cursorVisible;
	Framebuffer _fb;
	Font _font;

	void _renderFormattedChar(FormattedChar ch, ssize_t x, ssize_t y) {
		if (ch.style & CharStyle.negative) {
			_fb.renderChar(_font, ch.ch, x, y, ch.bg, ch.fg);
		} else {
			_fb.renderChar(_font, ch.ch, x, y, ch.fg, ch.bg);
		}
		if (ch.style & CharStyle.underline) {
			immutable startX = _curX * _font.width;
			immutable startY = (_curY + 1) * _font.height - 1;
			_fb.renderLine(startX, startY, startX + _font.width - 1, startY, ch.fg);
		}
		if (ch.style & CharStyle.strikethru) {
			immutable startX = _curX * _font.width;
			immutable startY = _curY * _font.height + _font.height / 2;
			_fb.renderLine(startX, startY, startX + _font.width - 1, startY, ch.fg);
		}
	}

	void _rerender() {
		foreach (idx, ch; _screen)
			_renderFormattedChar(ch, idx % _font.width, idx / _font.height);
		updateCursor();
	}
}
