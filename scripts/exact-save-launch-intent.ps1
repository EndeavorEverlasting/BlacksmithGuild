# Exact-save workflows must enter the game through launcher PLAY so the mod can
# own save selection at the in-game main menu. The in-game intent remains
# "continue" and is written separately to BlacksmithGuild_LaunchIntent.json.

function Resolve-TbgLauncherSelectionIntent {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('play', 'continue')]
        [string]$InGameLaunchIntent,

        [switch]$ExactSave
    )

    if (-not $ExactSave) {
        return $InGameLaunchIntent
    }

    if ($InGameLaunchIntent -ne 'continue') {
        throw 'Exact-save launch requires in-game continue intent.'
    }

    return 'play'
}
