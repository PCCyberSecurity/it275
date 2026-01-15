# Matrix Screen

# Ascii key code for escape key
$esc = [char]27
$Global:esc = $esc

# ANSI codes to set the background to black
$BlackBackground = "$esc[48;2;0;0;0m$esc[2J$esc[H"

# Get the raw user interface so we can do performance animation
$rawUI = $Host.UI.RawUI

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
    @{r=0;   g=100; b=0  }
)

# Tail Character - The falling line will "poop" one of these characters as it goes
# down the screen. This will just sit there and slowly fade out then delete itself
# to free up memory.
class TailCharacter {
    # Position of the character on the screen (x,y)
    [int]$X 
    [int]$Y
    # How far along the fade list are we
    [int]$FadeIndex
    # The character we are
    [string]$Glyph

    TailCharacter([int]$x, [int]$y, [int]$fade, [string]$glyph) {
        $this.X = $x
        $this.Y = $y
        $this.FadeIndex = $fade
        $this.Glyph = $glyph #$Global:Glyphs | Get-Random
    }

    [string] Render() {
        $c = $Global:FadeColors[$this.FadeIndex]
        $esc = $Global:esc

        # We use ANSI escape codes to set the RGB colors of this character
        # ANSI cursor positions are 1-based
        return "$esc[$($this.Y + 1);$($this.X + 1)H" +
               "$esc[38;2;$($c.r);$($c.g);$($c.b)m" +
               "$($this.Glyph)"
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
    [System.Collections.Generic.List[TailCharacter]]$Tail

    FallingLine([int]$x, [int]$height) {
        $this.X = $x
        $this.HeadY = Get-Random -Minimum (-30) -Maximum 0
        $this.Speed = Get-Random -Minimum 1 -Maximum 4
        $this.Counter = 0
        $this.TrailLength = Get-Random -Minimum 4 -Maximum 8
        $this.Tail = [System.Collections.Generic.List[TailCharacter]]::new()
    }

    [string] GetGlyph() {
        return $Global:Glyphs | Get-Random
    }

    [void] Update([int]$height) {
        $this.Counter++
        if ($this.Counter -lt $this.Speed) { return }
        $this.Counter = 0

        $this.HeadY++

        # Spawn tail characters
        for ($i = 0; $i -lt $this.TrailLength; $i++) {
            $y = $this.HeadY - $i
            if ($y -ge 0 -and
                $y -lt $height -and
                $i -lt $Global:FadeColors.Count) {

                $glyph = $this.GetGlyph()
                $this.Tail.Add(
                    [TailCharacter]::new(
                        $this.X,
                        $y,
                        $i,
                        $glyph
                    )
                )
            }
        }

        # # Cull expired
        # $this.Tail = $this.Tail | Where-Object {
        #     $_.FadeIndex -lt $Global:FadeColors.Count -and $_.Y -lt $height
        # }
        for ($i = $this.Tail.Count - 1; $i -ge 0; $i--) {
            $t = $this.Tail[$i]
            if ($t.FadeIndex -ge $Global:FadeColors.Count -or
                $t.Y -ge $height) {
                $this.Tail.RemoveAt($i)
            }
        }

        # Reset stream
        if ($this.HeadY -gt $height + 40) {
            $this.HeadY = Get-Random -Minimum (-30) -Maximum 0
            $this.Speed = Get-Random -Minimum 1 -Maximum 4
            $this.TrailLength = Get-Random -Minimum 4 -Maximum 8
            $this.Tail.Clear()
        }
    }
}

# =======================
# INIT
# =======================
$width  = $rawUI.WindowSize.Width
$height = $rawUI.WindowSize.Height

$Lines = @()
$line_count = $width * .75
for ($x = 0; $x -lt $line_count; $x++) {
    $line_x = Get-Random -Minimum 1 -Maximum $width
    $Lines += [FallingLine]::new($line_x, $height)
}

# FPS tracking
$frameCount = 0
$fps = 0
$lastTick = Get-Date

# =======================
# MAIN LOOP
# =======================
try {
    while ($true) {

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
            $line.Update($height)
            foreach ($t in $line.Tail) {
                [void]$buffer.Append($t.Render())
            }
        }

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
        Start-Sleep -Milliseconds 16
    }
}
finally {
    Write-Host "$esc[0m"
    $rawUI.CursorSize = 25
    Clear-Host
}
