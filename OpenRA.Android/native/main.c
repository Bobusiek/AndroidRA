/*
 * Copyright (c) The OpenRA Developers and Contributors
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */

/*
 * Tiny libmain.so used by SDLActivity.
 *
 * SDL's Android backend dlopen()s libmain.so on its own thread and calls SDL_main.
 * Managed code cannot export native symbols under Mono, so the C# side registers a
 * function pointer here (OpenRA_SetManagedMain) during Application.OnCreate, and
 * SDL_main simply forwards to it.
 */

#include <android/log.h>
#include <stddef.h>

typedef int (*openra_managed_main)(int argc, char *argv[]);

static openra_managed_main managed_main = NULL;

__attribute__((visibility("default")))
void OpenRA_SetManagedMain(openra_managed_main entry)
{
	managed_main = entry;
}

__attribute__((visibility("default")))
int SDL_main(int argc, char *argv[])
{
	if (managed_main == NULL)
	{
		__android_log_print(ANDROID_LOG_ERROR, "OpenRA", "SDL_main called before the managed entry point was registered");
		return 1;
	}

	return managed_main(argc, argv);
}
