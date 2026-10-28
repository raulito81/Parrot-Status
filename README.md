Parrot-Status
=============

Status Item for the Parrot Zik.

http://www.parrot.com/zik

Download
========

To download the latest version, follow this link.

https://github.com/vincent-le-normand/Parrot-Status/releases/latest

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

License
=======
This software is distributed under BSD Licence.

https://raw.githubusercontent.com/vincent-le-normand/Parrot-Status/master/LICENSE

Parrot and Parrot Zik are registered trademarks.

We are not affiliated, associated, authorized, endorsed by, or in any way officially connected with Parrot S.A, or any of its subsidiaries or its affiliates. The official Parrot web site is available at www.parrot.com. 

Thanks
======
Thanks to m0sia (https://github.com/m0sia) for the reverse engineering of Parrot Zik communication protocol.

See https://github.com/m0sia/pyParrotZik for original status item project, and if you need this kind of software for Linux or Windows.
