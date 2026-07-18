# Bandcamp Zip Extractor
Scans a user-specified directory for ZIP files, extracts them and renames any extracted mp3 files. Only really useful if you regularly bulk-buy on Bandcamp Friday, I suppose...

The behaviour is as follows:
1. Prompt for target directory and validate path.
2. Scan target directory for target files.
3. For each ZIP file:
	1. Check if a directory already exists with the same name.
	2. Check if name contains dashes - if so, rename to only the last part.
	3. Extract zip file to a new folder in same location.
	4. Examine filenames in new folder for common fragments e.g "Artist - Album - " or similar. If found, use Rename-Longtracks to remove common fragments.
	5. Prompt for a secondary location where the extracted files should be copied.

As of the most recent update, several switch parameters are available:
- UpdateMetadata: This enables checking for individual MP3 files as well as ZIP files, and sets default values for the Album and Track Number tag values if these are missing. This is a frequent issue with single-track offerings on Bandcamp, IME.
- Cleanup: This enables removing the downloaded ZIP file once extraction has completed successfully.
- Overwrite: This enables forcibly re-extracting a ZIP file for which a target directory already exists and contains MP3 files.

Output is written to the console, as well as to a logfile created in the same directory from which the script is executed.
