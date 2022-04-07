# Powershell application to aid in demo rendering.
# https://github.com/froschgrosch/quake3-scripts


# === FUNCTION DECLARATIONS ===
function truncateFilename($file) { # Remove the extension from the filename string 
    return $file.Name.Remove($file.Name.Length - $file.Extension.Length, $file.Extension.Length);
}

function YNquery($prompt){ # Do a yes/no query and return $true/$false 
    do { 
        $msgboxResult = Read-Host "$prompt (y/n) "
    } while(-not @("y","n").Contains($msgboxResult))

    if ($msgboxResult -eq "y"){
        return $true; 
    } else {
        return $false;
    }
}

function randomAlphanumeric($length){ # return a random alphanumeric string 
    # Characters:
    # ABCDEFGHIJKLMNOPQRSTUVWYXZabcdefghijklmnopqrstuvwxyz0123456789
    return -join ((48..57) + (65..90) + (97..122) | Get-Random -Count $length | ForEach-Object {[char]$_});
}

function writeSession { # Saves the current session to a json file 
    ConvertTo-Json -InputObject $session | Out-File .\zz_render\session.json
}

function stopRender { # exits if the demo's stopAfterCurrent is set to true or at the end of the render list.
    if ($config.user.exitBehaviour -eq 0) { # exit w/o pause
        exit 0
    } elseif ($config.user.exitBehaviour -eq 1) { # exit w/ pause
        Pause
        exit 0
    } elseif ($config.user.exitBehaviour -eq 2) { # logout
        shutdown -l -t $config.application.shutdownTimeout
        $echo = $config.application.shutdownTimeout
        Write-Output "Logging out in $echo seconds."
        if (YNquery('Cancel?')) { shutdown -a }
        exit
    } elseif ($config.user.exitBehaviour -eq 3) { # shutdown
        shutdown -l -t $config.application.shutdownTimeout
        $echo = $config.application.shutdownTimeout
        Write-Output "Shutting down in $echo seconds."
        if (YNquery('Cancel?')) { shutdown -a }
        exit
    } 
}


# loading config
$config = Get-Content .\zz_render\config.json | ConvertFrom-Json
$outputPath = $config.application.outputPath


# === SETTINGS CHECK ===
Write-Output '=== quake3e_render Powershell application ===' ' ' 'Please check the application settings:' 

# user.mergeRender
if (@(0,1).Contains($config.user.mergeRender)){
    $echo = 'mergeRender = ' + $config.user.mergeRender
} else { 
    $echo = 'mergeRender = ' + $config.user.mergeRender + '(invalid, defaults to 0)'
    $config.user.mergeRender = 0
}
Write-Output $echo

# user.renderScale
if (@(0,1).Contains($config.user.renderScale.enabled)){
    $echo = 'renderScale = ' + $config.user.renderScale.enabled
    if ($config.user.renderScale.enabled){
        $echo1 = ' (resolution: ' + $config.user.renderScale.resolution 
        if ($config.user.renderScale.resolution[0] -lt 96 -or $config.user.renderScale.resolution[1] -lt 72){
            # width and height should probably be checked separately, but this presumably is a rare case anyway.
            $config.user.renderScale.resolution = @(96,72)
            $echo1 += ' (invalid, defaulting to 96 * 72)'
        }
        $echo += $echo1 + ')'
    }
} else {
    $echo = 'renderScale = ' + $config.user.renderScale.enabled + '(invalid, defaulting to 0)'
    $config.user.renderScale.enabled = 0
}
Write-Output $echo

# user.framerate
if ($config.user.framerate -lt 1){
    $echo = 'frameRate = ' + $config.user.framerate + '(invalid, defaulting to 30)'
    $config.user.framerate = 30
} elseif ($config.user.framerate % 1 -gt 0) {
    $rateRounded = [math]::Floor($config.user.framerate)
    $echo = 'frameRate = ' + $config.user.framerate + '(not integral, rounding down to )' + $rateRounded
    $config.user.framerate = $rateRounded 
} else {
    $echo = 'frameRate = ' + $config.user.framerate
}
Write-Output $echo

# user.ffmpegMode
if ($config.user.ffmpegMode -ge $config.application.ffmpegPipeFormats.Length -or $config.user.ffmpegMode -lt 0){
    $echo = 'ffmpegMode = ' + $config.user.ffmpegMode + ' (' + $config.application.ffmpegPipeFormats[$config.user.ffmpegMode][1] + ') (invalid, defaulting to mode 0 (' + $config.application.ffmpegPipeFormats[0][1] + '))'
    $config.user.ffmpegMode = 0;
} else {
    $echo = 'ffmpegMode = ' + $config.user.ffmpegMode + ' (' + $config.application.ffmpegPipeFormats[$config.user.ffmpegMode][1] + ')'
}
Write-Output $echo

# user.logFFmpeg
if ((0..2).Contains($config.user.logFFmpeg)){
    $echo = 'logFFmpeg = ' + $config.user.logFFmpeg
} else {
    $echo = 'logFFmpeg = ' + $config.user.logFFmpeg + ' (invalid, defaulting to 0)'
    $config.user.logFFmpeg = 0
}
Write-Output $echo

# user.logSession
if ((0..2).Contains($config.user.logSession)){
    $echo = 'logSession = ' + $config.user.logSession
} else {
    $echo = 'logSession = ' + $config.user.logSession + ' (invalid, defaulting to 1)'
    $config.user.logSession = 1
}
Write-Output $echo

# user.fontScale
$q3e_renderScale = 0
$q3e_fontScale = 1
if ($config.user.renderScale.enabled){
    $q3e_renderScale = $config.application.renderScaleMode
    $q3e_fontScale = $config.user.fontScale.target * ($config.user.renderScale.resolution[1] / $config.user.fontScale.referenceResolution[1]) 

    $q3e_fontScale = [Math]::Min([Math]::Max(0.5,$q3e_fontScale),8) # maximum range is 0.5 to 8

     $echo = 'fontScale = ' + $config.user.fontScale.target + ' @ ' + $config.user.fontscale.referenceResolution + " (con_scale set to $q3e_fontScale)"
}
Write-Output $echo

# user.exitBehaviour
if ((0..3).Contains($config.user.exitBehaviour)){
    $exitDesc = @('Exit w/o pause','Exit w/ pause','Logout','Shutdown')
    $echo = 'exitBehaviour = ' + $config.user.exitBehaviour + ' (' + $exitDesc[$config.user.exitBehaviour] + ')'
} else {
    $echo = 'exitBehaviour = ' + $config.user.exitBehaviour + ' (invalid, defaulting to 1 (Exit w/ pause))'
    $config.user.exitBehaviour = 1
}
Write-Output $echo

if ( -not $(YNquery("Are those settings correct?"))) { exit }

# === APPLICATION === 

$continueSession = $false
# Try to read existing session
if (Test-Path -PathType Leaf .\zz_render\session.json) {
    $session = Get-Content .\zz_render\session.json |  ConvertFrom-Json
    $continueSession = $true
} else { 
    # Initialize new session
    $session = New-Object -TypeName PSObject
    $temp_date = New-Object -TypeName PSObject

    Add-Member -InputObject $temp_date -MemberType NoteProperty -Name start -Value $(Get-Date)
    Add-Member -InputObject $session -MemberType NoteProperty -Name date -Value $temp_date
}

if ($config.user.mergeRender -and -not $continueSession){
        Remove-Item .\zz_render\temp\merge\*.mp4

        $session.date.start | Get-Date -UFormat "Demo list of render session %Y-%m-%d %H:%M:%S" | Out-File -Encoding ascii .\zz_render\temp\output_mergelist.txt
        Write-Output "ffconcat version 1.0" | Out-File -Encoding ascii .\zz_render\temp\ffmpeg_mergelist.txt        
}

# == Demo List Creation == 
Write-Output ' ' "=== Creating render list ===" ' '

$temp_firstdemo = $true
:createRenderList foreach($file in $(Get-ChildItem .\render_input\ | Sort-Object -Property LastWriteTime)){
    if ($continueSession) {
        Write-Output "session.json found, skipping renderlist creation..."
        break
    } 
    
    Write-Output $(-join ("Checking """, $file.name, """..."))
    
    # Check if demo format (extension) is valid
    if ( !$($config.application.validDemoFormats.Contains($file.Extension))  ) {
        Write-Output $(-join("""", $file.Extension, """ is not a valid demo format, skipping..."))
        continue createRenderList
    }

    $temp_demoName = truncateFilename($file)

    # Check for skipKeywords
    foreach ($j in $config.application.skipKeywords){
        if ( $file.name.StartsWith($j) ){
            Write-Output "Contains ""$j"", skipping..."
            continue createRenderList
        }
    }
  
    # Check if demo was already rendered
    if ($(Test-Path -PathType Leaf "$outputPath\$temp_demoName.mp4") -and -not $config.user.mergeRender) {
        if (YNquery("This demo was already rendered at some point. Would you like to render again?")){
            Remove-Item "$outputPath\$temp_demoName.mp4"
        } else {
            Write-Output ' '
            continue createRenderList
        }
    }

    $udtFilename = "..\render_input\" + $file.name
    $temp_json = .\zz_tools\UDT_json.exe -a=g -c $udtFilename | ConvertFrom-Json
    
    # Check if demo game is in the valid games list 
    if (-not $config.application.validGames.Contains($temp_json.gameStates[0].configStringValues.fs_game)){
        Write-Output $(-join ("""", $temp_json.gameStates[0].configStringValues.fs_game , """ is not a valid game, skipping...)"))
        continue createRenderList
    }

    # demo is valid, ready for further processing

    Write-Output "Adding to renderlist."

    $temp_demo = New-Object -TypeName PSObject

    $captureName = randomAlphanumeric(11)

    Add-Member -Force -InputObject $temp_demo -MemberType NoteProperty -Name captureName -Value $captureName
    Add-Member -Force -InputObject $temp_demo -MemberType NoteProperty -Name game -Value $temp_json.gameStates[0].configStringValues.fs_game
    Add-Member -Force -InputObject $temp_demo -MemberType NoteProperty -Name fileName -Value $file.Name
    Add-Member -Force -InputObject $temp_demo -MemberType NoteProperty -Name fileName_truncated -Value $(truncateFilename($file))
    Add-Member -Force -InputObject $temp_demo -MemberType NoteProperty -Name fileExtension -Value $file.Extension
    Add-Member -Force -InputObject $temp_demo -MemberType NoteProperty -Name renderFinished -Value $false
    Add-Member -Force -InputObject $temp_demo -MemberType NoteProperty -Name stopAfterCurrent -Value $false
    
    if ($config.user.mergeRender) {
        Write-Output "file merge/$captureName.mp4" | Out-File -Append -Encoding ascii .\zz_render\temp\ffmpeg_mergelist.txt
    }

    if ($temp_firstdemo){
        $temp_firstdemo = $false
        Add-Member -InputObject $session -MemberType NoteProperty -Name demo -Value @($temp_demo)
    } else {
        $session.demo += $temp_demo
    }
}
 
if (-not $continueSession) { # fresh session
    writeSession
}


Write-Output ' ' "=== Starting render ===" ' '
# == Render Loop == 
$currentDuration = 0
$env:FFREPORT = ''


:renderLoop foreach($demo in $session.demo){
   
    $captureName = $demo.captureName
    $demoName = $demo.fileName_truncated
    $game = $demo.game
    
    $fileName = $demo.fileName
    $fileExt = $demo.fileExtension

    if ($demo.renderFinished) { # Demo already rendered, skip it
        Write-Output "Skipping ""$demoName""..." ' '
        continue :renderLoop
    }
	
    Write-Output "Rendering ""$demoName""... (capturename: $captureName)"

    if($demo.stopAfterCurrent){
        "Stopping rendering after the demo."
    }


    Copy-Item ".\render_input\$fileName" ".\$game\demos\$captureName$fileExt"


    $q3e_args = @(
        "+set fs_game $game",
        '+set nextdemo quit',
        '+seta in_nograb 1',
        $('+seta r_renderScale ' + $q3e_renderScale),
        $('+seta r_renderWidth ' + $config.user.renderScale.resolution[0]),
        $('+seta r_renderHeight ' + $config.user.renderScale.resolution[1]),
        $('+seta cl_aviPipeFormat ' + $config.application.ffmpegPipeFormats[$config.user.ffmpegMode][0]),
        $('+seta cl_aviFrameRate ' +  $config.user.framerate),
        "+seta con_scale  $q3e_fontScale",
        $('+demo ' + $demo.captureName + $demo.fileExtension),
        "+video-pipe $captureName"
    )

    $demo_rstarttime = Get-Date
    $q3e_proc = Start-Process -PassThru -ArgumentList $q3e_args -FilePath .\quake3e.x64.exe
    $demo_rtime = Measure-Command {Wait-Process -InputObject $q3e_proc}

    
    Write-Output $(-join ("Time in minutes: ", $demo_rtime.TotalMinutes)) ' '
    
    $demo.renderFinished = $true

    $demo_rtime1 = New-Object -TypeName PSObject
    Add-Member -Force -InputObject $demo_rtime1 -MemberType NoteProperty -Name start -Value $demo_rstarttime
    Add-Member -Force -InputObject $demo_rtime1 -MemberType NoteProperty -Name duration -Value $demo_rtime  

    Add-Member -Force -InputObject $demo -MemberType NoteProperty -Name renderTime -Value $demo_rtime1 
    Add-Member -Force -InputObject $demo -MemberType NoteProperty -Name ffmpegModeDesc -Value $config.application.ffmpegPipeFormats[$config.user.ffmpegMode][1]

    writeSession
   
    $file = Get-Item ".\$game\videos\$captureName.mp4"
    :lockFileLoop do { # wait until the rendered .mp4 is not locked anymore
        try {
            $oStream = $file.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            if ($oStream) { $oStream.Close() }
            break lockFileLoop
        } catch {
            Start-Sleep 1
        }
    } while ($true)

    Start-Sleep 1
    if ($config.user.mergeRender){      
        
        # write the mergedemolist 
        $ffprobeData = $(.\zz_tools\ffprobe.exe -v error -hide_banner -of json -show_entries format ".\$game\videos\$captureName.mp4") | ConvertFrom-Json

        if ($ffprobeData.format.duration -gt 10) { # YouTube description chapters, for which this feature is meant for, need to be at least 10 seconds long.

            # there is probably a better way to do this, but I forgot how the timestamp black magic worked
            $timestamp = $("{0:hh\:mm\:ss}" -f $([timespan]::fromseconds($currentDuration)))

            if ($currentDuration -lt 600) { # m:ss format
                $timestamp = $timestamp.Substring(4,4)
            } elseif ($currentDuration -lt 3600) { # mm:ss format
                $timestamp = $timestamp.Substring(3,5)
            } elseif ($currentDuration -lt 36000) { # h:mm:ss format
                $timestamp = $timestamp.Substring(1,7)
            } 
            Write-Output "$timestamp $demoName" | Out-File -Encoding ascii -Append .\zz_render\temp\output_mergelist.txt
        }
        $currentDuration += $ffprobeData.format.duration

        # move movie file to mergedir
        Move-Item -Force ".\$game\videos\$captureName.mp4" "zz_render\temp\merge\$captureName.mp4"

        if (@(1,2).Contains($config.user.logFFmpeg)){
            Move-Item -Force ".\$game\videos\$captureName.mp4-log.txt" ".\zz_render\temp\merge_ffmpeglogs\$demoName.log"
        } else { # delete ffmpeg logs
            Remove-Item ".\$game\videos\$captureName.mp4-log.txt"
        }


    } else { # if -not $config.user.mergeRender
        Move-Item -Force ".\$game\videos\$captureName.mp4" "$outputPath\$demoName.mp4"

        if ($config.user.logFFmpeg -eq 1){ # save without compression
            Move-Item -Force ".\$game\videos\$captureName.mp4-log.txt" "$outputPath\$demoName.log"
        } elseif ( $config.user.logFFmpeg -eq 2){ # save with compression
            Rename-Item ".\$game\videos\$captureName.mp4-log.txt" "$demoName.log"
            .\zz_tools\7za.exe a $(-join $(Resolve-Path $outputPath).Path + "\$demoName.log.gz") "$game\videos\$demoName.log" -mx=9 -sdel | Out-Null
        } else { # delete ffmpeg logs
            Remove-Item ".\$game\videos\$captureName.mp4-log.txt"
        }
    }    
    Remove-Item ".\$game\demos\$captureName$fileExt"

    if($demo.stopAfterCurrent){
        stopRender
    }
}


# Merge with ffmpeg
if ($config.user.mergeRender){
    Write-Output "Merging with ffmpeg..."

    $temp_date = Get-Date
    
    if (@(1,2).Contains($config.user.logFFmpeg)){
        $env:FFREPORT = 'file=ffmpeg_merge.log:level=32'
    }
    .\ffmpeg.exe -v 0 -y -f concat -safe 0 -i zz_render\temp\ffmpeg_mergelist.txt -c copy "$outputPath\merge_output.mp4"
    
    if (Test-Path -PathType Leaf "$outputPath\merge_demolist.txt") {
        Remove-Item "$outputPath\merge_demolist.txt"
    }
    Move-Item .\zz_render\temp\output_mergelist.txt "$outputPath\merge_demolist.txt"
    
    # save the logs
    if ($config.user.logFFmpeg -eq 2) {
        .\zz_tools\7za.exe a zz_render\temp\merge_ffmpeglogs.tar ffmpeg_merge.log .\zz_render\temp\ffmpeg_mergelist.txt .\zz_render\temp\merge_ffmpeglogs\*.log -sdel
        .\zz_tools\7za.exe a $(-join $(Resolve-Path $outputPath).Path + "\merge_ffmpeglogs.tar.gz") zz_render\temp\merge_ffmpeglogs.tar -mx=9 -sdel -y
    } elseif ($config.user.logFFmpeg -eq 1) {
        Move-Item .\zz_render\temp\ffmpeg_mergelist.txt .\zz_render\temp\merge_ffmpeglogs\ffmpeg_mergelist.txt
        Move-Item .\ffmpeg_merge.log .\zz_render\temp\merge_ffmpeglogs\ffmpeg_merge.log
        Move-Item .\zz_render\temp\merge_ffmpeglogs "$outputPath\merge_ffmpeglogs\"
        New-Item .\zz_render\temp\merge_ffmpeglogs\
    } else {
        Remove-Item .\zz_render\temp\ffmpeg_mergelist.txt
    }
    
    Remove-Item .\zz_render\temp\merge\*.mp4
}

Add-Member -InputObject $session.date -MemberType NoteProperty -Name end -Value $(Get-Date)
$temp_date_formatted = $($session.date.end | Get-Date -UFormat "%Y_%m_%d-%H_%M_%S")

if ($config.user.logSession -eq 2){
    writeSession
    .\zz_tools\7za.exe a "zz_render\logs\session-$temp_date_formatted.json.gz" ".\zz_render\session.json" -mx=9 -sdel | Out-Null
} elseif ($config.user.logSession -eq 1) {
    writeSession
    Move-Item ".\zz_render\session.json" ".\zz_render\logs\session-$temp_date_formatted.json"
} else {
    Remove-Item ".\zz_render\session.json"
}
Write-Output "Rendering finished."

stopRender