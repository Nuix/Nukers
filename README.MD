Nukers
======

![This script was last tested in Nuix 7.8](https://img.shields.io/badge/Script%20Tested%20in%20Nuix-7.8-green.svg)

View the GitHub project [here](https://github.com/Nuix/Nukers) or download the latest release [here](https://github.com/Nuix/Nukers/releases).

# Overview

**Written By:** Jason Wells

Sometimes you just need to completely remove work product from a case.  This repository contains a series of scripts to assist in removing:

- Custom Metadata
- Tags
- Exclusions
- Production Sets
- Item Sets
- Item Comments

Note that the scripts remove the above work product as best they can, records of these things will still exist in the case's history.

## Custom Metadata Nuker

Provides you with a selection of custom metadata fields.  You check the fields you wish to remove.  Additionally, if items were selected when the script is ran, the script allows you the option to only remove those fields from the selected items in addition to the option to remove those fields from all items in the case.

## Tag Nuker

Provides you with a selection of tags to be removed from items and the case.  It is important to note that you cannot remove a tag which still has child tags, so selecting a tag which has child tags implicitly means the script will also remove those child tags.  Child tags are removed before their parents to adhere to this.

## Exclusions

Provides you with a list of exclusion names.  You select the exclusions for which all items in those exclusions will be "included", effectively deleting the exclusion.

## Production Set Nuker

Provides you with a list of production sets.  Selected production sets are deleted from the case.

## Item Set Nuker

Provides you with a list of item sets.  Selected item sets are deleted from the case.

## Comment Nuker

Removes comment from selected items which have a comment.

# Getting Started

## Setup

Begin by downloading the latest release of this code.  Extract the contents of the archive into your Nuix scripts directory.  In Windows the script directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

## Cloning this Repository

This script relies on code from [Nx](https://github.com/Nuix/Nx) to present a settings dialog and progress dialog.  This JAR file is not included in the repository (although it is included in release downloads).  If you clone this repository, you will also want to obtain a copy of Nx.jar by either:
1. Building it from [the source](https://github.com/Nuix/Nx)
2. Downloading an already built JAR file from the [Nx releases](https://github.com/Nuix/Nx/releases)

Once you have a copy of Nx.jar, make sure to include it in the same directory as the scripts.

# License

```
Copyright 2018 Nuix

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```