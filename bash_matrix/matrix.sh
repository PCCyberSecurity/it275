#!/usr/bin/env bash

# ---------------- CONFIG ----------------
FPS=60
COLUMNS=40
GLOW_LEN=3   # how many chars behind head stay bright

GLYPHS='アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン'

# Fade palette (after glow)
FADE_COLORS=(46 40 34 28 22 16)   # green → black

HEAD_COLOR=231    # white
GLOW_COLOR=82     # neon green

# ---------------- SETUP ----------------
stty -echo -icanon time 0 min 0
printf '\e[?25l\e[2J'

cleanup() {
  printf '\e[?25h\e[0m\e[2J'
  stty sane
  exit
}
trap cleanup INT TERM

cols=$(tput cols)
rows=$(tput lines)

declare -A TAIL

# Column state
for ((i=0;i<COLUMNS;i++)); do
  CX[$i]=$((RANDOM % cols))
  CY[$i]=$((RANDOM % rows))
  SPEED[$i]=$((1 + RANDOM % 3))
done

frame_time=$(awk "BEGIN {print 1/$FPS}")

last_sec=$(date +%s)
frames=0
fps=0

# ---------------- MAIN LOOP ----------------
while true; do
  start=$(date +%s%N)
  buf=""

  # ---- NON-BLOCKING INPUT (Git Bash safe) ----
  if read -rsn1 -t 0 key; then
    [[ $key == $'\e' || $key == "q" ]] && cleanup
  fi

  cols=$(tput cols)
  rows=$(tput lines)

  # ---- FPS ----
  ((frames++))
  now=$(date +%s)
  if ((now != last_sec)); then
    fps=$frames
    frames=0
    last_sec=$now
  fi

  # ---- HUD ----
  buf+="\e[1;1H\e[37mFPS:$fps $(date '+%H:%M:%S')\e[0m"

  # ---- RAIN ----
  for ((i=0;i<COLUMNS;i++)); do
    for ((s=0;s<SPEED[i];s++)); do
      glyph="${GLYPHS:RANDOM%${#GLYPHS}:1}"

      # Head
      TAIL["${CX[i]},${CY[i]}"]="head:$glyph"

      # Glow behind head
      for ((g=1; g<=GLOW_LEN; g++)); do
        py=$((CY[i]-g))
        ((py<0)) && py=$((rows+py))
        TAIL["${CX[i]},$py"]="glow:$glyph"
      done

      ((CY[i]++))
      ((CY[i]>=rows)) && CY[i]=0
    done
  done

  # ---- DRAW & FADE ----
  for k in "${!TAIL[@]}"; do
    IFS=',' read x y <<< "$k"
    IFS=':' read state ch <<< "${TAIL[$k]}"

    case "$state" in
      head)
        buf+="\e[$((y+1));$((x+1))H\e[38;5;${HEAD_COLOR}m$ch"
        TAIL["$k"]="glow0:$ch"
        ;;
      glow)
        buf+="\e[$((y+1));$((x+1))H\e[38;5;${GLOW_COLOR}m$ch"
        TAIL["$k"]="fade0:$ch"
        ;;
      glow0)
        buf+="\e[$((y+1));$((x+1))H\e[38;5;${GLOW_COLOR}m$ch"
        TAIL["$k"]="fade0:$ch"
        ;;
      fade*)
        idx=${state#fade}
        if ((idx >= ${#FADE_COLORS[@]})); then
          unset TAIL["$k"]
        else
          buf+="\e[$((y+1));$((x+1))H\e[38;5;${FADE_COLORS[$idx]}m$ch"
          TAIL["$k"]="fade$((idx+1)):$ch"
        fi
        ;;
    esac
  done

  printf "%b" "$buf"

  # ---- FRAME LIMIT ----
  end=$(date +%s%N)
  elapsed=$(awk "BEGIN {print ($end-$start)/1000000000}")
  sleep_time=$(awk "BEGIN {print $frame_time-$elapsed}")
  (( $(awk "BEGIN {print ($sleep_time > 0)}") )) && sleep "$sleep_time"
done
