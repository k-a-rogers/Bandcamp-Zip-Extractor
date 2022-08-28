# Function declaration

Function Extract-Zip {
    param(
        [string]$file,
        [string]$location,
        [array]$extractlist,
        [boolean]$cleanup=$false
    )
    if (!(Test-Path $location)) {
        try {
            mkdir $location | out-Null
        } catch {
			Write-Output "Unable to create folder $location, error was:`n$($_.Exception.Message)"
			"Unable to create folder $location, error was:`n$($_.Exception.Message)" | Out-file -Filepath $global:logfile -append
        }
    }
    if ($extractlist) {
        Write-Output "Specific file extraction selected. Only the following files will be extracted:`n$($extractlist)"
		"Specific file extraction selected. Only the following files will be extracted:`n$($extractlist)" | Out-file -Filepath $global:logfile -append

    } else {
        Write-Output "Default mode selected, extracting all files..."
		"Default mode selected, extracting all files..." | Out-file -Filepath $global:logfile -append
    }
    if ((Test-Path $file) -and (Test-Path $location)) {
        # Instantiate a new shell object and namespace
        $shell=New-Object -com Shell.Application
        $zip=$shell.NameSpace($file)
        # Check if the $extractlist parameter is set, and extract files accordingly.
        if (!$extractlist) {
            # Extract list is not set so default to extracting all files.
            try {
                foreach ($item in $zip.items()) {
                    $shell.Namespace($location).Copyhere($item)
                }
                Write-Output "Finished extracting contents of $file to $location." 
			    "Finished extracting contents of $file to $location." | Out-file -Filepath $global:logfile -append
            } catch {
                Write-Output "An error occurred while extracting the contents of $file to $location; the error message was:`n$($_.Exception.Message)"
			    "An error occurred while extracting the contents of $file to $location; the error message was:", "`n", "$($_.Exception.Message)" | Out-file -Filepath $global:logfile -append
            }
        } else {
            # Extract list is set, so iterate through each name in the array and extract that file from the zip. Items in extractlist are not assumed to be unique matches, so a list of matching contents is generated for each item and a foreach loop iterates through the list, extracting each match individually.
            foreach ($e in $extractlist) {
                $list=@($zip.Items() | Where-Object {$_.Name -like $e})
                if ($list) {
                    foreach ($l in $list) {
                        try {
                            $shell.Namespace($location).Copyhere($l)
                            Write-Output "Extracted file $($e) successfully."
                            "Finished extracting contents of $file to $location." | Out-file -Filepath $global:logfile -append
                        } catch {
                            Write-Output "Unable to extract file $($e), error was:`n$($_.Exception.Message)"
                            "Unable to extract file $($e), error was:",$_.Exception.Message | Out-file -Filepath $global:logfile -append
                        }
                    }
                } else {
                    Write-Output "No file with name $($e) found in specified archive."
                    "No file with name $($e) found in specified archive." | Out-file -Filepath $global:logfile -append
                }
				Remove-Variable -Name list -Force -ErrorAction SilentlyContinue
            }
        }
		if ($cleanup) {
			Write-Output "Cleanup enabled: deleting compressed file..."
			"Cleanup enabled: deleting compressed file..." | Out-File -Filepath $global:logfile -append
			Remove-Item -Path $file -Force 
		}		
    } else {
        Write-Output "Unable to proceed with extraction, invalid input specified!"
		"Unable to proceed with extraction, invalid input specified!" | Out-file -Filepath $global:logfile -append
        if (!(Test-Path $file)) {
            Write-Output "Could not find file $file!"
			"Could not find file $file!" | Out-file -Filepath $global:logfile -append
			
        }
        if (!(Test-Path $location)) {
            Write-Output "Could not find or create folder path $location!"
			"Could not find or create folder path $location!" | Out-file -Filepath $global:logfile -append
        }
    }
}

Function Rename-LongTracks {
	Param(
		[String]$location,
		[string]$replace
		
	)
	if (!$replace) {
		$replace=Read-Host("Type the string to be removed from the track names")
	}
	Push-Location
	Set-Location $location
	$tracklist=Gci -Filter "*.mp3"
	foreach ($t in $tracklist) {
		$newname=$t.Name.ToString().Replace($replace,"")
		Rename-Item -Path $t.FullName -NewName $newname
		Remove-Variable -name newname -force -ErrorAction silentlycontinue
	}
	Pop-Location
}

# Main body

# 0. Set up logfile
# Main script body
$scriptroot=Split-Path -parent $MyInvocation.MyCommand.Definition
$global:logfile=$scriptroot+"\"+(Get-Date -format 'yyyy_MM_dd_HHmm')+"_Bandcamp_Zip_Extractor.log"
"$(Get-Date -Format 'yyyy-MM-dd HH:mm'): Bandcamp Zip Extractor" | Out-file -Filepath $global:logfile

# 1. Prompt for location to search for zip files.
[boolean]$validpath=$false
while (!$validpath) {
	$dirpath=Read-Host -Prompt "Enter top-level path to check for zipfiles"
	try {
		Test-Path $dirpath -ErrorAction Stop
		"Searching $($dirpath) for Zip files to extract..." | Out-file -Filepath $global:logfile -append
		$validpath=$true
	} catch {
		Write-Output "Invalid path entered, please try again!"
		Start-sleep 3
	}
	cls
}
Remove-variable -name validpath -force

$zipfiles=GCI -Recurse -Path $dirpath -Filter "*.zip"

# 2. Iterate through found files.
foreach ($zip in $zipfiles) {
	# 3. Check if directory already exists and is populated with mp3s
	if (Test-Path ($zip.Fullname -replace ".zip","")) {
		if ((Gci -path ($zip.Fullname -replace ".zip","") -filter "*.mp3").count -gt 0) {
			$repeat=Read-Host -Prompt "File $($zip.Fullname) has already been extracted, repeat? Y/N"
			if ($repeat -eq "N") {
				[boolean]$done=$true
				"File $($zip.Fullname) has already been extracted and user selected not to repeat." | Out-file -Filepath $global:logfile -append
			} else {
				[boolean]$done=$false
			}
		}
	}
	if (!$done) {
		# 4. Check for dash in filename, rename if found.
		if ($zip.name -match "-") {
			$newname=($zip.Name -split "-")[1]
			if ($newname -match "^ ") {
				$newname=$newname.TrimStart(" ")
			}
			"Renaming $($zip.Name) to $($newname)..." | Out-file -Filepath $global:logfile -append
			rename-item -Path $zip.fullname -NewName $newname
		}
		
		# 5. Extract zip file to new folder in same location
		if ($newname) {
			[string]$source=$zip.Directory.ToString()+"\"+$newname
			[string]$target=$zip.Directory.ToString()+"\"+$($newname -replace ".zip","")
			Remove-Variable -name newname -force -Erroraction silentlycontinue
		} else {
			[string]$source=$zip.FullName
			[string]$target=($zip.FullName -replace ".zip","")
		}

		Extract-Zip -file $source -location $target -cleanup $true
		
		# 6. Examine filenames in new folder for common fragments e.g "Artist - Album - " or similar.
		$sample=(GCI -path $target -Filter "*.mp3")[0]
		$count=($sample.Name -split "-").count
		if ($count -gt 1) {
			[string]$prefix=""
			for ($i=0;$i -lt $($count -1); $i++) {
				$prefix+=($sample -split "-")[$i]
				$prefix+="-"
			}
			if (($sample.Name -replace $prefix,"") -match "^ ") {
				$prefix+=" "
			}
			"Renaming files in directory $($target) to remove prefix $($prefix)..." | Out-file -Filepath $global:logfile -append
			Rename-LongTracks -location $target -replace $prefix
		}
		"All actions for file $($zip.Fullname) complete." | Out-file -Filepath $global:logfile -append
	} else {
		Remove-Variable -Name done -force
	}
}

# 7. Copy files to remote location e.g. music player
$playerpath=Read-Host -Prompt "Enter full path of directory where extracted files should be copied. Press Enter to skip"
if ($playerpath -ne "") {
	try {
		Test-Path -Path $playerpath -ErrorAction Stop
		Write-Output "Target directory found."
		$folders=GCI -path $dirpath -Recurse | ? {$_.Mode -match "^d" -and $_.CreationTime -gt ((get-Date).AddDays(-1))} | Sort-Object -Property Fullname
		$dirmatch=($dirpath -replace "\\","\\") -replace ":","\:"
		foreach ($folder in $folders) {
			$destination=$folder.FullName -replace $dirmatch,$playerpath
			if (!(Test-Path $destination)) {
				New-Item -Type Directory -Path $destination
			}
			$files=Gci -Path $folder.Fullname -filter "*.mp3"
			if ($files) {
				foreach ($file in Gci -Path $folder.Fullname) {
					Copy-Item -Path $file.Fullname -Destination $destination
				}
			}
			Remove-Variable -name destination,files -force -erroraction silentlycontinue
		}
	} catch {
		Write-Output "Target directory $($playerpath) could not be found!"
	}
}