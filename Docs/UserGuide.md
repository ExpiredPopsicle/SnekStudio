# Downloads

You can download **stable releases** or **nightly releases**. Both options are available for **Linux** and **Windows**.

## Latest Release

The latest release can be downloaded [here](https://github.com/ExpiredPopsicle/SnekStudio/releases/latest).

## Other Releases

To access different versions, visit the [Releases Page](https://github.com/ExpiredPopsicle/SnekStudio/releases).

## Linux Users

A **Flatpak** is available for Linux users.

If your platform is not available for download, you can open the project in the **Godot Editor**. More information on this process can be found in the README: [Getting Started](https://github.com/ExpiredPopsicle/SnekStudio/README.md#getting-started-linux--windows).



# User Guide
The user guide is for first time users, or users wanting to learn a bit more about what SnekStudio can offer. It is more detailed than the Getting Started guide, but covers similar content.

## Launching SnekStudio
Open the release of SnekStudio. You can double click the file named "snekstudio" on Linux, and Windows. Wait for the splashscreen to disappear which indicates the application is ready to use.

![SnekStudio splash screen which indicates the program is loading](Images/splashscreen.png)

By default, some initial settings are applied and an example model is loaded. This model is named "Samplesnek", the VRM file can be found in the SampleModels -> VRM folder.

![Main user interface of SnekStudio with default settings](Images/mainui.png)

## Exploring the Main User Interface
Let's explore the main user interface. The image below contains numbers that represent the following headings.

![Main user interface of SnekStudio with numbers for help](Images/mainui-num.png)

### 1. The menu bar
This is where all the settings are found, there are four items on the menu bar: File, Settings, Modules and Help.

To load a new model (VRM) you can use the File -> Open VRM item.

### 2. The model area
The model area is displayed through a camera that can be controlled by the mouse and keyboard:
* Middle Mouse - Rotate Camera
* Shift + Middle Mouse - Pan Camera
* Mouse Wheel - Zoom Camera

The model area also features a default background color and floor, displayed in the image below:
![The default background color and floor](Images/floor-background.png)


## Exploring the Menu Bar

The menu bar has several menus, outlined below:

### File menu

![The file menu](Images/file-menu.png)

To change the model currently loaded, use the File -> Open VRM.

To backup, and restore settings, use the File -> Load/Save Settings.

### Settings menu

![The settings menu](Images/settings-menu.png)

To change the background color, hide window decorations, control VSync mode and enable transparent background, use the Settings -> Window menu.

![Window settings](Images/window-settings.png)

To change the FOV of the camera, use the Settings -> General Settings menu.

![Camera FOV](Images/general-settings.png)


### Modules menu

![The modules menu](Images/modules-menu.png)

The main menu you will access is the modules area which includes the mod list.

## Window Options
Windows that are opened through menu items and other interactions also have a few features:
* You can pop out a window from the main user interface by clicking the "p" in the top right corner.
* You can close the window by clicking the "x" in the top right corner.
* You can resize the windows as you would any other window.

![Options for windows](Images/window-close-up.png)

## Exploring the Mod List
The mod list includes available mods for SnekStudio. Check out the mod install guide (TODO) for installing mods into SnekStudio.

![Mod list with numbers](Images/mod-list-num.png)

### 1. Mods currently loaded
The list shows active mods that are loaded into the scene. You can add more mods, the default does not include some useful mods!

Clicking on a mod on this list will display the settings, like so:

![Mod settings shown](Images/scene-basic-mod-settings.png)

Any changes you make to these settings is instantly saved and applied, there are no save buttons!


### 2. Mod instance name
Each instance of a mod can have a different name. By default, a mod has the instance name that corresponds to the mod name.

### 3. Mod list controls
You can add, remove or move a mod up or down using these buttons. You can add more than one instance of a mod at a time. For example, you might have two or three ModelToggle mods for different toggles.

### 4. Any active errors
Any errors from within mods is shown here, currently there is an error describing that there is no camera selected in the MediaPipeController mod.


## Tracking in SnekStudio
You might have noticed that the model isn't "moving" or tracking by default. This is also evident in the error about a camera not being selected.

Before we address this error, it is important to look at how tracking works in SnekStudio. 

There are several mods that are involved in the tracking process and have specific orders of execution and must be ordered correctly in the mod list:

1. MediaPipeController - tracks hands, and face based on camera data for 50 blend shapes. 
2. EyeAdjustments - applies some small fixes to eyes as per settings.
3. MediaPipeToVrmBlendshapes (optional) - converts MediaPipe blend shapes to basic VRM blend shapes, likely wanted for most VRM 0.X models.
4. BlendShapeScalingAndOffset - change blend shape scaling, offset and smoothing.
5. LipSync (optional) - allows you to use your microphone to track lip and mouth movement. Must be before animation applier.
6. AnimationApplier - applies animations to the model.
7. RotateTrackers (optional) - rotates trackers to compensate for slight camera angles, must be between mod 1 (MediaPipe) and 7 (PoseIK) in this list.
8. PoseIK - Poses model based on tracker input.
9. BlendShapeOverride (optional) - overrides blend shape values directly.

You will notice some missing from the initial mods, that's OK! You don't need all of them to work, the optional mods are sometimes useful for your setup.


### Other Tracking Mods
There are a few other tracking mods, these are for those who are feeling adventurous or want to try some other tracking styles.

* VMCController - allows for receiving Virtual Motion Capture (VMC) data from other applications such as VSeeFace.
* HOTAS - adds support for animating model that controls a HOTAS-style controller.
* GraphicsTablet - a work in progress mod that allows graphics tablet motions to be converted into SnekStudio tracking.
* VMCSender - a work in progress mod that allows sending VMC-compatible data to other applications.


### Getting Tracking to Work
Let's solve that error! 

To solve the camera error, click on the MediaPipeController mod and change the Video Device to your webcam or video device:

![MediaPipeController video device selection](Images/mediapipecontroller-video-device.png)

You may see more than one device with the same name. In the example there are two C922 cameras, only one will work. To find out, select the device and see if tracking is working on the model. Try other devices until it does.

![Tracking working](Images/mediapipecontroller-tracking-example.png)

In the settings, you can also adjust if hand tracking is enabled, or other settings like head rotation smoothing, blending and reset time. Play with these as you wish to. More details on each can be found in the (TODO) MediaPipeController mod docs.


## Changing Scene Details

You can now move on to setting up the scene with the right lighting, and directional light colors. These are all controlled under the SceneBasic mod, as shown below.

![SceneBasic mod settings](Images/scene-basic-mod-settings.png)

You can disable the ground plane (floor), by scrolling to the bottom and disabling the "Draw Ground Plane" option.

Finally, enable transparent background in the Settings menu bar -> Window menu item.

![Final settings for stream setup](Images/transparent-background.png)


## Hiding User Interface

To hide all user interface dialogs, press the escape key. You can restore these dialogs at any time by pressing the escape key again.


## Broadcast Software Setup

Unlike other applications, SnekStudio does not have Spout2 or other support for capturing the window.

Simply add a new window capture, and select the window making sure you have transparency enabled in SnekStudio.

The final setup might look like this on Linux:

![Linux OBS SnekStudio](Images/obs-setup-linux.png)

### Twitch Integration

If you wish to use mods that feature redeems (HeadPats, ObjectThrower, ModelToggle), you must add the TwitchIntegration mod.

Navigate to the mod list (Modules -> Mod List), and add the TwitchIntegration mod on the add dialog:

![Add twitch integration mod](Images/twitch-integration-add.png)

Immediately, your web browser will open and display a Twitch authorization page:

![Twitch authorization for SnekStudio](Images/twitch-integration-authorization.png)

Read all permissions carefully that you are granting to SnekStudio, then click Authorize or Cancel.

If you click Authorize you will be redirected back to a localhost website:

![Twitch authorization callback page](Images/twitch-integration-callback.png)


You can close the tab and return to SnekStudio. The mods that rely on redeems will now work.

Feel free to test redeems using the Modules -> Channel Event Tester tool.

![Channel events tool with sample data](Images/channel-events-tester.png)
