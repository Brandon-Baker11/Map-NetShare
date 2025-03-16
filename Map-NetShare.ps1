function Map-NetShare {
    param(
        [string][Parameter(Mandatory = $true, Position = 0)] $email
    )
    Import-Module ActiveDirectory

    # Pulls the user's samaccount from AD by filtering using the user's email address 
    $UserProfile = (Get-ADUser -Filter { Emailaddress -like $Email } -Properties * | Select-Object SamAccountName).samaccountname

    if (!$UserProfile) {
        Write-Host "No AD user profile found with that email."
    }
    else {
        # This queries AD to find the first object that matches the $userprofile and returns the 'member of' properties, returning the network drives they have access to
        $UserGroups = ([ADSISEARCHER]"samaccountname=$userprofile").Findone().Properties.memberof

        # An empty array that will store all of the shared drives once they are formatted 
        $myTable = @()

        # A foreach loop that will get the network share name and description and regexes it so we get the name and path to the share drive
        foreach ($UserGroup in $Usergroups) {
            $GroupDescription = $null
            $UserGroup = $UserGroup.ToString() # Ensures that the $usergroup variable is a string
            $GroupDescription = ((Get-ADGroup "$UserGroup" -Properties *).description) # This grabs the description which is the path of the network share
            $UserGroup = $UserGroup -replace '^CN=([^,]+).+$', '$1' # This overwrites the original $usergroup variable with the formatted version

            If (($GroupDescription -like "*\\*")) {
                # If the description has \\ it will create a custom object. $usergroup being the name and $groupdescription being the network share path and adds it to $mytable
                $myTable += [pscustomobject]@{Group = $UserGroup; Share = $GroupDescription }  
            }
        }
    }

    # This loop will allow the tech to input the paths to be mapped to the terminal
    $patharray = @()
    while ($true) {
        Write-host "`n`n******* USER'S ACCESSIBLE SHARES *******"
        $myTable | Format-Table -Wrap
        Write-Host "Paths to be mapped:"; $patharray
        $pathtomap = Read-Host -Prompt "`nCopy and Paste the path you want to map (Do not include qoutes!)"
        $patharray += $pathtomap
        $addpath = Read-Host -Prompt "`nWould you like to add another path? [Y] or [N]"
        
        if (($addpath -eq "Y") -or ($addpath -eq "y")) {
            continue
        }
        elseif (($addpath -eq "N") -or ($addpath -eq "n")) {
            break
        }
        else {
            Write-Host "`nInvalid selection... Returning you to path entry prompt"; Start-Sleep -Seconds 2
        }

    }

    $pcname = Read-Host -Prompt "Enter the user's computer name" # Prompt the technician to provide the user's computer name

    if (Test-Connection $pcname -Quiet) {
        # Test to see if the computer is online, if so, continues to create the paths.txt file and tools folder if necessary
        if (!(Test-Path -Path "\\$pcname\c$\tools")) {
            Write-Host "Creating tools folder on $pcname...`n"; Start-Sleep -Seconds 1.5
            New-Item -Path "\\$pcname\c$\" -Name "tools" -ItemType Directory
            Write-Host "Folder '\\$pcname\c$\tools' successfully created!`n"; Start-Sleep -Seconds 1.5
            Write-Host "Creating file \\$pcname\c$\tools\paths.txt"; Start-Sleep -Seconds 1.5
            New-Item -Path "\\$pcname\c$\tools\paths.txt" -ItemType File -Force
            Write-Host "File '\\$pcname\c$\tools\paths.txt' successfully created!`n"; Start-Sleep -Separator 1.5
            $patharray | Out-File -FilePath "\\$pcname\c$\tools\paths.txt" -Force # Outputs the share paths contained in $patharray
        }
        else {
            Write-Host "Creating file \\$pcname\c$\tools\paths.txt"; Start-Sleep -Seconds 1.5
            New-Item -Path "\\$pcname\c$\tools\paths.txt" -ItemType File -Force
            Write-Host "File '\\$pcname\c$\tools\paths.txt' successfully created!`n"; Start-Sleep -Separator 1.5
            $patharray | Out-File -FilePath "\\$pcname\c$\tools\paths.txt" -Force 
        }
        # Checks to see if the batch file is reachable, in my case, it was stored on a network share drive
        if (Test-Path -Path "\\path\to\file\MapShares.bat") {
            # Checks if the batch file is already on the target computer
            if (Test-Path -Path "\\$pcname\c$\tools\MapShares.bat") {
                Write-Host "`nMapShares.bat file already in user's tools folder"; Start-Sleep -Seconds 1.5
                Write-Host "`nRunning MapShares.bat on $pcname..."; Start-Sleep -Seconds 1.5
            }
            else {
                # Copies file from share to the target computer
                Copy-Item "\\path\to\file\MapShares.bat" -Destination "\\$pcname\c$\tools\MapShares.bat"
                Write-Host "`nThe file MapShares.bat was successfully copied to the path '\\$pcname\c$\tools\MapShares.bat'"; Start-Sleep -Seconds 1.5
                Write-Host "`nRunning MapShares.bat on $pcname..."; Start-Sleep -Seconds 1.5
            }
        }
        else {
            Write-Host "Unable to connect to '\\path\to\file\MapShares.bat' network share"
        }
    }
    else {
        Write-Host "Unable to establish connection with target computer"
    }

    # Creates a scheduled task and runs the batch file on the target computer as the user
    Invoke-Command -ComputerName $pcname -ScriptBlock {
        $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument 'cmd /c C:\tools\Mapshares.bat' # Sets task action
        $CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger # Builds trigger
        $Trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly # Builds trigger
        $Trigger.Subscription = # Builds trigger
        # To set a different trigger for a different app change the event ID. If you want to change the GetInfoScript, it needs to be changed in all locations

        # The line below is a filter written in XML that will find the event in event viewer that acts as the trigger for this scheduled task to start.
        # It follows the Application path and looks for the event source named GetInfoScript that also has the event ID of 9005. This filter is then assigned to $trigger.subscription
        @"
<QueryList><Query Id="0" Path="Application"><Select Path="Application">*[System[Provider[@Name='GetInfoScript'] and EventID=9005]]</Select></Query></QueryList>
"@
        # ^ DO ^ NOT ^ MESS ^ WITH ^ THIS^ 
        $Trigger.Enabled = $True # Sets $trigger property to true
        # Makes sure the currently signed in user is who this task affects
        $principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance –ClassName Win32_ComputerSystem | Select-Object -expand UserName) 
        $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal # Builds the full task using the $action, $trigger, and $principal variables defined above
        Register-ScheduledTask MapShares -InputObject $task  > $null # Registers the task and discards any output generated by the command
                
        Start-ScheduledTask -TaskName "MapShares"
        start-sleep -Seconds 30
        schtasks /delete /tn MapShares /f # Forcefully deletes the task named MapShares
    }
    Remove-Item -Path "\\$PCName\C$\tools\MapShares.bat" -Recurse # Removes the batch file that maps the share drives
    Remove-Item -Path "\\$pcname\c$\tools\paths.txt" -Recurse
}