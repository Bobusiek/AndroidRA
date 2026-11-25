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
using System.Runtime.InteropServices;
using Android.App;
using Android.Runtime;

namespace OpenRA.Android
{
	/// <summary>
	/// Runs before any activity is created. Registers the managed game entry point with libmain.so,
	/// which SDLActivity calls (as SDL_main) on its dedicated SDL thread once the surface is ready.
	/// </summary>
	[Application]
	public class OpenRAApplication : Application
	{
		[UnmanagedFunctionPointer(CallingConvention.Cdecl)]
		delegate int ManagedMain(int argc, IntPtr argv);

		// Must stay referenced for the lifetime of the process, otherwise the GC would free the thunk.
		static readonly ManagedMain EntryPoint = GameRunner.Run;

		[DllImport("main")]
		static extern void OpenRA_SetManagedMain(IntPtr entry);

		public OpenRAApplication(IntPtr handle, JniHandleOwnership transfer)
			: base(handle, transfer) { }

		public override void OnCreate()
		{
			base.OnCreate();
			OpenRA_SetManagedMain(Marshal.GetFunctionPointerForDelegate(EntryPoint));
		}
	}
}
