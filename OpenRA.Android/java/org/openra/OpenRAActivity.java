/*
 * Copyright (c) The OpenRA Developers and Contributors
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */

package org.openra;

import org.libsdl.app.SDLActivity;

/**
 * Hosts the SDL surface. SDL starts its own thread and calls SDL_main from libmain.so,
 * which forwards into the managed entry point registered by OpenRA.Android.OpenRAApplication.
 */
public class OpenRAActivity extends SDLActivity {
	@Override
	protected String[] getLibraries() {
		return new String[] { "SDL2", "main" };
	}
}
