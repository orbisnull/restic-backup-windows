param(
    [parameter(Mandatory = $true)]
    [alias("j")]
    [ValidatePattern("[\w]+")]
    [ValidateLength(1, 255)]
    [string]
    $jobname,

    [parameter(Mandatory = $false)]
    [alias("c")]
    [string]
    $command = "dump",

    [parameter(Mandatory = $false)]
    [alias("p")]
    [string]
    $params = ""
)
if ($PSBoundParameters.Verbose)
{
    $VerbosePreference = "Continue"
}
$IsDebug = $false
if ($PSBoundParameters.Debug)
{
    $DebugPreference = "Continue"
    $IsDebug = $true
}

$exe = "C:\usr\bin\restic.exe"
Write-Debug "Restic path: $exe"

$conf_root_dir = "C:\usr\etc\restic-backup"
Write-Debug "Root conf dir: $conf_root_dir"

$conf_dir = "$conf_root_dir\$jobname"

if (-Not(Test-Path -Path $conf_dir))
{
    Write-Debug "Full job dir: $conf_dir"
    throw "The job dir $jobname not exist"
}
Write-Verbose "Check exist '$conf_dir': OK"

function SetEnv()
{
    #[string[]]$envVars = Get-Content -Path $conf_dir\env.conf
    $envVars = Get-Content -Path $conf_dir\env.json | ConvertFrom-Json
    #Write-Debug ($envVars | Format-Table | Out-String)

    ForEach ($var in $envVars)
    {
        Write-Debug "Set $( $var.name ): *****"
        Set-Item -Path Env:$( $var.name ) -Value $var.value
    }
    Write-Verbose "Set env variables: OK"
}

function UnsetEnv()
{
    $envVars = Get-Content -Path $conf_dir\env.json | ConvertFrom-Json

    ForEach ($var in $envVars)
    {
        Write-Debug "Unset $( $var.name )"
        Remove-Item -Path Env:$( $var.name )
    }
    Write-Verbose "Unset env variables: OK"
}


function Dump()
{
    $tagsFile = "$conf_dir\tags.list"
    if (Test-Path -Path $tagsFile)
    {
        [string[]]$tagsList = Get-Content -Path $tagsFile
        for ($index = 0; $index -lt $tagsList.count; $index++){
            $tagsList[$index] = "--tag " + $tagsList[$index]
        }

        $tagsString = $tagsList -join " "
        Write-Debug "tags: $tagsString"
        Write-Verbose "Loaded tags from file $tagsFile"
    }
    else
    {
        $tagsString = ""
        Write-Verbose "Tags not used - tags file not exist"
    }

    $includeFile = "$conf_dir\include.list"
    $include = ""
    if (Test-Path -Path $includeFile)
    {
        $include = "--files-from=$includeFile"
        Write-Verbose "Use include list from file $includeFile"
    }

    $excludeFile = "$conf_dir\exclude.list"
    $exclude = ""
    if (Test-Path -Path $excludeFile)
    {
        $exclude = "--exclude-file=$excludeFile"
        Write-Verbose "Use exclude list from file $excludeFile"
    }

    $arguments = "$tagsString --tag=job_$( $jobname ) $exclude $include $params"

    Run "backup" $arguments
}

function Run([string] $command, [string]$arguments)
{
    SetEnv
    $arguments = "$command $arguments"
    Write-Verbose "Start restic ($exe) with arguments '$arguments'"
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -Wait -Passthru -NoNewWindow
    UnsetEnv
    $p.WaitForExit()
    if ($p.ExitCode -ne 0)
    {
        throw "Failed execute $exe $arguments"
    }
}

function main()
{
    Try
    {
        switch ($command)
        {
            "dump" {
                Dump
            }
            default {
                Run $command $params
            }
        }
    }
    Catch
    {
        Write-Output "Ran into an issue: '$PSItem'"
        if ($IsDebug)
        {
            $PSItem.InvocationInfo | Format-List *
            $PSItem.ScriptStackTrace
        }
        exit 1;
    }
}

main
