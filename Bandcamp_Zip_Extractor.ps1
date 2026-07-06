# Function declaration

Function Extract-Zip {
    param(
        [string]$file,
        [string]$location,
        [array]$extractlist,
        [boolean]$cleanup=$false
    )
    if (!(Test-Path -LiteralPath $location)) {
        try {
            New-Item -ItemType "Directory" -Path $location | Out-Null
        } catch {
            Write-Output "Unable to create folder $location, error was:`n$($_.Exception.Message)" -foregroundcolor red
			"Unable to create folder $location, error was:`n$($_.Exception.Message)" | Out-File -Filepath $global:logfile -append
        }
    }

    if ((Test-Path -LiteralPath $file) -and (Test-Path -LiteralPath $location)) {
		if ($extractlist) {
			Write-Output "Specific file extraction selected. Only the following files will be extracted:`n$($extractlist)"
			"Specific file extraction selected. Only the following files will be extracted:`n$($extractlist)" | Out-File -Filepath $global:logfile -append

			$shell=New-Object -com Shell.Application
			$zip=$shell.NameSpace($file)

			foreach ($e in $extractlist) {
				$list=@($zip.Items() | Where-Object {$_.Name -like $e})
				if ($list) {
					foreach ($l in $list) {
						try {
							$shell.Namespace($location).Copyhere($l)
							Write-Output "Extracted file $($e) successfully."
							"Finished extracting contents of $file to $location." | Out-File -Filepath $global:logfile -append
						} catch {
							Write-Error -Message "Unable to extract file $($e), error was:`n$($_.Exception.Message)"
							"Unable to extract file $($e), error was:",$_.Exception.Message | Out-File -Filepath $global:logfile -append
						}
					}
				} else {
					Write-Warning -Message "No file with name $($e) found in specified archive."
					"No file with name $($e) found in specified archive." | Out-File -Filepath $global:logfile -append
				}
				Remove-Variable -Name list -Force -ErrorAction SilentlyContinue
			}
		} else {
			Write-Output "Default mode selected, extracting all files..."
			"Default mode selected, extracting all files..." | Out-File -Filepath $global:logfile -append

			$shell=New-Object -com Shell.Application
			$zip=$shell.NameSpace($file)
			try {
				foreach ($item in $zip.items()) {
					$shell.Namespace($location).Copyhere($item)
				}
				Write-Output "Finished extracting contents of $file to $location."
				"Finished extracting contents of $file to $location." | Out-File -Filepath $global:logfile -append
			} catch {
				Write-Error -Message "An error occured while extracting the contents of $file to $location; the error message was:`n$($_.Exception.Message)"
				"An error occured while extracting the contents of $file to $location; the error message was:", "`n", "$($_.Exception.Message)" | Out-File -Filepath $global:logfile -append
			}
		}
		if ($cleanup) {
			Write-Output "Cleanup enabled: deleting compressed file..."
			"Cleanup enabled: deleting compressed file..." | Out-File -Filepath $global:logfile -append
			Remove-Item -LiteralPath $file -Force 
		}		
    } else {
        Write-Error -Message "Unable to proceed with extraction, invalid input specified!"
		"Unable to proceed with extraction, invalid input specified!" | Out-File -Filepath $global:logfile -append
        if (!(Test-Path -LiteralPath $file)) {
            Write-Error -Message "Could not find file $file!"
			"Could not find file $file!" | Out-File -Filepath $global:logfile -append
			
        }
        if (!(Test-Path -LiteralPath $location)) {
            Write-Error -Message "Could not find or create folder path $location!"
			"Could not find or create folder path $location!" | Out-File -Filepath $global:logfile -append
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
	Set-Location -LiteralPath $location
	$tracklist=Get-ChildItem -Literalpath . -Filter "*.mp3"
	foreach ($t in $tracklist) {
		$Newname=$t.Name.ToString().Replace($replace,"")
		Rename-Item -LiteralPath $t.FullName -NewName $newname
		Remove-Variable -name newname -force
	}
	Pop-Location
}

# Main body

# 0. Set up logfile
# Main script body
$scriptroot=Split-Path -parent $MyInvocation.MyCommand.Definition
$global:logfile=$scriptroot+"\"+(Get-Date -format 'yyyy_MM_dd_HHmm')+"_Bandcamp_Zip_Extractor.log"
"$(Get-Date -Format 'yyyy-MM-dd HH:mm'): Bandcamp Zip Extractor" | Out-File -Filepath $global:logfile

# 1. Prompt for location to search for zip files.
[boolean]$validpath=$false
while (!$validpath) {
	$dirpath=Read-Host -Prompt "Enter top-level path to check for zipfiles"
	try {
		Test-Path $dirpath -ErrorAction Stop
		"Searching $($dirpath) for Zip files to extract..." | Out-File -Filepath $global:logfile -append
		$validpath=$true
	} catch {
		Write-Warning -Message "Invalid path entered, please try again!"
		Start-Sleep 3
	}
	cls
}
Remove-Variable -name validpath -force

$zipfiles=Get-ChildItem -Recurse -LiteralPath $dirpath -Filter "*.zip"

# 2. Iterate through found files.
foreach ($zip in $zipfiles) {
	# 3. Check if directory already exists and is populated with mp3s
	if (Test-Path ($zip.Fullname -replace ".zip","")) {
		if ((Get-ChildItem -LiteralPath ($zip.Fullname -replace ".zip","") -filter "*.mp3").count -gt 0) {
			[boolean]$done=$true
			"File $($zip.Fullname) appears to have already been extracted." | Out-File -Filepath $global:logfile -append
		}
	}
	if (!$done) {
		# 4. Check for dash in filename, rename if found.
		if ($zip.name -match " - ") {
			$newname=($zip.Name -split " - ")[1]
			if ($newname -match "^ ") {
				$newname=$newname.TrimStart(" ")
			}
			"Renaming $($zip.Name) to $($newname)..." | Out-File -Filepath $global:logfile -append
			Rename-Item -LiteralPath $zip.fullname -NewName $newname
		}
		
		# 5. Extract zip file to new folder in same location
		if ($newname) {
			[string]$source=$zip.Directory.ToString()+"\"+$newname
			[string]$target=$zip.Directory.ToString()+"\"+$($newname -replace ".zip","")
			Remove-Variable -name newname -force
		} else {
			[string]$source=$zip.FullName
			[string]$target=($zip.FullName -replace ".zip","")
		}

		Extract-Zip -file $source -location $target -cleanup $true
		
		# 6. Examine filenames in new folder for common fragments e.g "Artist - Album - " or similar.
		$sample=(Get-ChildItem -LiteralPath $target -Filter "*.mp3")[0]
		$count=($sample.Name -split " - ").count
		if ($count -gt 1) {
			[string]$prefix=""
			for ($i=0;$i -lt $($count -1); $i++) {
				$prefix+=($sample -split "-")[$i]
				$prefix+="-"
			}
			if (($sample.Name -replace $prefix,"") -match "^ ") {
				$prefix+=" "
			}
			"Renaming files in directory $($target) to remove prefix $($prefix)..." | Out-File -Filepath $global:logfile -append
			Rename-LongTracks -location $target -replace $prefix
		}
		"All actions for file $($zip.Fullname) complete." | Out-File -Filepath $global:logfile -append
	} else {
		Remove-Variable -Name done -force
	}
}