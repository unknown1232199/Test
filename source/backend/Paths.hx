package backend;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;
import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.system.System;
import openfl.geom.Rectangle;
import lime.utils.Assets;
import flash.media.Sound;
import haxe.Json;
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end
#if MODS_ALLOWED
import backend.Mods;
#end

@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var SOUND_EXT = "ogg";
	inline public static var VIDEO_EXT = "mp4";

	/**
	 * Base UI path prefix for custom UI assets.
	 */
	public static var uiBasePath:String = "";

	/**
	 * UI suffix for pixel/alternate versions
	 */
	public static var uiSuffix:String = "";

	/**
	 * Get a UI asset path with support for nested folders
	 * @param assetName Base asset name (e.g., "ready", "combo")
	 * @param useSuffix Whether to append uiSuffix
	 * @return Full image path string
	 */
	public static function getUIPath(assetName:String, useSuffix:Bool = true):String
	{
		var base:String = "images/";

		// Add custom base path if set
		if (uiBasePath != null && uiBasePath.length > 0)
		{
			// Normalize path: ensure no leading/trailing slashes
			var normalizedPath = uiBasePath.replace('\\', '/');
			if (normalizedPath.startsWith("/"))
				normalizedPath = normalizedPath.substr(1);
			if (normalizedPath.endsWith("/"))
				normalizedPath = normalizedPath.substr(0, -1);

			// Add UI folder suffix
			base += normalizedPath + "/";
		}

		// Add asset name
		base += assetName;

		// Add suffix if requested
		if (useSuffix && uiSuffix != null && uiSuffix.length > 0)
			base += uiSuffix;

		return base;
	}

	/**
	 * Set UI path for standard UI
	 * @param uiName UI name
	 * @param isPixel Whether to use pixel suffix
	 */
	public static function setUIPath(uiName:String, isPixel:Bool = false):Void
	{
		if (uiName == null || uiName == "normal")
		{
			uiBasePath = "";
			uiSuffix = "";
			return;
		}

		// Handle "-pixel" suffix in name
		if (uiName == "pixel")
			isPixel = true;
		if (uiName.endsWith("-pixel"))
		{
			uiName = uiName.substr(0, uiName.length - 6);
			isPixel = true;
		}

		uiBasePath = uiName.endsWith("UI") ? uiName : uiName + "UI";
		uiSuffix = isPixel ? "-pixel" : "";
	}

	/**
	 * Reset UI path to default (normal)
	 */
	public static function resetUIPath():Void
	{
		uiBasePath = "";
		uiSuffix = "";
	}

	/**
	 * Get the UI folder prefix (compatible with old system)
	 * @deprecated Use getUIPath() instead
	 */
	public static function getUIPrefix():String
	{
		if (uiBasePath == null || uiBasePath.length == 0)
			return "";
		return uiBasePath + "/";
	}

	/**
	 * Temporary frames cache that gets cleared between states.
	 */
	static var tempFramesCache:Map<String, FlxAtlasFrames> = [];

	static var animateAtlasExistenceCache:Map<String, Bool> = [];
	static var animateAtlasAnimationCache:Map<String, String> = [];
	static var animateAtlasSpriteJsonCache:Map<String, Array<String>> = [];
	static var animateAtlasPageKeysCache:Map<String, Array<String>> = [];

	/**
	 * Initialize Paths system
	 * Call this at game startup
	 */
	public static function init():Void
	{
		// Clear temp cache on state switch
		FlxG.signals.preStateSwitch.add(function()
		{
			clearTempFramesCache();
		});
	}

	/**
	 * Clear temporary frames cache
	 * Called automatically between state switches
	 */
	public static function clearTempFramesCache():Void
	{
		if (tempFramesCache == null)
			return;

		var count = 0;
		for (key => frames in tempFramesCache)
		{
			if (frames != null && frames.parent != null)
			{
				frames.parent.persist = false;
				frames.parent.destroyOnNoUse = true;
				count++;
			}
		}

		tempFramesCache.clear();
	}

	public static function hasAnimateAtlas(key:String):Bool
	{
		return cacheAnimateAtlasData(key);
	}

	public static function getAnimateAtlasPageKeys(key:String):Array<String>
	{
		if (!cacheAnimateAtlasData(key))
			return [];

		return animateAtlasPageKeysCache.get(key.trim()).copy();
	}

	static function getAnimateAtlasSpriteJsons(key:String):Array<String>
	{
		if (!cacheAnimateAtlasData(key))
			return [];

		return animateAtlasSpriteJsonCache.get(key.trim()).copy();
	}

	static function getAnimateAtlasAnimationJson(key:String):String
	{
		if (!cacheAnimateAtlasData(key))
			return null;

		return animateAtlasAnimationCache.get(key.trim());
	}

	static function cacheAnimateAtlasData(key:String):Bool
	{
		if (key == null)
			return false;

		key = key.trim();
		if (key.length == 0)
			return false;

		if (animateAtlasExistenceCache.exists(key))
			return animateAtlasExistenceCache.get(key);

		var animationJson:String = getTextFromFile('images/$key/Animation.json');
		if (animationJson == null)
		{
			animateAtlasExistenceCache.set(key, false);
			return false;
		}

		var spriteJsons:Array<String> = [];
		var pageKeys:Array<String> = [];
		for (i in 0...32)
		{
			var suffix:String = i == 0 ? '' : Std.string(i);
			var spriteJson:String = getTextFromFile('images/$key/spritemap$suffix.json');
			if (spriteJson == null)
			{
				if (pageKeys.length > 0)
					break;
				continue;
			}

			var pageKey:String = '$key/spritemap$suffix';
			if (!fileExists('images/$pageKey.png', IMAGE))
				continue;

			spriteJsons.push(spriteJson);
			pageKeys.push(pageKey);
		}

		var exists:Bool = pageKeys.length > 0;
		animateAtlasExistenceCache.set(key, exists);
		if (!exists)
			return false;

		animateAtlasAnimationCache.set(key, animationJson);
		animateAtlasSpriteJsonCache.set(key, spriteJsons);
		animateAtlasPageKeysCache.set(key, pageKeys);
		return true;
	}

	public static function excludeAsset(key:String)
	{
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = [
		'assets/shared/music/freakyMenu.$SOUND_EXT',
		'images/touchpad/*',
		'assets/shared/mobile/touchpad/*'
	];

	static function isAssetExcluded(key:String):Bool
	{
		if (key == null)
			return false;

		for (excluded in dumpExclusions)
		{
			if (excluded == null)
				continue;

			if (excluded.endsWith('*'))
			{
				var prefix = excluded.substr(0, excluded.length - 1);
				if (key.startsWith(prefix) || ('assets/' + key).startsWith(prefix))
					return true;
			}
			else if (key == excluded || ('assets/' + key) == excluded)
				return true;
		}

		return false;
	}

	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		var keysToRemove:Array<String> = [];

		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !isAssetExcluded(key))
			{
				if (destroyGraphic(currentTrackedAssets.get(key)))
					keysToRemove.push(key); // and remove the key from local cache map
			}
		}

		for (key in keysToRemove)
			currentTrackedAssets.remove(key);

		// Match Psych's cache cleanup behavior: free collected assets promptly.
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = AssetCache.localTrackedAssets;

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		var graphicsToDestroy:Array<FlxGraphic> = [];

		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key))
			{
				var graphic:FlxGraphic = FlxG.bitmap.get(key);
				if (graphic != null)
					graphicsToDestroy.push(graphic);
			}
		}

		for (graphic in graphicsToDestroy)
		{
			destroyGraphic(graphic);
		}
	}

	public static var currentTrackedAssets:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();
	public static var lastLocalTrackedAssets:Array<String> = [];

	static function destroyGraphic(graphic:FlxGraphic):Bool
	{
		if (graphic == null)
			return false;
		graphic.destroy();
		return true;
	}

	public static function returnPixelGraphic(pixels:BitmapData):FlxGraphic
	{
		return FlxGraphic.fromBitmapData(pixels, false, null, false);
	}

	public static function getPixelAssets(key:String):String
	{
		return 'assets/images/' + key;
	}

	inline public static function image(key:String, ?library:String):FlxGraphic
	{
		return fileExists(getPath('assets/images/$key.png', IMAGE), IMAGE, library) ? returnGraphic(key, false, library)
			: FlxGraphic.fromClass(GraphicNull);
	}

	inline public static function getPath(file:String, type:AssetType = null, ?library:String):String
	{
		#if MODS_ALLOWED
		if (currentTrackedAssets.exists(file))
			lastLocalTrackedAssets.push(file);

		return modFolders(file);
		#else
		return 'assets/$file';
		#end
	}

	inline public static function returnGraphic(key:String, mod:Bool = false, ?library:String):FlxGraphic
	{
		var path = mod ? modFolders(key) : 'assets/images/$key.png';
		var graphic:FlxGraphic = FlxGraphic.fromFile(path, false, library);
		currentTrackedAssets[path] = graphic;
		lastLocalTrackedAssets.push(path);
		return graphic;
	}

	inline public static function font(key:String):String
	{
		return getPath('assets/fonts/$key');
	}

	inline public static function sound(key:String, ?library:String):String
	{
		return getPath('assets/sounds/$key.$SOUND_EXT', SOUND, library);
	}

	inline public static function soundRandom(key:String, min:Int, max:Int, ?library:String):String
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline public static function music(key:String, ?library:String):String
	{
		return getPath('assets/music/$key.$SOUND_EXT', MUSIC, library);
	}

	inline public static function voices(song:String, ?library:String):String
	{
		return getPath('assets/songs/${song.toLowerCase()}/voices.$SOUND_EXT', MUSIC, library);
	}

	inline public static function inst(song:String, ?library:String):String
	{
		return getPath('assets/songs/${song.toLowerCase()}/inst.$SOUND_EXT', MUSIC, library);
	}

	inline public static function video(key:String):String
	{
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	static public function mods(key:String = ''):String
	{
		#if MODS_ALLOWED
		return Paths.modsPath(key);
		#else
		return 'assets/$key';
		#end
	}

	static public function modsPath(key:String = ''):String
	{
		#if MODS_ALLOWED
		var modsFolder:String = '';

		if (modsFolder == '')
		{
			modsFolder = #if android 'storage/emulated/0/Android/data/com.example.funkin/files/mods/'
			#elseif web 'mods/'
			#elseif mac '/Library/Application Support/FNF/mods/'
			#else 'mods/'
			#end;
		}

		return modsFolder + key;
		#else
		return 'assets/$key';
		#end
	}

	static public function fileExists(key:String, type:AssetType = null, ?library:String):Bool
	{
		#if MODS_ALLOWED
		if (FileSystem.exists(modFolders(key)))
			return true;

		#end
		if (OpenFlAssets.exists(getPath(key, type, library), type))
			return true;

		return Assets.cache.hasImage(key) || Assets.cache.hasSound(key) || Assets.cache.hasMusic(key);
	}

	inline static public function getTextFromFile(path:String):String
	{
		#if sys
		if (FileSystem.exists(path))
			return File.getContent(path);
		#end

		if (Assets.exists(path, TEXT))
			return Assets.getText(path);

		return null;
	}

	inline static public function canUseSound():Bool
	{
		#if flash
		return false;
		#else
		return true;
		#end
	}

	static public function safeReadDirectory(path:String):Array<String>
	{
		#if MODS_ALLOWED
		try
		{
			if (FileSystem.exists(path) && FileSystem.isDirectory(path))
				return FileSystem.readDirectory(path);
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn('Error reading directory: $path - $e');
		}
		#end
		return [];
	}

	static public function safeModPathExists(path:String):Bool
	{
		#if MODS_ALLOWED
		try
		{
			return FileSystem.exists(path);
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn('Error checking path: $path - $e');
		}
		#end
		return false;
	}

	static public function safeModIsDirectory(path:String):Bool
	{
		#if MODS_ALLOWED
		try
		{
			return FileSystem.isDirectory(path);
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn('Error checking if directory: $path - $e');
		}
		#end
		return false;
	}

	static public function modsLibrary(key:String):String
	{
		#if MODS_ALLOWED
		var ndllsFolder = mods('libs');

		// Prioritize currently active mod
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var currentModLibPath = mods(Mods.currentModDirectory + '/libs/' + key);
			if (safeModPathExists(currentModLibPath))
				return currentModLibPath;
		}

		// Check global mods
		for (mod in Mods.getGlobalMods())
		{
			var libPath = mods(mod + '/libs/' + key);
			if (safeModPathExists(libPath))
				return libPath;
		}

		// Check mods root
		var file = mods('libs/' + key);
		if (safeModPathExists(file))
			return file;
		#end

		return null;
	}

	static public function modsLibraries():Array<String>
	{
		#if MODS_ALLOWED
		var ndlls:Array<String> = [];

		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var ndllsFolder = mods(Mods.currentModDirectory + '/libs');
			if (safeModPathExists(ndllsFolder) && safeModIsDirectory(ndllsFolder))
			{
				for (file in safeReadDirectory(ndllsFolder))
				{
					if (file.endsWith('.ndll') || file.endsWith('.dll'))
					{
						var name = file.substring(0, file.lastIndexOf('.'));
						ndlls.push(name);
					}
				}
			}
		}

		for (mod in Mods.getGlobalMods())
		{
			var ndllsFolder = mods(mod + '/libs');
			if (safeModPathExists(ndllsFolder) && safeModIsDirectory(ndllsFolder))
			{
				for (file in safeReadDirectory(ndllsFolder))
				{
					if (file.endsWith('.ndll') || file.endsWith('.dll'))
					{
						var name = file.substring(0, file.lastIndexOf('.'));
						ndlls.push(name);
					}
				}
			}
		}

		var ndllsFolder = mods('libs');
		if (safeModPathExists(ndllsFolder) && safeModIsDirectory(ndllsFolder))
		{
			for (file in safeReadDirectory(ndllsFolder))
			{
				if (file.endsWith('.ndll') || file.endsWith('.dll'))
				{
					var name = file.substring(0, file.lastIndexOf('.'));
					ndlls.push(name);
				}
			}
		}

		return ndlls;
		#else
		return [];
		#end
	}

	/**
	 * Check if a native library exists in mods
	 * @param key Name of the library (without extension)
	 * @return True if the library exists
	 */
	static public function modsLibraryExists(key:String):Bool
	{
		return modsLibrary(key) != null;
	}

	static public function modFolders(key:String)
	{
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
			if (safeModPathExists(fileToCheck))
				return fileToCheck;
			#if linux
			else
			{
				var newPath:String = findFile(key);
				if (newPath != null)
					return newPath;
			}
			#end
		}

		for (mod in Mods.getGlobalMods())
		{
			var fileToCheck:String = mods(mod + '/' + key);
			if (safeModPathExists(fileToCheck))
				return fileToCheck;
			#if linux
			else
			{
				var newPath:String = findFile(key);
				if (newPath != null)
					return newPath;
			}
			#end
		}
		return mods(key);
	}

	#if linux
	static function findFile(key:String):String
	{
		var targetParts:Array<String> = key.replace('\\', '/').split('/');
		if (targetParts.length == 0)
			return null;

		var baseDir:String = targetParts.shift();
		var searchDirs:Array<String> = [mods(Mods.currentModDirectory + '/' + baseDir), mods(baseDir)];

		for (part in targetParts)
		{
			if (part == '')
				continue;

			var nextDir:String = findNodeInDirs(searchDirs, part);
			if (nextDir == null)
			{
				return null;
			}

			searchDirs = [nextDir];
		}

		return searchDirs[0];
	}

	static function findNodeInDirs(dirs:Array<String>, key:String):String
	{
		for (dir in dirs)
		{
			var node:String = findNode(dir, key);
			if (node != null)
			{
				return dir + '/' + node;
			}
		}
		return null;
	}

	static function findNode(dir:String, key:String):String
	{
		try
		{
			var allFiles:Array<String> = Paths.readDirectory(dir);
			var fileMap:Map<String, String> = new Map();

			for (file in allFiles)
			{
				fileMap.set(file.toLowerCase(), file);
			}

			return fileMap.get(key.toLowerCase());
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}
	#end
	#end
	#if flxanimate
	static function loadAnimateAtlasFromKeys(spr:FlxAnimate, keys:Array<String>):Void
	{
		var cleanKeys:Array<String> = [];
		for (key in keys)
		{
			if (key == null)
				continue;

			key = key.trim();
			if (key.length > 0 && !cleanKeys.contains(key))
				cleanKeys.push(key);
		}

		if (cleanKeys.length < 1)
			return;

		var frames:flxanimate.frames.FlxAnimateFrames = new flxanimate.frames.FlxAnimateFrames();
		var animationJsons:Array<String> = [];

		for (key in cleanKeys)
		{
			var spritePages:Array<String> = getAnimateAtlasSpriteJsons(key);
			var pageKeys:Array<String> = getAnimateAtlasPageKeys(key);
			if (spritePages.length < 1 || pageKeys.length != spritePages.length)
				throw 'Missing Animate atlas spritemap data for "$key"';

			for (i in 0...spritePages.length)
				frames.addAtlas(parseAnimateSpritemap(spritePages[i], image(pageKeys[i])), true);

			var animationJson:String = getAnimateAtlasAnimationJson(key);
			if (animationJson != null)
				animationJsons.push(animationJson);
		}

		if (animationJsons.length < 1)
			throw 'Missing Animate atlas Animation.json for "${cleanKeys[0]}"';

		spr.loadSeparateAtlas(animationJsons[0], frames);
		if (Std.isOfType(spr, flxanimate.PsychFlxAnimate))
		{
			var atlas:flxanimate.PsychFlxAnimate = cast spr;
			for (i in 1...animationJsons.length)
				atlas.addAtlasLibrary(animationJsons[i]);
		}
	}

	static function parseAnimateSpritemap(spriteJson:String, graphic:FlxGraphic):FlxAtlasFrames
	{
		var data:Dynamic = Json.parse(stripBOM(spriteJson));
		var frames:FlxAtlasFrames = new FlxAtlasFrames(graphic);
		var sprites:Array<Dynamic> = cast data.ATLAS.SPRITES;

		for (sprite in sprites)
		{
			var limb:Dynamic = sprite.SPRITE;
			var rotated:Bool = limb.rotated == true;
			var rect:FlxRect = FlxRect.get(limb.x, limb.y, limb.w, limb.h);
			if (rotated)
				rect.setSize(rect.height, rect.width);

			frames.addAtlasFrame(rect, FlxPoint.get(limb.w, limb.h), FlxPoint.get(), limb.name, rotated ? FlxFrameAngle.ANGLE_NEG_90 : FlxFrameAngle.ANGLE_0);
		}

		return frames;
	}

	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
	{
		var changedAnimJson = false;
		var changedAtlasJson = false;
		var changedImage = false;

		if (Std.isOfType(folderOrImg, Array))
		{
			loadAnimateAtlasFromKeys(spr, cast folderOrImg);
			return;
		}

		if (spriteJson != null)
		{
			changedAtlasJson = true;
			spriteJson = File.getContent(spriteJson);
		}

		if (animationJson != null)
		{
			changedAnimJson = true;
			animationJson = File.getContent(animationJson);
		}

		// Folder/path-based auto-detection with full multi-page support
		if (Std.isOfType(folderOrImg, String))
		{
			var originalPath:String = folderOrImg;

			// Arrays to hold each spritemap page (JSON content + loaded graphic)
			var spritePages:Array<String> = [];
			var spriteImgs:Array<FlxGraphic> = [];

			if (!changedAtlasJson)
			{
				var cachedSpritePages:Array<String> = getAnimateAtlasSpriteJsons(originalPath);
				var cachedPageKeys:Array<String> = getAnimateAtlasPageKeys(originalPath);
				if (cachedSpritePages.length > 0 && cachedPageKeys.length == cachedSpritePages.length)
				{
					changedImage = true;
					changedAtlasJson = true;
					for (pageJson in cachedSpritePages)
						spritePages.push(pageJson);
					for (pageKey in cachedPageKeys)
						spriteImgs.push(image(pageKey));
				}
			}
			else
			{
				// spriteJson was given externally - just locate matching image(s)
				for (i in 0...10)
				{
					var st:String = (i == 0) ? '' : '$i';
					if (fileExists('images/$originalPath/spritemap$st.png', IMAGE))
					{
						changedImage = true;
						spriteImgs.push(image('$originalPath/spritemap$st'));
					}
					else if (changedImage)
						break;
				}
			}

			// Fallback to loading the folder as a plain image
			if (!changedImage)
			{
				changedImage = true;
				folderOrImg = image(originalPath);
			}

			if (!changedAnimJson)
			{
				animationJson = getAnimateAtlasAnimationJson(originalPath);
				if (animationJson == null)
					animationJson = getTextFromFile('images/$originalPath/Animation.json');
				changedAnimJson = (animationJson != null);
			}

			if (spritePages.length > 0)
			{
				var frames:flxanimate.frames.FlxAnimateFrames = new flxanimate.frames.FlxAnimateFrames();
				for (i in 0...spritePages.length)
					frames.addAtlas(parseAnimateSpritemap(spritePages[i], spriteImgs[i]), true);

				spr.loadSeparateAtlas(animationJson, frames);
				return;
			}
		}

		spr.loadAtlasEx(folderOrImg, spriteJson, animationJson);
	}
	#end

	public static function readDirectory(directory:String):Array<String>
	{
		#if MODS_ALLOWED
		var files:Array<String> = safeReadDirectory(directory);
		if (files.length > 0)
			return files;

		#if android
		var prefix:String = directory.endsWith('/') ? directory : directory + '/';
		var filenames:Array<String> = [];
		for (asset in Assets.list())
		{
			if (!asset.startsWith(prefix))
				continue;
			var remainder:String = asset.substr(prefix.length);
			var name:String = remainder.split('/')[0];
			if (name.length > 0 && !filenames.contains(name))
				filenames.push(name);
		}
		return filenames;
		#else
		return [];
		#end
		#else
		var dirs:Array<String> = [];
		for (dir in Assets.list().filter(folder -> folder.startsWith(directory)))
		{
			@:privateAccess
			for (library in lime.utils.Assets.libraries.keys())
			{
				if (library != 'default' && Assets.exists('$library:$dir') && (!dirs.contains('$library:$dir') || !dirs.contains(dir)))
					dirs.push('$library:$dir');
				else if (Assets.exists(dir) && !dirs.contains(dir))
					dirs.push(dir);
			}
		}
		return dirs.map(dir -> dir.substr(dir.lastIndexOf("/") + 1));
		#end
	}

	public static function getModStateScripts(folderName:String):Array<String>
	{
		var scripts:Array<String> = [];
		var processedPaths:Map<String, Bool> = new Map();
		
		if (folderName == null || (folderName != "state" && folderName != "substate" && folderName != "states" && folderName != "substates"))
			return scripts;
		
		var folderVariants:Array<String> = [];
		if (folderName == "state" || folderName == "states")
			folderVariants = ["scripts/states/", "scripts/state/"];
		else if (folderName == "substate" || folderName == "substates")
			folderVariants = ["scripts/substates/", "scripts/substate/"];
		
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			for (variant in folderVariants)
			{
				var currentModScriptsPath:String = mods(Mods.currentModDirectory + '/' + variant);
				if (safeModPathExists(currentModScriptsPath) && safeModIsDirectory(currentModScriptsPath))
				{
					var modScripts:Array<String> = safeReadDirectory(currentModScriptsPath);
					for (file in modScripts)
					{
						if ((file.endsWith('.hx') || file.endsWith('.hscript')) && !processedPaths.exists(file))
						{
							var fullPath:String = currentModScriptsPath + file;
							scripts.push(fullPath);
							processedPaths.set(file, true);
						}
					}
				}
			}
		}
		
		for (globalMod in Mods.getGlobalMods())
		{
			for (variant in folderVariants)
			{
				var globalModScriptsPath:String = mods(globalMod + '/' + variant);
				if (safeModPathExists(globalModScriptsPath) && safeModIsDirectory(globalModScriptsPath))
				{
					var globalScripts:Array<String> = safeReadDirectory(globalModScriptsPath);
					for (file in globalScripts)
					{
						if ((file.endsWith('.hx') || file.endsWith('.hscript')) && !processedPaths.exists(file))
						{
							var fullPath:String = globalModScriptsPath + file;
							scripts.push(fullPath);
							processedPaths.set(file, true);
						}
					}
				}
			}
		}
		
		for (variant in folderVariants)
		{
			var rootModsScriptsPath:String = mods(variant);
			if (safeModPathExists(rootModsScriptsPath) && safeModIsDirectory(rootModsScriptsPath))
			{
				var rootScripts:Array<String> = safeReadDirectory(rootModsScriptsPath);
				for (file in rootScripts)
				{
					if ((file.endsWith('.hx') || file.endsWith('.hscript')) && !processedPaths.exists(file))
					{
						var fullPath:String = rootModsScriptsPath + file;
						scripts.push(fullPath);
						processedPaths.set(file, true);
					}
				}
			}
		}
		
		return scripts;
	}
}
