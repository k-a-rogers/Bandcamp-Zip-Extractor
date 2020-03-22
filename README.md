# Bandcamp Zip Extractor
Scans user-specified directory for zip files, extracts them and renames any extracted mp3 files

The behaviour is as follows:
	1. Prompt for target directory and validate path.
	2. Scans target directory for zip files, and for each zip file:
		3. Check if a directory already exists with the same name. If so, check if directory contains mp3s. If yes, skip it.
		4. Check if name contains dashes - if so, rename to only the last part.
		5. Extract zip file to new folder in same location
		6. Examine filenames in new folder for common fragments e.g "Artist - Album - " or similar. If found, use Rename-Longtracks to remove common fragment

The initial version works broadly as intended, but a couple of enhancements and bug fixes will be implemented shortly:
	1. Adding a "successful extraction" check to Extract-Zip as a required pre-requisite for cleanup.
	2. Adding a "Copy to alternate directory" option for copying to e.g. mp3 player.