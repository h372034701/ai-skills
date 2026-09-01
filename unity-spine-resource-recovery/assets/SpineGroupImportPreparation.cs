// Prepares AssetRipper-extracted Spine groups for Spine Unity's importer,
// then creates or repairs Unity wrapper assets from the imported sources.

using System;
using System.Collections.Generic;
using System.IO;
using Spine.Unity;
using UnityEditor;
using UnityEngine;

public static class SpineGroupImportPreparation {
	private const string GroupRootAssetPath = "Assets/SpineGroups/groups";
	private const float DefaultScale = 0.01f;
	private const float DefaultMix = 0.2f;

	private struct GroupSettings {
		public float scale;
		public float defaultMix;
	}

	[MenuItem("Tools/Spine/Prepare Exported Spine Groups")]
	private static void PrepareExportedSpineGroups () {
		if (!EnsureGroupRootExists())
			return;

		List<string> atlasPaths = new List<string>();
		List<string> skeletonPaths = new List<string>();
		foreach (string fullPath in Directory.GetFiles(ToFullPath(GroupRootAssetPath), "*.*", SearchOption.AllDirectories)) {
			string assetPath = ToAssetPath(fullPath);
			if (assetPath.EndsWith(".atlas", StringComparison.OrdinalIgnoreCase))
				atlasPaths.Add(assetPath);
			else if (assetPath.EndsWith(".skel", StringComparison.OrdinalIgnoreCase))
				skeletonPaths.Add(assetPath);
		}

		atlasPaths.Sort(StringComparer.OrdinalIgnoreCase);
		skeletonPaths.Sort(StringComparer.OrdinalIgnoreCase);

		int renamedAtlases = 0;
		int renamedSkeletons = 0;
		int skipped = 0;
		List<string> errors = new List<string>();

		AssetDatabase.StartAssetEditing();
		try {
			renamedAtlases = RenameForSpineImporter(atlasPaths, ".txt", ref skipped, errors);
			renamedSkeletons = RenameForSpineImporter(skeletonPaths, ".bytes", ref skipped, errors);
		} finally {
			AssetDatabase.StopAssetEditing();
		}

		AssetDatabase.SaveAssets();
		AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);

		if (errors.Count > 0) {
			Debug.LogError("Spine group preparation finished with " + errors.Count + " error(s):\n" +
				string.Join("\n", errors.ToArray()));
			return;
		}

		Debug.LogFormat(
			"Prepared Spine groups: renamed {0} atlas file(s) and {1} skeleton file(s); " +
			"skipped {2} already-prepared file(s).",
			renamedAtlases,
			renamedSkeletons,
			skipped);

		EditorApplication.delayCall += ValidateImportedAssets;
	}

	[MenuItem("Tools/Spine/Build Missing SkeletonData Assets")]
	private static void BuildMissingSkeletonDataAssets () {
		if (!EnsureGroupRootExists())
			return;

		int created = 0;
		int repaired = 0;
		int existing = 0;
		int atlasOnly = 0;
		List<string> errors = new List<string>();

		foreach (string groupAssetPath in GetGroupAssetPaths()) {
			SpineAtlasAsset[] atlasAssets = FindAssetsInFolder<SpineAtlasAsset>(groupAssetPath);
			if (atlasAssets.Length == 0) {
				errors.Add(groupAssetPath + ": no SpineAtlasAsset was found.");
				continue;
			}

			TextAsset[] skeletonFiles = FindSkeletonSources(groupAssetPath);
			if (skeletonFiles.Length == 0) {
				atlasOnly++;
				continue;
			}
			if (skeletonFiles.Length > 1) {
				errors.Add(groupAssetPath + ": more than one skeleton source file was found.");
				continue;
			}

			SkeletonDataAsset[] skeletonDataAssets = FindAssetsInFolder<SkeletonDataAsset>(groupAssetPath);
			if (skeletonDataAssets.Length > 1) {
				errors.Add(groupAssetPath + ": more than one SkeletonDataAsset was found.");
				continue;
			}

			TextAsset skeletonFile = skeletonFiles[0];
			GroupSettings settings = ReadGroupSettings(groupAssetPath);
			SkeletonDataAsset skeletonDataAsset = skeletonDataAssets.Length == 1 ? skeletonDataAssets[0] : null;
			if (skeletonDataAsset != null) {
				if (IsConfigured(skeletonDataAsset, skeletonFile, atlasAssets)) {
					existing++;
					continue;
				}

				ConfigureSkeletonDataAsset(skeletonDataAsset, skeletonFile, atlasAssets, settings);
				EditorUtility.SetDirty(skeletonDataAsset);
				if (skeletonDataAsset.GetSkeletonData(true) == null)
					errors.Add(groupAssetPath + ": repaired SkeletonDataAsset could not read " + skeletonFile.name + ".");
				else
					repaired++;
				continue;
			}

			skeletonDataAsset = ScriptableObject.CreateInstance<SkeletonDataAsset>();
			ConfigureSkeletonDataAsset(skeletonDataAsset, skeletonFile, atlasAssets, settings);
			string outputPath = AssetDatabase.GenerateUniqueAssetPath(groupAssetPath + "/SpineSkeletonData.asset");
			AssetDatabase.CreateAsset(skeletonDataAsset, outputPath);
			EditorUtility.SetDirty(skeletonDataAsset);

			if (skeletonDataAsset.GetSkeletonData(true) == null)
				errors.Add(groupAssetPath + ": created SkeletonDataAsset could not read " + skeletonFile.name + ".");
			else
				created++;
		}

		AssetDatabase.SaveAssets();
		AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);

		if (errors.Count == 0) {
			Debug.LogFormat(
				"Created {0} missing SkeletonDataAsset(s), repaired {1} asset(s), and kept {2} existing asset(s). " +
				"Skipped {3} atlas-only group(s).",
				created,
				repaired,
				existing,
				atlasOnly);
		} else {
			Debug.LogError("Spine SkeletonData creation finished with " + errors.Count + " error(s):\n" +
				string.Join("\n", errors.ToArray()));
		}

		EditorApplication.delayCall += ValidateImportedAssets;
	}

	[MenuItem("Tools/Spine/Validate Exported Spine Groups")]
	private static void ValidateImportedAssets () {
		if (!EnsureGroupRootExists())
			return;

		string[] groupAssetPaths = GetGroupAssetPaths();
		int groupsWithAtlas = 0;
		int atlasAssetCount = 0;
		int usableAtlasAssetCount = 0;
		int skeletonSourceCount = 0;
		int usableSkeletonDataCount = 0;
		int atlasOnlyGroupCount = 0;
		List<string> problems = new List<string>();

		foreach (string groupAssetPath in groupAssetPaths) {
			SpineAtlasAsset[] atlasAssets = FindAssetsInFolder<SpineAtlasAsset>(groupAssetPath);
			atlasAssetCount += atlasAssets.Length;
			if (atlasAssets.Length == 0) {
				problems.Add(groupAssetPath + ": missing SpineAtlasAsset.");
			} else {
				groupsWithAtlas++;
				foreach (SpineAtlasAsset atlasAsset in atlasAssets) {
					if (atlasAsset.GetAtlas() == null)
						problems.Add(groupAssetPath + ": could not load " + atlasAsset.name + ".");
					else
						usableAtlasAssetCount++;
				}
			}

			TextAsset[] skeletonFiles = FindSkeletonSources(groupAssetPath);
			if (skeletonFiles.Length == 0) {
				atlasOnlyGroupCount++;
				continue;
			}
			if (skeletonFiles.Length > 1) {
				problems.Add(groupAssetPath + ": more than one skeleton source file was found.");
				continue;
			}
			skeletonSourceCount++;

			SkeletonDataAsset[] skeletonDataAssets = FindAssetsInFolder<SkeletonDataAsset>(groupAssetPath);
			if (skeletonDataAssets.Length != 1) {
				problems.Add(groupAssetPath + ": expected one SkeletonDataAsset, found " + skeletonDataAssets.Length + ".");
				continue;
			}

			SkeletonDataAsset skeletonDataAsset = skeletonDataAssets[0];
			if (!IsConfigured(skeletonDataAsset, skeletonFiles[0], atlasAssets)) {
				problems.Add(groupAssetPath + ": SkeletonDataAsset has incorrect source or atlas references.");
				continue;
			}
			if (skeletonDataAsset.GetSkeletonData(true) == null) {
				problems.Add(groupAssetPath + ": could not deserialize " + skeletonFiles[0].name + ".");
				continue;
			}

			usableSkeletonDataCount++;
		}

		string summary = string.Format(
			"Spine group validation: {0}/{1} group(s) with atlases, {2}/{3} usable SpineAtlasAsset(s), " +
			"{4}/{5} usable SkeletonDataAsset(s), {6} atlas-only group(s).",
			groupsWithAtlas,
			groupAssetPaths.Length,
			usableAtlasAssetCount,
			atlasAssetCount,
			usableSkeletonDataCount,
			skeletonSourceCount,
			atlasOnlyGroupCount);

		if (problems.Count == 0)
			Debug.Log(summary);
		else
			Debug.LogError(summary + " Problems:\n" + string.Join("\n", problems.ToArray()));
	}

	private static bool EnsureGroupRootExists () {
		if (Directory.Exists(ToFullPath(GroupRootAssetPath)))
			return true;
		Debug.LogError("Spine group directory was not found: " + GroupRootAssetPath);
		return false;
	}

	private static string[] GetGroupAssetPaths () {
		string[] fullPaths = Directory.GetDirectories(ToFullPath(GroupRootAssetPath));
		Array.Sort(fullPaths, StringComparer.OrdinalIgnoreCase);
		for (int i = 0; i < fullPaths.Length; i++)
			fullPaths[i] = ToAssetPath(fullPaths[i]);
		return fullPaths;
	}

	private static TextAsset[] FindSkeletonSources (string groupAssetPath) {
		List<TextAsset> result = new List<TextAsset>();
		foreach (string fullPath in Directory.GetFiles(ToFullPath(groupAssetPath), "*.*", SearchOption.TopDirectoryOnly)) {
			string fileName = Path.GetFileName(fullPath);
			bool isSkeletonBinary = fileName.IndexOf(".skel", StringComparison.OrdinalIgnoreCase) >= 0;
			bool isSkeletonJson = fileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase) &&
				!string.Equals(fileName, "manifest.json", StringComparison.OrdinalIgnoreCase);
			if (fileName.EndsWith(".meta", StringComparison.OrdinalIgnoreCase) || (!isSkeletonBinary && !isSkeletonJson))
				continue;

			TextAsset candidate = AssetDatabase.LoadAssetAtPath<TextAsset>(ToAssetPath(fullPath));
			if (candidate != null)
				result.Add(candidate);
		}
		return result.ToArray();
	}

	private static T[] FindAssetsInFolder<T> (string groupAssetPath) where T : UnityEngine.Object {
		List<T> result = new List<T>();
		string[] guids = AssetDatabase.FindAssets("t:" + typeof(T).Name, new[] { groupAssetPath });
		foreach (string guid in guids) {
			string assetPath = AssetDatabase.GUIDToAssetPath(guid);
			string directory = Path.GetDirectoryName(assetPath).Replace('\\', '/');
			if (!string.Equals(directory, groupAssetPath, StringComparison.OrdinalIgnoreCase))
				continue;
			T candidate = AssetDatabase.LoadAssetAtPath<T>(assetPath);
			if (candidate != null)
				result.Add(candidate);
		}
		return result.ToArray();
	}

	private static GroupSettings ReadGroupSettings (string groupAssetPath) {
		GroupSettings settings = new GroupSettings { scale = DefaultScale, defaultMix = DefaultMix };
		string manifestPath = ToFullPath(groupAssetPath + "/manifest.json");
		if (!File.Exists(manifestPath))
			return settings;

		try {
			Dictionary<string, object> manifest = Spine.Json.Deserialize(new StringReader(File.ReadAllText(manifestPath)))
				as Dictionary<string, object>;
			object value;
			if (manifest != null && manifest.TryGetValue("scale", out value) && value != null)
				settings.scale = Convert.ToSingle(value);
			if (manifest != null && manifest.TryGetValue("default_mix", out value) && value != null)
				settings.defaultMix = Convert.ToSingle(value);
		} catch (Exception exception) {
			Debug.LogWarning(groupAssetPath + ": could not read manifest settings; using defaults. " + exception.Message);
		}
		return settings;
	}

	private static void ConfigureSkeletonDataAsset (
		SkeletonDataAsset skeletonDataAsset,
		TextAsset skeletonFile,
		SpineAtlasAsset[] atlasAssets,
		GroupSettings settings) {

		skeletonDataAsset.Clear();
		skeletonDataAsset.skeletonJSON = skeletonFile;
		AtlasAssetBase[] configuredAtlases = new AtlasAssetBase[atlasAssets.Length];
		for (int i = 0; i < atlasAssets.Length; i++)
			configuredAtlases[i] = atlasAssets[i];
		skeletonDataAsset.atlasAssets = configuredAtlases;
		skeletonDataAsset.scale = settings.scale;
		skeletonDataAsset.defaultMix = settings.defaultMix;
	}

	private static bool IsConfigured (
		SkeletonDataAsset skeletonDataAsset,
		TextAsset skeletonFile,
		SpineAtlasAsset[] expectedAtlases) {

		if (skeletonDataAsset.skeletonJSON != skeletonFile || skeletonDataAsset.atlasAssets == null)
			return false;
		foreach (SpineAtlasAsset expectedAtlas in expectedAtlases) {
			bool found = false;
			foreach (AtlasAssetBase configuredAtlas in skeletonDataAsset.atlasAssets) {
				if (configuredAtlas == expectedAtlas) {
					found = true;
					break;
				}
			}
			if (!found)
				return false;
		}
		return true;
	}

	private static int RenameForSpineImporter (
		List<string> sourcePaths,
		string suffix,
		ref int skipped,
		List<string> errors) {

		int renamed = 0;
		foreach (string sourcePath in sourcePaths) {
			string targetPath = sourcePath + suffix;
			if (File.Exists(ToFullPath(targetPath))) {
				skipped++;
				continue;
			}

			string error = AssetDatabase.MoveAsset(sourcePath, targetPath);
			if (string.IsNullOrEmpty(error))
				renamed++;
			else
				errors.Add(sourcePath + " -> " + targetPath + ": " + error);
		}
		return renamed;
	}

	private static string ToAssetPath (string fullPath) {
		return "Assets" + fullPath.Substring(Application.dataPath.Length).Replace('\\', '/');
	}

	private static string ToFullPath (string assetPath) {
		return Application.dataPath + assetPath.Substring("Assets".Length);
	}
}
