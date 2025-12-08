#!/usr/bin/bash

RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
MAGENTA="\e[35m"
RESET="\e[0m"
CLEAR_SCREEN="\e[2J"
HIDE_CURSOR="\e[?25l"
SHOW_CURSOR="\e[?25h"

shopt -s expand_aliases
alias echo="echo -en"

# Use tput to get the width and height of the terminal (in lines/columns)
SCREEN_MAX_X=$(tput cols)
SCREEN_MAX_Y=$(tput lines)

PLAYER="${GREEN}@"
PLAYER_X=5
PLAYER_Y=5
PLAYER_LIVES=5

TROLL="${RED}$"
TROLL_X=50
TROLL_Y=20

draw_it() {
    echo "${CLEAR_SCREEN}"
    #echo "did it work?"
    # \e[10;10H
    echo "\e[0;40H${GREEN}Lives: ${PLAYER_LIVES}"

    echo "\e[${PLAYER_Y};${PLAYER_X}H${PLAYER}"
    #echo "${TROLL_Y}"
    # \e[Y;XH
    echo "\e[${TROLL_Y};${TROLL_X}H${TROLL}"
}

game_over() {
    local msg=$1
    echo "${SHOW_CURSOR}"
    echo "${CLEAR_SCREEN}"
    echo "\e[1;1HGame over!\e[2;1H$msg\e[4;1H"

    exit;

}

troll_ai() {
    if [[ "$TROLL_Y" -gt "$PLAYER_Y" ]]; then
        ((TROLL_Y--))
    fi
    if [[ "$TROLL_Y" -lt "$PLAYER_Y" ]]; then
        ((TROLL_Y++))
    fi
    if [[ "$TROLL_X" -lt "$PLAYER_X" ]]; then
        ((TROLL_X++))
    fi
    if [[ "$TROLL_X" -gt "$PLAYER_X" ]]; then
        ((TROLL_X--))
    fi
    
    if [[ ("$TROLL_X" -eq "$PLAYER_X") && 
        ("$TROLL_Y" -eq "$PLAYER_Y") ]]; then
        ((PLAYER_LIVES--))
        if [[ "$PLAYER_LIVES" -lt "1" ]]; then
            # Call the game over function and leave the game
            game_over "${RED}YOU LOOSE!"
        fi
        # New life, random location
        PLAYER_X=$(( (RANDOM % $SCREEN_MAX_X) ))
        PLAYER_Y=$(( (RANDOM % $SCREEN_MAX_Y) ))
        
    fi

}

echo "${HIDE_CURSOR}"
while true; do
    draw_it

    read -rsn1 key

    if [[ $key == "q" ]]; then
        # Time to quit
        break
    fi
    if [[ $key == "w" ]]; then
        ((PLAYER_Y--))
    fi
    if [[ $key == "s" ]]; then
        ((PLAYER_Y++))
    fi
    if [[ $key == "a" ]]; then
        ((PLAYER_X--))
    fi
    if [[ $key == "d" ]]; then
        ((PLAYER_X++))
    fi

    # Troll AI gets to run.
    troll_ai

done

# Call the game over function.
game_over