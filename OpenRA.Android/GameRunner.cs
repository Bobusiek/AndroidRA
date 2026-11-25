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
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using Android.Content;
using AndroidLog = Android.Util.Log;
using JavaSystem = Java.Lang.JavaSystem;

namespace OpenRA.Android
{
	/// <summary>Prepares the engine directories and runs the game on the SDL thread.</summary>
	static class GameRunner
	{
		const string LogTag = "OpenRA";
		const string EngineAsset = "engine.zip";
		const string StampFile = ".engine-stamp";
		const string DefaultMod = "ra";
		const string UIScaleStampFile = ".android-uiscale";

		// Must match the options offered by DisplaySettingsLogic.ShowUIScaleDropdown
		static readonly float[] UIScales = [1f, 1.25f, 1.5f, 1.75f, 2f];

		/// <summary>
		/// Defaults better suited to phones, applied only before settings.yaml exists
		/// (the engine then saves them, so later changes in the settings menu are kept).
		/// </summary>
		static readonly string[] FirstRunSettings =
		[
			"Graphics.CapFramerate=True",
			"Graphics.MaxFramerate=30",
		];

		/// <summary>
		/// Settings the touch controls depend on, enforced on every launch:
		/// Classic style lets a single tap select and command, right-drag (two fingers) scrolls the map
		/// in "grab" direction, and edge scrolling is disabled because the cursor stays where the last tap was.
		/// </summary>
		static readonly string[] TouchSettings =
		[
			"Game.MouseControlStyle=Classic",
			"Game.UseAlternateScrollButton=False",
			"Game.MouseScroll=Standard",
			"Game.ViewportEdgeScroll=False",
			"Game.ZoomModifier=None",
		];

		public static int Run(int argc, IntPtr argv)
		{
			var exitCode = (int)RunStatus.Error;
			try
			{
				var context = global::Android.App.Application.Context;
				var engineDir = ExtractEngineData(context);
				var supportDir = GetSupportDir(context);

				AndroidLog.Info(LogTag, $"Engine dir: {engineDir}");
				AndroidLog.Info(LogTag, $"Support dir: {supportDir}");

				Platform.OverrideEngineDir(engineDir);
				Platform.OverrideSupportDir(supportDir);
				Environment.CurrentDirectory = engineDir;

				string[] args = [.. WithDefaultMod(ReadArguments(argc, argv)), .. TouchSettings];
				if (!File.Exists(Path.Combine(supportDir, "settings.yaml")))
					args = [.. args, .. FirstRunSettings];

				// Pick a UI scale for the screen once; afterwards the player's choice in the settings menu wins.
				var uiScaleStamp = Path.Combine(supportDir, UIScaleStampFile);
				if (!File.Exists(uiScaleStamp))
				{
					var uiScale = ChooseUIScale(context);
					AndroidLog.Info(LogTag, $"Using default UI scale {uiScale}");
					args = [.. args, "Graphics.UIScale=" + uiScale.ToString(CultureInfo.InvariantCulture)];

					// Arguments only override settings in memory, so save them once the menu has loaded.
					void SaveDefaults()
					{
						Game.OnShellmapLoaded -= SaveDefaults;
						Game.Settings.Save();
						File.WriteAllText(uiScaleStamp, uiScale.ToString(CultureInfo.InvariantCulture));
					}

					Game.OnShellmapLoaded += SaveDefaults;
				}

				exitCode = (int)Game.InitializeAndRun(args);
			}
			catch (Exception e)
			{
				AndroidLog.Error(LogTag, e.ToString());
				try
				{
					ExceptionHandler.HandleFatalError(e);
				}
				catch (Exception handlerException)
				{
					AndroidLog.Error(LogTag, "Failed to write crash log: " + handlerException);
				}
			}
			finally
			{
				Log.Dispose();
			}

			// The engine keeps a lot of static state, so never reuse this process for another run.
			JavaSystem.Exit(exitCode);
			return exitCode;
		}

		/// <summary>
		/// Returns the largest UI scale offered by the settings menu that keeps the effective resolution at or
		/// above the engine's minimum of 1024x720, so high-density screens get readable text and larger buttons.
		/// </summary>
		static float ChooseUIScale(Context context)
		{
			var metrics = context.Resources.DisplayMetrics;
			var longSide = Math.Max(metrics.WidthPixels, metrics.HeightPixels);
			var shortSide = Math.Min(metrics.WidthPixels, metrics.HeightPixels);
			var maxScale = Math.Min(longSide / 1024f, shortSide / 720f);

			var scale = 1f;
			foreach (var candidate in UIScales)
				if (candidate <= maxScale)
					scale = candidate;

			return scale;
		}

		/// <summary>SDL passes the library name as argv[0]; the remaining entries are launch arguments.</summary>
		static string[] ReadArguments(int argc, IntPtr argv)
		{
			var args = new string[Math.Max(0, argc - 1)];
			for (var i = 1; i < argc; i++)
				args[i - 1] = Marshal.PtrToStringUTF8(Marshal.ReadIntPtr(argv, i * IntPtr.Size));

			return args;
		}

		/// <summary>Desktop launchers always pass Game.Mod; default to Red Alert unless one was given.</summary>
		static string[] WithDefaultMod(string[] args)
		{
			foreach (var arg in args)
				if (arg.StartsWith("Game.Mod=", StringComparison.Ordinal))
					return args;

			return [.. args, "Game.Mod=" + DefaultMod];
		}

		/// <summary>
		/// Player data (settings, logs, replays, maps and downloaded game content) lives in the app-specific
		/// external storage so it can be inspected and copied with adb or a file manager.
		/// </summary>
		static string GetSupportDir(Context context)
		{
			var dir = context.GetExternalFilesDir(null)?.AbsolutePath ?? Path.Combine(context.FilesDir.AbsolutePath, "support");
			Directory.CreateDirectory(dir);
			return dir;
		}

		/// <summary>Extracts the bundled engine data into internal storage whenever the APK is installed or updated.</summary>
		static string ExtractEngineData(Context context)
		{
			var engineDir = Path.Combine(context.FilesDir.AbsolutePath, "engine");
			var stampPath = Path.Combine(engineDir, StampFile);
			var stamp = GetPackageStamp(context);

			if (File.Exists(stampPath) && File.ReadAllText(stampPath) == stamp)
				return engineDir;

			AndroidLog.Info(LogTag, "Extracting engine data...");
			if (Directory.Exists(engineDir))
				Directory.Delete(engineDir, true);

			// ZipArchive needs a seekable stream, so copy the asset into the cache first.
			var tempZip = Path.Combine(context.CacheDir.AbsolutePath, EngineAsset);
			using (var asset = context.Assets.Open(EngineAsset))
			using (var file = File.Create(tempZip))
				asset.CopyTo(file);

			ZipFile.ExtractToDirectory(tempZip, engineDir);
			File.Delete(tempZip);

			File.WriteAllText(stampPath, stamp);
			AndroidLog.Info(LogTag, "Engine data extracted.");

			return engineDir;
		}

		static string GetPackageStamp(Context context)
		{
			// LastUpdateTime changes on every install/update of the APK.
			var info = context.PackageManager.GetPackageInfo(context.PackageName, 0);
			return info.LastUpdateTime.ToString(System.Globalization.CultureInfo.InvariantCulture);
		}
	}
}
