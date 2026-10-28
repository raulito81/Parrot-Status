Parrot-Status
=============

Status Item for the Parrot Zik.

Fork of [vincent-le-normand/Parrot-Status](https://github.com/vincent-le-normand/Parrot-Status), updated to run on current macOS (see [CHANGELOG](CHANGELOG.md)).

http://www.parrot.com/zik

Download
========

To download the latest version, follow this link.

https://github.com/raulito81/Parrot-Status/releases/latest

Installation
============

To install the software, drag it onto your Application Folder. 

Building
========

Requires macOS 13 Ventura or later and Xcode.

```bash
xcodebuild -project "Parrot Status.xcodeproj" -scheme "Parrot Status" -configuration Release -derivedDataPath build
cp -R "build/Build/Products/Release/Parrot Status.app" /Applications/
```

The app is signed ad hoc. On first launch macOS asks for Bluetooth and notification access; allow both. It adds itself to the login items the first time it runs; turn this off from "Open at login" in its menu.

Hold Option while the menu is open to set the battery notification levels.

Diagnostics
===========

To see which API paths a headset supports, launch the app with `open -a "Parrot Status" --args -ProbeAPI YES` while the headset is connected. It asks the headset for a list of known paths and saves the answers in `~/Library/Logs/Parrot Status/probe.log`. Specific requests can be given with `-ProbeRequests '("GET /api/…", "SET /api/…?arg=…")'`.

License
=======
This software is distributed under BSD Licence.

https://github.com/raulito81/Parrot-Status/blob/main/LICENSE

Parrot and Parrot Zik are registered trademarks.

We are not affiliated, associated, authorized, endorsed by, or in any way officially connected with Parrot S.A, or any of its subsidiaries or its affiliates. The official Parrot web site is available at www.parrot.com. 

Thanks
======
Thanks to m0sia (https://github.com/m0sia) for the reverse engineering of Parrot Zik communication protocol.

See https://github.com/m0sia/pyParrotZik for original status item project, and if you need this kind of software for Linux or Windows.
