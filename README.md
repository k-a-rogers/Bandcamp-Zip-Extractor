# Bandcamp Zip Extractor
Scans user-specified directory for zip files, extracts them and renames any extracted mp3 files

The behaviour is as follows:

1. Prompt for a directory to check, and validate the path exists.
2. Scan the  directory for zip files, and for each zip file:
    1. Check if a directory already exists with the same name. If so, check if directory contains mp3s. If yes, skip it.
    2. Check if name contains dashes - if so, rename to only the last part.
    3. Extract zip file to new folder in same location
    4. Examine filenames in new folder for common fragments e.g "Artist - Album - " or similar. If found, use Rename-Longtracks to remove common fragment
    5. Remove original zip file.
5. When all extraction operations are complete, prompt for a target directory where extracted files will be copied. If an empty path is provided, the script halts.

The script logs actions taken on each run to a file in the local directory with names in the form "yyyy_MM_dd_HHmm_Bandcamp_Zip_Extractor.log".