#!/bin/bash

##################
# Pomodoro Timer #
##################
                              
# Only run one instance of the script!

lockdir=/tmp/pomo.lock
if mkdir "$lockdir"; then
    trap 'rm -rf "$lockdir" & echo > $state & notify-send --icon=$icon Quit pomo' 0; else
    notify-send --icon=$icon \
	--category=warning "Already running!"
    exit 0
fi

config="$HOME/.config/pomo.conf"
state="$HOME/.local/share/pomo/pomo.state"
icon="$HOME/.local/share/pomo/pomo.svg"

# If config doesn't exist, write one.

if [[ ! -f $config ]]; then    
    echo -e "log=$HOME/.local/share/pomo/pomo.log\n\
descr=Work\n\
action=20\n\
break_short=5\n\
break_long=15\n\
break_interval=4\n\
max=4\n\
notify=FALSE\n\
notify_cmd=/usr/bin/notify-send\n\
sound=FALSE\n\
sound_player=/usr/bin/play\n\
sound_file=/usr/share/sounds/freedesktop/stereo/bell.oga\n\
window=TRUE\n\
trayicon=TRUE\n\
icon=$HOME/.local/share/pomo/pomo.svg" > $config
fi

# Change values from config with yad

options=$(yad \
    --title="Pomo" \
    --licon=$icon \
    --form \
    --columns=1 \
    --item-separator=, \
    --field="Logfile:SFL" "$(grep -i '^log=' $config | cut -f2 -d=)" \
    --field="Descr" "$(grep -i '^descr=' $config | cut -f2 -d=)" \
    --field="Action:SCL" "$(grep -i '^action=' $config | cut -f2 -d=)" \
    --field="Short break:SCL" "$(grep -i '^break_short=' $config | cut -f2 -d=)" \
    --field="Long Break:SCL" "$(grep -i '^break_long=' $config | cut -f2 -d=)" \
    --field="Long break interval:SCL" "$(grep -i '^break_interval=' $config | cut -f2 -d=)" \
    --field="Max of Pomodori:SCL" "$(grep -i '^max=' $config | cut -f2 -d=)" \
    --field="Popup notification:CHK" "$(grep -i '^notify=' $config | cut -f2 -d=)" \
    --field="Popup notification cmd" "$(grep -i '^notify_cmd=' $config | cut -f2 -d=)" \
    --field="Sound notification:CHK" "$(grep -i '^sound=' $config | cut -f2 -d=)" \
    --field="Sound player cmd" "$(grep -i '^sound_player=' $config | cut -f2 -d=)" \
    --field="Sound file:FL" "$(grep -i '^sound_file=' $config | cut -f2 -d=)" \
    --field="Window notifications:CHK" "$(grep -i '^window=' $config | cut -f2 -d=)" \
    --field="System tray icon:CHK" "$(grep -i '^trayicon=' $config | cut -f2 -d=)" \
    --field="Tray icon file:FL" "$(grep -i '^icon=' $config | cut -f2 -d=)" \
    --field="Set Options as Standard:CHK" "FALSE")

[[ ! $options ]] && exit    # exit on Cancel Button

# So, what was changed with yad?
# TODO: I think this can be done better with a loop through an array.

log="$(echo $options | cut -f1 -d '|')"
descr="$(echo $options | cut -f2 -d '|')"
action="$(echo $options | cut -f3 -d '|')"
break_short="$(echo $options | cut -f4 -d '|')"
break_long="$(echo $options | cut -f5 -d '|')"
break_interval="$(echo $options | cut -f6 -d '|')"
max="$(echo $options | cut -f7 -d '|')"
notify="$(echo $options | cut -f8 -d '|')"
notify_cmd="$(echo $options | cut -f9 -d '|')"
sound="$(echo $options | cut -f10 -d '|')"
sound_player="$(echo $options | cut -f11 -d '|')"
sound_file="$(echo $options | cut -f12 -d '|')"
window="$(echo $options | cut -f13 -d '|')"
trayicon="$(echo $options | cut -f14 -d '|')"
icon="$(echo $options | cut -f15 -d '|')"
standard="$(echo $options | cut -f16 -d '|')"

if [[ $standard == TRUE ]]; then
    echo -e "log=$log\n\
descr=$descr\n\
action=$action\n\
break_short=$break_short\n\
break_long=$break_long\n\
break_interval=$break_interval\n\
max=$max\n\
notify=$notify\n\
notify_cmd=$notify_cmd\n\
sound=$sound\n\
sound_player=$sound_player\n\
sound_file=$sound_file\n\
window=$window\n\
trayicon=$trayicon\n\
icon=$icon" > $config
fi

if [[ $trayicon == TRUE ]]; then
    PIPE="/tmp/pipe.tmp"
    rm $PIPE
    mkfifo $PIPE
    exec 3<> $PIPE
    yad --notification --listen <&3 & 
    echo "menu:\
|\
Start!bash $HOME/.conky/pomo/pomo.sh|\
Cancel!kill -15 $$|\
Quit Tray!exit" >&3
    echo icon:"$HOME/.local/share/pomo/pomo.svg" >&3
    echo "tooltip:Pomo" >&3
fi

p_count=0  # count the pomodori
b_count=0  # count the breaks

while true; do
    ### Work
    min=0

    p_count=$(( $p_count + 1 ))   

    while (( $min < $action )); do
	bar=$(( 100 / $action * $min )) # execibar for conky
	# descr  execibar  (elapsed/remaining min)  (done/remainig pomos)  (break)  
	echo -e "$descr\t$bar\t$min/$action\t$p_count/$max\t($b_count/$break_interval)" > $state
	sleep 60;
	min=$((min + 1))
	echo -e "$descr\t$bar\t$min/$action\t$p_count/$max\t($b_count/$break_interval)" > $state
    done    
    
    echo -e "$(date +%F\\t%R)\t$action\t$descr" >> $log
   

    if [[ $p_count == $max ]]; then
	[[ $sound == TRUE ]] && $sound_player $sound_file
	[[ $notify == TRUE ]] && $notify_cmd "Reached max of $max Pomodori!" --icon=$icon &
	if [[ $window == TRUE ]]; then
	    yad --info --title="Pomo" \
		--text="Reached Max of $max Pomodori!" \
		--image=$icon
	fi
	exit
    fi

    ## Break

    b_count=$((b_count + 1))

    if [[ $break_interval == $b_count ]]; then
	break=$break_long; else
    	break=$break_short;
    fi

    [[ $sound == TRUE ]] && $sound_player $sound_file
    [[ $notify == TRUE ]] && $notify_cmd "Have a $break minute break!" --icon=$icon
    if [[ $window == TRUE ]]; then
	yad --info --title="Pomo" \
	    --text="Have a $break minute break!" \
	    --image=$icon
	[[ $? = 1 ]] && echo -e "\nCancelled!" && exit
    fi

    min=0
    while (( $min < $break )); do
	bar=$(( 100 / $break * $min ))
	echo -e "Break\t$bar\t$min/$break\t$b_count/$break_interval" > $state
	sleep 60;
	min=$((min + 1))
	echo -e "Break\t$bar\t$min/$break\t$b_count/$break_interval" > $state
    done

    [[ $break_interval == $b_count ]] && b_count=0

    [[ $sound == TRUE ]] && $sound_player $sound_file
    [[ $notify == TRUE ]] && $notify_cmd "$break minute break is over." --icon=$icon
    if [[ $window == TRUE ]]; then
	yad --info \
	    --title="Pomo" \
	    --text="$break minute break is over." \
	    --image=$icon
	[[ $? = 1 ]] && echo -e "\nCancelled!" && exit
    fi
done

exit
