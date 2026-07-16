param(
	[parameter(mandatory=$false)]
	[boolean]$UpdateMetadata = $false,
	[parameter(mandatory=$false)]
	[boolean]$Cleanup = $false,
	[parameter(mandatory=$false)]
	[boolean]$Overwrite = $false
)

Function Extract-Zip {
    param(
        [string]$File,
        [string]$Location,
        [array]$ExtractList,
        [boolean]$Cleanup=$false
    )
    if (!(Test-Path -LiteralPath $Location)) {
        try {
            New-Item -ItemType "Directory" -Path $Location | Out-Null
        } catch {
            Write-Output "Unable to create folder $Location, error was:`n$($_.Exception.Message)" -foregroundcolor red
			"Unable to create folder $Location, error was:`n$($_.Exception.Message)" | Out-File -Filepath $global:logfile -append
        }
    }

    if ((Test-Path -LiteralPath $File) -and (Test-Path -LiteralPath $Location)) {
		if ($ExtractList) {
			Write-Output "Specific file extraction selected. Only the following files will be extracted:`n$($ExtractList)"
			"Specific file extraction selected. Only the following files will be extracted:`n$($ExtractList)" | Out-File -Filepath $global:logfile -append

			$Shell=New-Object -com Shell.Application
			$Zip=$Shell.NameSpace($File)

			foreach ($E in $ExtractList) {
				$List=@($Zip.Items() | Where-Object {$_.Name -like $E})
				if ($List) {
					foreach ($L in $List) {
						try {
							$Shell.Namespace($Location).Copyhere($L)
							Write-Output "Extracted file $($E) successfully."
							"Finished extracting contents of $File to $Location." | Out-File -Filepath $global:logfile -append
						} catch {
							Write-Error -Message "Unable to extract file $($E), error was:`n$($_.Exception.Message)"
							"Unable to extract file $($E), error was:",$_.Exception.Message | Out-File -Filepath $global:logfile -append
						}
					}
				} else {
					Write-Warning -Message "No file with name $($E) found in specified archive."
					"No file with name $($E) found in specified archive." | Out-File -Filepath $global:logfile -append
				}
				Remove-Variable -Name List -Force -ErrorAction SilentlyContinue
			}
		} else {
			Write-Output "Default mode selected, extracting all files..."
			"Default mode selected, extracting all files..." | Out-File -Filepath $global:logfile -append

			$Shell=New-Object -com Shell.Application
			$Zip=$Shell.NameSpace($File)
			try {
				foreach ($Item in $Zip.items()) {
					$Shell.Namespace($Location).Copyhere($Item)
				}
				Write-Output "Finished extracting contents of $File to $Location."
				"Finished extracting contents of $File to $Location." | Out-File -Filepath $global:logfile -append
			} catch {
				Write-Error -Message "An error occured while extracting the contents of $File to $Location; the error message was:`n$($_.Exception.Message)"
				"An error occured while extracting the contents of $File to $Location; the error message was:", "`n", "$($_.Exception.Message)" | Out-File -Filepath $global:logfile -append
			}
		}
		if ($Cleanup) {
			Write-Output "Cleanup enabled: deleting compressed file..."
			"Cleanup enabled: deleting compressed file..." | Out-File -Filepath $global:logfile -append
			Remove-Item -LiteralPath $File -Force 
		}		
    } else {
        Write-Error -Message "Unable to proceed with extraction, invalid input specified!"
		"Unable to proceed with extraction, invalid input specified!" | Out-File -Filepath $global:logfile -append
        if (!(Test-Path -LiteralPath $File)) {
            Write-Error -Message "Could not find file $File!"
			"Could not find file $File!" | Out-File -Filepath $global:logfile -append
			
        }
        if (!(Test-Path -LiteralPath $Location)) {
            Write-Error -Message "Could not find or create folder path $Location!"
			"Could not find or create folder path $Location!" | Out-File -Filepath $global:logfile -append
        }
    }
}

Function Rename-LongTracks {
	Param(
		[String]$Location,
		[string]$Replace
		
	)
	if (-not $Replace) {
		$Replace=Read-Host("Type the string to be removed from the track names")
	}
	Push-Location
	Set-Location -LiteralPath $Location
	$TrackList=Get-ChildItem -Literalpath . -Filter "*.mp3"
	foreach ($T in $TrackList) {
		$NewName=$T.Name.ToString().Replace($Replace,"")
		Rename-Item -LiteralPath $T.FullName -NewName $NewName
		Remove-Variable -name NewName -force
	}
	Pop-Location
}

Function Load-DLL {
	[boolean]$global:Loaded = $false
	while (-not $global:loaded) {
		if ($DllPath) {
			try {
				[System.Reflection.Assembly]::LoadFile("$($DllPath)\taglib-sharp.dll")
				$global:loaded=$true
			} catch {
				Write-Output "Couldn't load DLL from $($DllPath)!"
				"Couldn't load DLL from $($DllPath)!" | Out-File -Filepath $global:logfile -append
			}
		} else {
			if (Test-Path -Path "$PSScriptRoot\taglib-sharp.dll") {
				$DllPath = $PSScriptRoot+"\taglib-sharp.dll"
				try {
					[System.Reflection.Assembly]::LoadFile("$DllPath") | Out-Null
					[boolean]$global:loaded = $true
				} catch {
					Write-Output "Couldn't load DLL from $($DllPath)!"
					"Couldn't load DLL from $($DllPath)!" | Out-File -Filepath $global:logfile -append
				}
			} else {
				$PF = Get-ChildItem -LiteralPath $env:programfiles -Directory -Filter "*taglib-sharp*"
				if ($PF) {
					$DllPath = (Get-ChildItem -LiteralPath $PF.Fullname | Where-Object -FilterScript {$_.Name -like "taglib-sharp.dll"}).FullName
					if ($DllPath) {
						try {
							[System.Reflection.Assembly]::LoadFile("$($DllPath)") | Out-Null
							$global:loaded = $true
						} catch {
							Write-Output "Couldn't load DLL from $($DllPath)!"
							"Couldn't load DLL from $($DllPath)!" | Out-File -Filepath $global:logfile -append
						}
					} else {
						Write-Output "Could not find required DLL in $($PF.Fullname)"
						"Could not find required DLL in $($PF.Fullname)" | Out-File -Filepath $global:logfile -append
					}
				}
				$PFx86 = Get-ChildItem -LiteralPath ${env:programfiles(x86)} -Directory -Filter "*taglib-sharp*"
				if ($PFx86) {
					$DllPath = (Get-ChildItem -LiteralPath $PFx86.Fullname -Recurse | Where-Object {$_.Name -like "taglib-sharp.dll"}).FullName
					if ($DllPath) {
						try {
							[System.Reflection.Assembly]::LoadFile("$($DllPath)") | Out-Null
							$global:loaded=$true
						} catch {
							Write-Output "Couldn't load DLL from $($DllPath)!"
							"Couldn't load DLL from $($DllPath)!" | Out-File -Filepath $global:logfile -append
						}
					} else {
						Write-Output "Could not find required DLL in $($PFx86.Fullname)"
						"Could not find required DLL in $($PFx86.Fullname)" | Out-File -Filepath $global:logfile -append					
					}
				}
			}
		}
		if (-not $global:loaded) {
			Write-Output "Taglib-Sharp library could not be found on local system. Please refer to https://github.com/mono/taglib-sharp for more information."
			"Taglib-Sharp library could not be found on local system. Please refer to https://github.com/mono/taglib-sharp for more information." | Out-File -Filepath $global:logfile -append
		}
		break;
	}
}

# Main body

# 0. Set up logfile
# Main script body
$ScriptRoot=Split-Path -parent $MyInvocation.MyCommand.Definition
$global:logfile=$ScriptRoot+"\"+(Get-Date -format 'yyyy_MM_dd_HHmm')+"_Bandcamp_Zip_Extractor.log"
"$(Get-Date -Format 'yyyy-MM-dd HH:mm'): Bandcamp Zip Extractor" | Out-File -Filepath $global:logfile

# 1. Prompt for location to search for zip files.
[boolean]$ValidPath=$false
while (-not $ValidPath) {
	$DirPath=Read-Host -Prompt "Enter top-level path to check for zipfiles"
	try {
		Test-Path $DirPath -ErrorAction Stop
		"Searching $($DirPath) for Zip files to extract..." | Out-File -Filepath $global:logfile -append
		$ValidPath=$true
	} catch {
		Write-Warning -Message "Invalid path entered, please try again!"
		Start-Sleep 3
	}
	Clear-Host
}
Remove-Variable -name ValidPath -force

# Check individual mp3 files first if these are in scope

if ($UpdateMetadata) {
	$Mp3Files = Get-ChildItem -Recurse -Path $DirPath -Filter "*.mp3" | Where-Object -FilterScript {[datetime]$_.CreationTime -ge (Get-Date).AddHours(-48)}

	if ($Mp3Files) {
		Load-DLL
		if ($global:loaded) {
			foreach ($File in $Mp3Files) {
				Write-Output "Checking metadata for $($File.Fullname)..."
				"Checking metadata for $($File.Fullname)..." | Out-file -Filepath $global:logfile -append
				$Metadata = [Taglib.File]::Create($File.Fullname)
				if ($Metadata.Tag.Album -eq $null) {
					Write-Output "$($File.Fullname) metadata incomplete, fixing..."
					"$($File.Fullname) metadata incomplete, fixing..." | Out-file -Filepath $global:logfile -append
					$Metadata.Tag.Album = $Metadata.Tag.Title
					[boolean]$Changed = $True
				}
				if ($Metadata.Tag.Track -eq $null) {
					$Metadata.Tag.Track = 1
					[boolean]$Changed = $True
				}
				if ($Changed) {
					$Metadata.Save()
				}
				Remove-variable -name Metadata -Force -ErrorAction SilentlyContinue
				"Updated metadata for file $($File.fullname)" | Out-file -Filepath $global:logfile -append
			}
		} else {
			Write-Output "Can't perform requested metadata updates as Taglib-Sharp is not loaded!"
			"Can't perform requested metadata updates as Taglib-Sharp is not loaded!"  | Out-file -Filepath $global:logfile -append
		}
	} else {
		Write-Output "UpdateMetadata switch enabled, but no recent MP3 files found requiring metadata update!"
		"UpdateMetadata switch enabled, but no recent MP3 files found requiring metadata update!" | Out-file -Filepath $global:logfile -append
	}
}

$ZipFiles=Get-ChildItem -Recurse -LiteralPath $DirPath -Filter "*.zip"

# 2. Iterate through found files.
foreach ($Zip in $ZipFiles) {
	# 3. Check if directory already exists and is populated with mp3s
	if (Test-Path ($Zip.Fullname -replace ".zip","")) {
		if ((Get-ChildItem -LiteralPath ($Zip.Fullname -replace ".zip","") -filter "*.mp3").count -gt 0) {
			[boolean]$Done=$true
			"File $($Zip.Fullname) appears to have already been extracted." | Out-File -Filepath $global:logfile -append
		}
	}
	if (-not $Done) {
		# 4. Check for dash in filename, rename if found.
		if ($Zip.name -match " - ") {
			$NewName=($Zip.Name -split " - ")[1]
			if ($NewName -match "^ ") {
				$NewName=$NewName.TrimStart(" ")
			}
			"Renaming $($Zip.Name) to $($NewName)..." | Out-File -Filepath $global:logfile -append
			Rename-Item -LiteralPath $Zip.fullname -NewName $NewName
		}
		
		# 5. Extract zip file to new folder in same location
		if ($NewName) {
			[string]$Source=$Zip.Directory.ToString()+"\"+$NewName
			[string]$Target=$Zip.Directory.ToString()+"\"+$($NewName -replace ".zip","")
			Remove-Variable -name NewName -force
		} else {
			[string]$Source=$Zip.FullName
			[string]$Target=($Zip.FullName -replace ".zip","")
		}

		Extract-Zip -file $Source -location $Target -cleanup $Cleanup		
		# 6. Examine filenames in new folder for common fragments e.g "Artist - Album - " or similar.
		$Sample=(Get-ChildItem -LiteralPath $Target -Filter "*.mp3")[0]
		$Count=($Sample.Name -split " - ").count
		if ($Count -gt 1) {
			[string]$Prefix=""
			for ($i=0;$i -lt $($Count -1); $i++) {
				$Prefix+=($Sample -split "-")[$i]
				$Prefix+="-"
			}
			if (($Sample.Name -replace $Prefix,"") -match "^ ") {
				$Prefix+=" "
			}
			"Renaming files in directory $($Target) to remove prefix $($Prefix)..." | Out-File -Filepath $global:logfile -append
			Rename-LongTracks -location $Target -replace $Prefix
		}
		"All actions for file $($Zip.Fullname) complete." | Out-File -Filepath $global:logfile -append
	} else {
		Remove-Variable -Name done -force
	}
}