# Godot Beep Saber VR
This is a basic implementation of the beat saber game mechanic for VR using the [Godot Game Engine](https://godotengine.org/) and the [Godot Oculus Quest Toolkit](https://github.com/NeoSpark314/godot_oculus_quest_toolkit).

The main target platform is the Oculus Quest but it should also work with SteamVR if you add the OpenVR plugin to the addons folder in the godot project.

Originally this game was (and still is) a demo game as part of the Godot Oculus Quest Toolkit. To keep the demo implementation small
this stand alone version was forked so that it can be changed and developed independent of the original demo.

You can watch [a video of the original version here](https://www.youtube.com/watch?v=kg3yiwaphlk):

[![BeepSaber Demo Video](https://raw.githubusercontent.com/NeoSpark314/godot_oculus_quest_toolkit/master/doc/images/showcase/beepsaber.jpg)](https://www.youtube.com/watch?v=kg3yiwaphlk)

# About the implementation
This game uses godot 3.2. So far this implementation allows to partially load and play maps from [BeatSaver](https://beatsaver.com/) but a lot of features are not yet implemented.

There is one demo song included that is part of the deployed package.

You can play custom songs by upacking them and putting them into folders `BeepSaber/Songs/songNameXYZ` on your Oculus Quest.
For custom songs on desktop put them into your `Downloads/BeepSaber/Songs/songNameXYZ`.

# Credits
The included Music Track is Time Lapse by TheFatRat (https://www.youtube.com/watch?v=3fxq7kqyWO8)

# Licensing
The source code of the godot beep saber game in this repository is licensed under an MIT License.