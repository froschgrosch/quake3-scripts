# Powershell application to aid in demo rendering.
# github/froschgrosch/quake3-scripts

# === USER CONFIG ===

$mergeRender = 0

$renderScale = 0
$renderResolution = @("3840","2160")
$framerate = 60

$ffmpegMode = 0

$keepLog = 0

# === APPLICATION CONFIG ===

$outputPath = ".\render_output" # no trailing backslash 

$skipKeywords=@("SKIP")
$validGames = @("baseq3")

$ffmpegModes = @(
    """-pix_fmt yuv420p -c:v libx264  -crf 23  -profile:v high -preset:v medium -maxrate:v $ffmpegBitrate -bufsize 2M -bf 2 -c:a aac -strict -2 -b:a 384k -r:a 48k -movflags faststart"""  # software h264 1080p crf23
)


# === APPLICATION ===

# Add-Type -AssemblyName System.Windows.Forms

if ($mergeRender){
    Remove-Item ".\zz_tools\merge_rendertemp\*.mp4"
    
    if (Test-Path -PathType Leaf "$outputPath\merge_demolist.txt"){
        Remove-Item "$outputPath\merge_demolist.txt"
    }

    echo "ffconcat version 1.0" | Out-File -Encoding ascii .\zz_tools\mergerenderlist.txt
}

:demoLoop foreach($file in $(Get-ChildItem .\render_input\ | Sort-Object -Property LastWriteTime)){

    $demoName = $file.Name.Remove($file.Name.Length - 6, 6)
    echo "Demo: $demoName"

    # Skip conditions
    
    foreach ($skipKeyword in $skipKeywords){
        if ( $file.Name.StartsWith($skipKeyword) ){
            echo "Contains ""$skipKeyword"", skipping..." " "
            continue demoLoop
        }
    }
  
    if ($(Test-Path -PathType Leaf "$outputPath\$demoName.mp4") -and -not $mergeRender) {

        #$msgboxResult = [System.Windows.MessageBox]::Show("This demo was already rendered at some point. Would you like to render again?","Info",4,32)
        do { $msgboxResult = Read-Host "This demo was already rendered at some point. Would you like to render again? (y/n)"} while(-not @("y","n").Contains($msgboxResult))

        if ($msgboxResult -eq "n"){
			echo " "
            continue demoLoop
        } else {
            Remove-Item "$outputPath\$demoName.mp4"
        }
    }

    $demoData = .\zz_tools\UDT_json.exe -c "..\render_input\$demoName.dm_68" | ConvertFrom-Json
    $game = $demoData.gameStates[0].configStringValues.fs_game

    if (-not  $file.name.Substring($file.Name.Length - 6, 6) -eq ".dm_68" -or -not $validGames.Contains($game)){
        echo "Not a valid demo, skipping..." " "
        continue demoLoop
    }

    
    
    # Render

    $captureName = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 11 | % {[char]$_})
	
    if ($mergeRender) {
        echo "file merge_rendertemp/$captureName.mp4" | Out-File -Append -Encoding ascii .\zz_tools\mergerenderlist.txt
        echo "Demo $demoName" | Out-File -Append .\zz_tools\merge_demolist.txt
    }


    echo "Rendering... (capturename: $captureName)"

    Copy-Item ".\render_input\$demoName.dm_68" ".\$game\demos\$captureName.dm_68"
    
	+seta in_nograb 1 `
    .\ffmpeg.exe -v 0 -y -f concat -safe 0 -i zz_tools\mergerenderlist.txt -c copy "$outputPath\merge_output.mp4"
    