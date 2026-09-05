# Steps to Making a New Release
... Because I always forget.

## Update build script

Open `Build/build_vars.sh` and change VERSION to the version.

## Update the flatpak metainfo.xml

In `flatpak/com.snekstudio.Snekstudio.metainfo.xml`, add the release notes for the new version.

## Update the version in the project

Open up the project in the Godot editor. Go to `Project->Project Settings->Application->Config->Version`. Modify it there.

## Commit the changes for the version and metainfo

```bash
git add flatpak/com.snekstudio.Snekstudio.metainfo.xml project.godot
git commit -m "v0.1.7 version number and release notes."
```

## Make a new tag

Make a tag in git with the version number in a format that looks like `v0.1.7`.

```bash
git tag v0.1.7
```

Remember to get the 'v' in there.

## Push the tag to the repo

```
git push origin main --tags
```

## Go and make an actual release out of it

Go to `https://github.com/ExpiredPopsicle/SnekStudio/tags`.

Find the new tag. Select it.

Click "Create release from tag".

For "Release title", put the version in the form of "Release v0.1.7".

Copy the patch notes into the "Release notes" box.

"Release label" should be set to "Latest".

Click "Publish release".

