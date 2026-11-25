#region Copyright & License Information
/*
 * Copyright (c) The OpenRA Developers and Contributors
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */
#endregion

using System;
using System.Collections.Generic;
using System.Linq;
using SDL2;

namespace OpenRA.Platforms.Default
{
	/// <summary>
	/// Translates touchscreen gestures into the mouse input the engine already understands.
	/// Designed for the "Classic" mouse style, where the left button selects and issues orders
	/// and dragging with the right button scrolls the map.
	///   - Tap: left click (double tap is detected as a double click).
	///   - One finger drag: left drag (selection box, scrollbars, sliders).
	///   - Two finger drag: right button drag (scrolls the map).
	///   - Pinch: mouse wheel (zoom).
	///   - Two finger tap or long press: right click (deselect, pause/cancel production).
	/// </summary>
	sealed class TouchGestures
	{
		// Movement (in effective window pixels) before a touch stops being a tap.
		// Must exceed the engine's MouseScrollDeadzone so that two finger pans are always treated as scrolling.
		const int TapSlop = 16;
		const long LongPressMilliseconds = 450;

		// Relative change in finger distance that corresponds to one mouse wheel step.
		const float PinchStep = 0.04f;

		enum State { Idle, Pending, LeftDrag, TwoFinger, Consumed }

		readonly Dictionary<long, int2> fingers = [];
		State state;

		long primaryFinger;
		int2 pressPosition;
		long pressTime;
		int2 lastPosition;

		int2 twoFingerStart;
		int2 lastCentroid;
		float lastPinchDistance;
		bool rightButtonDown;
		bool zoomed;

		public void FingerDown(long id, int2 position, IInputHandler handler, Modifiers mods)
		{
			fingers[id] = position;

			switch (state)
			{
				case State.Idle:
					state = State.Pending;
					primaryFinger = id;
					pressPosition = lastPosition = position;
					pressTime = Environment.TickCount64;
					break;

				case State.Pending:
					state = State.TwoFinger;
					twoFingerStart = lastCentroid = Centroid();
					lastPinchDistance = PinchDistance();
					rightButtonDown = false;
					zoomed = false;
					handler.OnMouseInput(new MouseInput(MouseInputEvent.Move, MouseButton.None, lastCentroid, int2.Zero, mods, 0));
					break;

				// Additional fingers are ignored while a gesture is in progress
				default:
					break;
			}
		}

		public void FingerMotion(long id, int2 position, IInputHandler handler, Modifiers mods)
		{
			if (!fingers.ContainsKey(id))
				return;

			fingers[id] = position;

			switch (state)
			{
				case State.Pending:
					if (id == primaryFinger && (position - pressPosition).Length > TapSlop)
					{
						Move(handler, pressPosition, MouseButton.None, mods);
						Press(handler, MouseButton.Left, pressPosition, mods);
						state = State.LeftDrag;
						Move(handler, position, MouseButton.Left, mods);
					}

					break;

				case State.LeftDrag:
					if (id == primaryFinger)
						Move(handler, position, MouseButton.Left, mods);

					break;

				case State.TwoFinger:
					UpdateTwoFinger(handler, mods);
					break;

				default:
					break;
			}
		}

		public void FingerUp(long id, int2 position, IInputHandler handler, Modifiers mods)
		{
			if (!fingers.Remove(id))
				return;

			switch (state)
			{
				case State.Pending:
					Click(handler, MouseButton.Left, pressPosition, mods);
					state = State.Consumed;
					break;

				case State.LeftDrag:
					if (id == primaryFinger)
					{
						Move(handler, position, MouseButton.Left, mods);
						Release(handler, MouseButton.Left, position, mods);
						state = State.Consumed;
					}

					break;

				case State.TwoFinger:
					if (rightButtonDown)
						Release(handler, MouseButton.Right, lastCentroid, mods);
					else if (!zoomed)
						Click(handler, MouseButton.Right, twoFingerStart, mods);

					state = State.Consumed;
					break;

				default:
					break;
			}

			if (fingers.Count == 0)
				state = State.Idle;
		}

		/// <summary>Must be called once per frame to detect long presses.</summary>
		public void Update(IInputHandler handler, Modifiers mods)
		{
			if (state == State.Pending && Environment.TickCount64 - pressTime >= LongPressMilliseconds)
			{
				Click(handler, MouseButton.Right, pressPosition, mods);
				state = State.Consumed;
			}
		}

		void UpdateTwoFinger(IInputHandler handler, Modifiers mods)
		{
			if (fingers.Count < 2)
				return;

			var centroid = Centroid();

			// Pinch zoom: emit whole mouse wheel steps as the finger distance changes
			var distance = PinchDistance();
			if (lastPinchDistance > 0 && distance > 0)
			{
				var steps = (int)(MathF.Log(distance / lastPinchDistance) / MathF.Log(1 + PinchStep));
				if (steps != 0)
				{
					zoomed = true;
					lastPinchDistance *= MathF.Pow(1 + PinchStep, steps);
					handler.OnMouseInput(new MouseInput(MouseInputEvent.Scroll, MouseButton.None, centroid, new int2(0, steps), mods, 0));
				}
			}

			// Pan: hold the right (scroll) button once the fingers have moved far enough
			if (!rightButtonDown && (centroid - twoFingerStart).Length > TapSlop)
			{
				Move(handler, twoFingerStart, MouseButton.None, mods);
				Press(handler, MouseButton.Right, twoFingerStart, mods);
				rightButtonDown = true;
			}

			if (rightButtonDown)
				Move(handler, centroid, MouseButton.Right, mods);

			lastCentroid = centroid;
		}

		int2 Centroid()
		{
			var first = fingers.Values.Take(2).ToArray();
			return first.Length < 2 ? first[0] : (first[0] + first[1]) / 2;
		}

		float PinchDistance()
		{
			var first = fingers.Values.Take(2).ToArray();
			return first.Length < 2 ? 0 : (first[0] - first[1]).Length;
		}

		void Move(IInputHandler handler, int2 position, MouseButton buttons, Modifiers mods)
		{
			handler.OnMouseInput(new MouseInput(MouseInputEvent.Move, buttons, position, position - lastPosition, mods, 0));
			lastPosition = position;
		}

		static byte SdlButton(MouseButton button)
		{
			return button == MouseButton.Right ? (byte)SDL.SDL_BUTTON_RIGHT : (byte)SDL.SDL_BUTTON_LEFT;
		}

		static void Press(IInputHandler handler, MouseButton button, int2 position, Modifiers mods)
		{
			var taps = MultiTapDetection.DetectFromMouse(SdlButton(button), position);
			handler.OnMouseInput(new MouseInput(MouseInputEvent.Down, button, position, int2.Zero, mods, taps));
		}

		static void Release(IInputHandler handler, MouseButton button, int2 position, Modifiers mods)
		{
			var taps = MultiTapDetection.InfoFromMouse(SdlButton(button));
			handler.OnMouseInput(new MouseInput(MouseInputEvent.Up, button, position, int2.Zero, mods, taps));
		}

		void Click(IInputHandler handler, MouseButton button, int2 position, Modifiers mods)
		{
			Move(handler, position, MouseButton.None, mods);
			Press(handler, button, position, mods);
			Release(handler, button, position, mods);
		}
	}
}
