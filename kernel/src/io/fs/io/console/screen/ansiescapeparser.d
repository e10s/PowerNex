module io.fs.io.console.screen.ansiescapeparser;

// TODO: Add reasonable attributes

/// Action handler for 'param'.
class ParamProcessor {
	private enum size_t _maxParamN = 16;
	private uint[_maxParamN] _params;
	private size_t _idx;

	/// Stores a character and construct integral parameters.
	@safe nothrow typeof(this) opOpAssign(string op)(dchar ch) if (op == "~")
	in {
		// '0'-'9' or ';'
		assert(0x30 <= ch && ch <= 0x39 || ch == 0x3b);
	}
	body {
		if (ch == 0x3b) // ';'
		{
			if (_idx < _maxParamN - 1) {
				_idx++;
			}
		} else if (_idx < _maxParamN) {
			_params[_idx] = 10 * _params[_idx] + (ch - '0');
		}
		return this;
	}

	/// Called by a parser.
	@safe nothrow private void _clear() {
		_idx = 0;
		_params[] = 0;
	}

	/// The stored parameters.
	@property @safe nothrow auto collection() const {
		return _params[0 .. _idx + 1];
	}
}

/// Action handler for 'collect'.
class CollectProcessor {
	private dstring _chars;

	/// Stores a character.
	@safe nothrow typeof(this) opOpAssign(string op)(dchar ch) if (op == "~")
	in {
		// `SP` - '/' or '<' - '?'
		assert(0x20 <= ch && ch <= 0x2f || 0x3c <= ch && ch <= 0x3f);
	}
	body {
		_chars ~= ch;
		return this;
	}

	/// Called by a parser.
	@safe nothrow private void _clear() {
		_chars = null;
	}

	/// The collected characters as `dstring`.
	@property @safe nothrow auto collection() const {
		return _chars;
	}
}

/// Skeleton for action handlers for 'dcs'.
interface DCSHandler {
	///
	void hook(CollectProcessor, ParamProcessor, dchar);
	///
	void put(dchar);
	///
	void unhook();
	///
	void clear();
}

/// Skeleton for action handlers for 'osc'.
interface OSCHandler {
	///
	void oscStart();
	///
	void oscPut(dchar);
	///
	void oscEnd();
	///
	void clear();
}

/// The parser for ANSI escape codes.
class ANSIEscapeParser {
	mixin StateClasses;

	private StateContext _stateContext;
	private ParamProcessor _paramProcessor;
	private CollectProcessor _collectProcessor;

	/// Creates a parser.
	this() {
		_stateContext = new StateContext;
		_paramProcessor = new ParamProcessor;
		_collectProcessor = new CollectProcessor;
	}

	private void delegate(dchar) _onInvalid, _onPrint, _onExecute;
	private void delegate(in CollectProcessor, dchar) _onEscDispatch;
	private void delegate(in CollectProcessor, in ParamProcessor, dchar) _onCSIDispatch;
	private DCSHandler _dcsHandler;
	private OSCHandler _oscHandler;

	/+ User-defined action handlers +/
	/**
	 * Sets handler invoked when an undefined, i.e. invalid, sequence is found.
	 * Note that this is not documented in the spec.
	 * Optional.
	 */
	@property auto onInvalid(void delegate(dchar) handler) {
		_onInvalid = handler;
		return handler;
	}

	/**
	 * Sets handler invoked on '_print' action.
	 * Optional.
	 */
	@property auto onPrint(void delegate(dchar) handler) {
		_onPrint = handler;
		return handler;
	}

	/**
	 * Sets handler invoked on '_execute' action.
	 * Optional.
	 */
	@property auto onExecute(void delegate(dchar) handler) {
		_onExecute = handler;
		return handler;
	}

	/**
	 * Sets handler invoked on 'esc dispatch' action.
	 * Optional.
	 */
	@property auto onEscDispatch(void delegate(in CollectProcessor, dchar) handler) {
		_onEscDispatch = handler;
		return handler;
	}

	/**
	 * Sets handler invoked on 'csi dispatch' action.
	 * Optional.
	 */
	@property auto onCSIDispatch(void delegate(in CollectProcessor, in ParamProcessor, dchar) handler) {
		_onCSIDispatch = handler;
		return handler;
	}

	/**
	 * Sets handler for 'dcs'-related action handlers.
	 * Optional.
	 */
	@property auto dcsHandler(DCSHandler handler) {
		_dcsHandler = handler;
		return handler;
	}

	/**
	 * Sets handler for 'osc'-related action handlers.
	 * Optional.
	 */
	@property auto oscHandler(OSCHandler handler) {
		_oscHandler = handler;
		return handler;
	}

	private dstring _eaten;

	/// Processes a character.
	typeof(this) eat(dchar ch) {
		_eaten ~= ch;
		if (!_stateContext.state.digest(ch)) {
			foreach (c; _eaten) {
				_vomit(c);
			}
			_eaten = null;
		}
		return this;
	}

	/+ Internal actions called by `State***` objects +/
	//
	private void _vomit(dchar ch) {
		if (_onInvalid !is null) {
			_onInvalid(ch);
		}
	}

	// Passes a visible (GL and GR) character to the callback.
	private void _print(dchar ch) {
		if (_onPrint !is null) {
			_onPrint(ch);
		}
	}

	// Passes a control (C0 or C1) character to the callback.
	private void _execute(dchar ch) {
		if (_onExecute !is null) {
			_onExecute(ch);
		}
	}

	// _Clears the current stored data.
	private void _clear() {
		_paramProcessor._clear();
		_collectProcessor._clear();
		if (_dcsHandler !is null) {
			_dcsHandler.clear();
		}
		if (_oscHandler !is null) {
			_oscHandler.clear();
		}
	}

	private void _collect(dchar ch) {
		_collectProcessor ~= ch;
	}

	private void _param(dchar ch) {
		_paramProcessor ~= ch;
	}

	private void _escDispatch(dchar ch) {
		if (_onEscDispatch !is null) {
			_onEscDispatch(_collectProcessor, ch);
		}
	}

	private void _csiDispatch(dchar ch) {
		if (_onCSIDispatch !is null) {
			_onCSIDispatch(_collectProcessor, _paramProcessor, ch);
		}
	}

	private void _hook(dchar ch) {
		if (_dcsHandler !is null) {
			_dcsHandler.hook(_collectProcessor, _paramProcessor, ch);
		}
	}

	private void _put(dchar ch) {
		if (_dcsHandler !is null) {
			_dcsHandler.put(ch);
		}
	}

	private void _unhook() {
		if (_dcsHandler !is null) {
			_dcsHandler.unhook();
		}

	}

	private void _oscStart() {
		if (_oscHandler !is null) {
			_oscHandler.oscStart();
		}
	}

	private void _oscPut(dchar ch) {
		if (_oscHandler !is null) {
			_oscHandler.oscPut(ch);
		}
	}

	private void _oscEnd() {
		if (_oscHandler !is null) {
			_oscHandler.oscEnd();
		}
	}
}

private mixin template StateClasses() {
	class StateContext {
		private State _state;
		private this() {
			// Initial state
			state = new StateGround;
		}

		@property State state(State newState) {
			if (_state !is null) {
				_state.exit();
			}
			_state = newState;
			_state.entry();
			return _state;
		}

		@property State state() {
			return _state;
		}
	}

	abstract class State {
		/// Invoked when entering into the state.
		void entry() {
		}

		/// Invoked when leaving the state.
		void exit() {
		}

		/// Returns false if no appropriate behavior is defined for the character.
		bool digest(dchar ch);
	}

	class StateAny : State {
		private this() {
		}

		override bool digest(dchar ch) {
			switch (ch) {
			case 0x18:
			case 0x1a:
			case 0x80: .. case 0x8f:
			case 0x91: .. case 0x97:
			case 0x99:
			case 0x9a:
				_execute(ch);
				_stateContext.state = new StateGround;
				break;
			case 0x9c:
				_stateContext.state = new StateGround;
				break;
			case 0x1b:
				_stateContext.state = new StateEscape;
				break;
			case 0x90:
				_stateContext.state = new StateDCSEntry;
				break;
			case 0x9b:
				_stateContext.state = new StateCSIEntry;
				break;
			case 0x9d:
				_stateContext.state = new StateOSCString;
				break;
			case 0x98:
			case 0x9e:
			case 0x9f:
				_stateContext.state = new StateSOSorPMorAPCString;
				break;
			default:
				return false;
			}
			return true;
		}
	}

	final class StateGround : StateAny {
		private this() {
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				_execute(ch);
			} else if (_isPrintable(ch)) {
				_print(ch);
			} else {
				return false;
			}
			return true;
		}
	}

	final class StateEscape : StateAny {
		private this() {
		}

		override void entry() {
			_clear();
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				_execute(ch);
			} else if (ch == 0x7f) {
				// IGNORE
			} else if (0x20 <= ch && ch <= 0x2f) {
				_collect(ch);
				_stateContext.state = new StateEscapeIntermediate;
			} else if (0x30 <= ch && ch <= 0x4f || 0x51 <= ch && ch <= 0x57 || ch == 0x59 || ch == 0x5a || ch == 0x5c
					|| 0x60 <= ch && ch <= 0x7e) {
				_escDispatch(ch);
				_stateContext.state = new StateGround;
			} else if (ch == 0x5b) {
				_stateContext.state = new StateCSIEntry;
			} else if (ch == 0x58 || ch == 0x5e || ch == 0x5f) {
				_stateContext.state = new StateSOSorPMorAPCString;
			} else if (ch == 0x50) {
				_stateContext.state = new StateDCSEntry;
			} else if (ch == 0x5d) {
				_stateContext.state = new StateOSCString;
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateEscapeIntermediate : StateAny {
		private this() {
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				_execute(ch);
			} else if (0x20 <= ch && ch <= 0x2f) {
				_collect(ch);
			} else if (ch == 0x7f) {
				// IGNORE
			} else if (0x30 <= ch && ch <= 0x7e) {
				_escDispatch(ch);
				_stateContext.state = new StateGround;
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateCSIEntry : StateAny {
		private this() {
		}

		override void entry() {
			_clear();
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				_execute(ch);
			} else if (ch == 0x7f) {
				// IGNORE
			} else if (0x40 <= ch && ch <= 0x7e) {
				_csiDispatch(ch);
				_stateContext.state = new StateGround;
			} else if (0x30 <= ch && ch <= 0x39 || ch == 0x3b) {
				_param(ch);
				_stateContext.state = new StateCSIParam;
			} else if (0x3c <= ch && ch <= 0x3f) {
				_collect(ch);
				_stateContext.state = new StateCSIParam;
			} else if (ch == 0x3a) {
				_stateContext.state = new StateCSIIgnore;
			} else if (ch >= 0x20 && ch <= 0x2f) {
				_collect(ch);
				_stateContext.state = new StateCSIIntermediate;
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateCSIParam : StateAny {
		private this() {
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				_execute(ch);
			} else if (0x30 <= ch && ch <= 0x39 || ch == 0x3b) {
				_param(ch);
			} else if (ch == 0x7f) {
				// IGNORE
			} else if (0x40 <= ch && ch <= 0x7e) {
				_csiDispatch(ch);
				_stateContext.state = new StateGround;
			} else if (0x20 <= ch && ch <= 0x2f) {
				_collect(ch);
				_stateContext.state = new StateCSIIntermediate;
			} else if (ch == 0x3a || 0x3c <= ch && ch <= 0x3f) {
				_stateContext.state = new StateCSIIgnore;
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateCSIIntermediate : StateAny {
		private this() {
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				_execute(ch);
			} else if (0x20 <= ch && ch <= 0x2f) {
				_collect(ch);
			} else if (ch == 0x7f) {
				// IGNORE
			} else if (0x30 <= ch && ch <= 0x3f) {
				_stateContext.state = new StateCSIIgnore;
			} else if (0x40 <= ch && ch <= 0x7e) {
				_csiDispatch(ch);
				_stateContext.state = new StateGround;
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateCSIIgnore : StateAny {
		private this() {
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				_execute(ch);
			} else if (0x20 <= ch && ch <= 0x3f || ch == 0x7f) {
				// IGNORE
			} else if (0x40 <= ch && ch <= 0x7e) {
				_stateContext.state = new StateGround;
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateDCSEntry : StateAny {
		private this() {
		}

		override void entry() {
			_clear();
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				// IGNORE
			} else if (ch == 0x7f) {
				// IGNORE
			} else if (0x20 <= ch && ch <= 0x2f) {
				_collect(ch);
				_stateContext.state = new StateDCSIntermediate;
			} else if (ch == 0x3a) {
				_stateContext.state = new StateDCSIgnore;
			} else if (0x30 <= ch && ch <= 0x39 || ch == 0x3b) {
				_param(ch);
				_stateContext.state = new StateDCSParam;
			} else if (0x3c <= ch && ch <= 0x3f) {
				_collect(ch);
				_stateContext.state = new StateDCSParam;
			} else if (0x40 <= ch && ch <= 0x7e) {
				_stateContext.state = new StateDCSPassthrough(ch);
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateDCSParam : StateAny {
		private this() {
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				// IGNORE
			} else if (0x30 <= ch && ch <= 0x39 || ch == 0x3b) {
				_param(ch);
				_stateContext.state = new StateDCSParam;
			} else if (ch == 0x7f) {
				// IGNORE
			} else if (0x20 <= ch && ch <= 0x2f) {
				_collect(ch);
				_stateContext.state = new StateDCSIntermediate;
			} else if (ch == 0x3a || 0x3c <= ch && ch <= 0x3f) {
				_stateContext.state = new StateDCSIgnore;
			} else if (0x40 <= ch && ch <= 0x7e) {
				_stateContext.state = new StateDCSPassthrough(ch);
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateDCSIntermediate : StateAny {
		private this() {
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				// IGNORE
			} else if (0x20 <= ch && ch <= 0x2f) {
				_collect(ch);
			} else if (ch == 0x7f) {
				// IGNORE
			} else if (0x30 <= ch && ch <= 0x3f) {
				_stateContext.state = new StateDCSIgnore;
			} else if (0x40 <= ch && ch <= 0x7f) {
				_stateContext.state = new StateDCSPassthrough(ch);
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateDCSPassthrough : StateAny {
		private dchar _finalChar;
		private this(dchar finalChar) {
			_finalChar = finalChar;
		}

		override void entry() {
			_hook(_finalChar);
		}

		override void exit() {
			_unhook();
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				_put(ch);
			} else if (_isPrintable(ch) && ch != 0x7f) {
				_put(ch);
			} else if (ch == 0x7f) {
				// IGNORE
			} else if (ch == 0x9c) {
				_stateContext.state = new StateGround;
				assert(0);
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateDCSIgnore : StateAny {
		private this() {
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				// IGNORE
			} else if (_isPrintable(ch)) {
				// IGNORE
			} else if (ch == 0x9c) {
				_stateContext.state = new StateGround;
				assert(0);
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateOSCString : StateAny {
		private this() {
		}

		override void entry() {
			_oscStart();
		}

		override void exit() {
			_oscEnd();
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				// IGNORE
			} else if (_isPrintable(ch)) {
				_oscPut(ch);
			} else if (ch == 0x9c) {
				_stateContext.state = new StateGround;
				assert(0);
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}

	final class StateSOSorPMorAPCString : StateAny {
		private this() {
		}

		override bool digest(dchar ch) {
			if (super.digest(ch)) {
				return true;
			}

			if (_isWithinC0(ch)) {
				// IGNORE
			} else if (_isPrintable(ch)) {
				// IGNORE
			} else if (ch == 0x9c) {
				_stateContext.state = new StateGround;
				assert(0);
			} else {
				_stateContext.state = new StateGround;
				return false;
			}
			return true;
		}
	}
}

@nogc @safe nothrow pure private bool _isPrintable(dchar ch) {
	return 0x20 <= ch && ch <= 0x7f || 0xa0 <= ch /* && ch <= 0xff */ ;
}

@nogc @safe nothrow pure private bool _isWithinC0(dchar ch) // C0, but partial
{
	return 0x00 <= ch && ch <= 0x17 || ch == 0x19 || 0x1c <= ch && ch <= 0x1f;
}
