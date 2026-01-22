# Matrix Screen

# Ascii key code for escape key
$esc = [char]27
$Global:esc = $esc

# ANSI codes to set the background to black
$BlackBackground = "$esc[48;2;0;0;0m$esc[2J$esc[H"

# Get the raw user interface so we can do performance animation
$rawUI = $Host.UI.RawUI
$Global:rawUI = $rawUI

# Allow reading Ctrl+C as input so we can exit gracefully
$origTreatCtrl = [Console]::TreatControlCAsInput
[Console]::TreatControlCAsInput = $true

# Cursor size
$rawUI.CursorSize = 0

# Set background to black by writing the ANSI code to the screen
Write-Host "$BlackBackground" -NoNewline

# The characters to show (glyphs)
# We will randomly grab one of these for characters on the screen
# Glyph set
# Matrix glyphs (Katakana generated safely)
$Global:Glyphs = @()

# Katakana block: U+FF71 – U+FF9D - Add matrix fun characters
for ($i = 0xFF71; $i -le 0xFF9D; $i++) {
    $Global:Glyphs += [char]$i
}

# Add ASCII noise - Add some normal characters.
$Global:Glyphs += '0','1','2','3','4','5','6','7','8','9'
$Global:Glyphs += '@','#','$','%','&','*'

# Fade glyphs out using these RGB colors
# Start at one end of the list and slowly fade to the other color
$Global:FadeColors = @(
    @{r=255; g=255; b=255},
    @{r=160; g=255; b=160},
    @{r=80;  g=255; b=80 },
    @{r=0;   g=180; b=0  },
    @{r=0;   g=100; b=0  },
    @{r=0;   g=0;   b=0}   # <-- added full black for final fade
)

# Utility: return $true if the given 0-based x,y coordinate is within the current window
function IsOnScreen {
    param(
        [int]$x,
        [int]$y
    )
    $width  = $Global:rawUI.WindowSize.Width
    $height = $Global:rawUI.WindowSize.Height
    return ($x -ge 0 -and $x -lt $width -and $y -ge 0 -and $y -lt $height)
}


# Tail Character - The falling line will "poop" one of these characters as it goes
# down the screen. This will just sit there and slowly fade out then delete itself
# to free up memory.
class TailCharacter {
    # Position of the character on the screen (x,y)
    [int]$X 
    [int]$Y
    # How far along the fade list are we
    [int]$FadeIndex
    # Milliseconds between fade steps
    [int]$FadeIntervalMs
    # Last time we advanced fade
    [datetime]$LastFadeTime
    # The character we are
    [string]$Glyph

    TailCharacter([int]$x, [int]$y, [string]$glyph) {
        $this.X = $x
        $this.Y = $y
        $this.FadeIndex = 0
        $this.Glyph = $glyph
        $this.FadeIntervalMs = 350
        $this.LastFadeTime = Get-Date
    }

    [string] Render() {
        $c = $Global:FadeColors[$this.FadeIndex]
        $esc = $Global:esc

        # We use ANSI escape codes to set the RGB colors of this character
        # ANSI cursor positions are 1-based
        $ret = "$esc[$($this.Y + 1);$($this.X + 1)H" +
               "$esc[38;2;$($c.r);$($c.g);$($c.b)m" +
               "$($this.Glyph)"

        # Advance fade index only after configured interval has elapsed
        $elapsed = (Get-Date) - $this.LastFadeTime
        if ($elapsed.TotalMilliseconds -ge $this.FadeIntervalMs) {
            $this.FadeIndex++
            $this.LastFadeTime = Get-Date
        }

        return $ret
    }
}


# =======================
# CLASS: FallingLine
# =======================
class FallingLine {
    [int]$X
    [int]$HeadY
    [int]$Speed
    [int]$Counter
    [int]$TrailLength
    [string]$CurrentGlyph
    [System.Collections.Generic.List[TailCharacter]]$Tail
    [int]$MoveIntervalMs
    [datetime]$LastMoveTime

    FallingLine() {
        $this.Tail = [System.Collections.Generic.List[TailCharacter]]::new()
        # Use this to decide when it is time to move the line down
        $this.MoveIntervalMs = 250
        $this.LastMoveTime = Get-Date
        # Reset gives us our initial position and glyph
        $this.ResetLine()
    }

    [void] ResetLine() {
        $this.HeadY = Get-Random -Minimum (-45) -Maximum 0
        # Pick a new random column on the current window width
        $this.X = Get-Random -Minimum 1 -Maximum ($Global:rawUI.WindowSize.Width)
        $this.CurrentGlyph = $this.GetNewGlyph()
        #$this.Tail.Clear()
    }

    [string] GetNewGlyph() {
        return $Global:Glyphs | Get-Random
    }

    [void] Update() {
        $elapsed = (Get-Date) - $this.LastMoveTime
        if ($elapsed.TotalMilliseconds -ge $this.MoveIntervalMs) {
            $this.HeadY++
            
            # Spawn tail character following this movement
            $y = $this.HeadY - 1
            
            # Only spawn tail if on screen
            if (IsOnScreen -x $this.X -y $y) {
                $this.Tail.Add(
                    [TailCharacter]::new(
                        $this.X,
                        $y,
                        $this.CurrentGlyph
                    )
                )
            }
            # Get a new glphy for next head position
            $this.CurrentGlyph = $this.GetNewGlyph()

            $this.LastMoveTime = Get-Date
        }

        
        
        # Cull expired tail characters
        for ($i = $this.Tail.Count - 1; $i -ge 0; $i--) {
            $t = $this.Tail[$i]
            if ($t.FadeIndex -ge $Global:FadeColors.Count) {
                $this.Tail.RemoveAt($i)
            }
        }

        # Reset line if off screen
        if ($this.HeadY -gt $Global:rawUI.WindowSize.Height + 1) {
            $this.ResetLine()
        }

    }
}

# =======================
# INIT
# =======================
$width  = $rawUI.WindowSize.Width
$height = $rawUI.WindowSize.Height

$Lines = @()
$line_count = [int]($width * .65)
for ($x = 0; $x -lt $line_count; $x++) {
    $Lines += [FallingLine]::new()
}

# FPS tracking
$frameCount = 0
$fps = 0
$lastTick = Get-Date

#$test_tail = [TailCharacter]::new(10,10,'A')

# =======================
# MAIN LOOP
# =======================
try {
    while ($true) {

        # Check for Escape or Ctrl+C to exit gracefully
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'Q' -or $key.Key -eq 'Escape' -or ($key.Key -eq 'C' -and ($key.Modifiers -band [ConsoleModifiers]::Control))) {
                break
            }
        }

        # Resize detection
        if ($rawUI.WindowSize.Width -ne $width -or
            $rawUI.WindowSize.Height -ne $height) {

            $width  = $rawUI.WindowSize.Width
            $height = $rawUI.WindowSize.Height
            $Lines.Clear()
            for ($x = 0; $x -lt $width; $x++) {
                $Lines += [FallingLine]::new($x, $height)
            }
            Write-Host "$esc[2J" -NoNewline
        }

        $buffer = New-Object System.Text.StringBuilder
        [void]$buffer.Append("$esc[H$esc[48;2;0;0;0m")

        foreach ($line in $Lines) {
            $line.Update()
            foreach ($t in $line.Tail) {
                [void]$buffer.Append($t.Render())
            }
        }

        # Test tail character rendering
        #[void]$buffer.Append($test_tail.Render())

        # HUD
        $frameCount++
        if ((Get-Date) - $lastTick -ge [TimeSpan]::FromSeconds(1)) {
            $fps = $frameCount
            $frameCount = 0
            $lastTick = Get-Date
        }

        $timeStr = (Get-Date).ToString("HH:mm:ss")
        [void]$buffer.Append(
            "$esc[1;1H$esc[38;2;0;255;0mFPS: $fps  TIME: $timeStr"
        )

        Write-Host $buffer.ToString() -NoNewline
        Start-Sleep -Milliseconds 10
    }
}
finally {
    Write-Host "$esc[0m"
    $rawUI.CursorSize = 25
    # Restore original TreatControlCAsInput setting
    [Console]::TreatControlCAsInput = $origTreatCtrl
    Clear-Host
}
