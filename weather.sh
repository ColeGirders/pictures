#!/bin/bash
# include common definitions
# shellcheck source=scripts/core/sxmo_common.sh
. "$(dirname "$0")/sxmo_common.sh"

[ -z "$SXMO_GPSLOCATIONSFILES" ] && SXMO_GPSLOCATIONSFILES="/usr/share/sxmo/appcfg/places_for_gps.tsv"
ROWHOURS=8
WEATHERXML=""

downloadweatherxml() {
	WEATHERXML="$(
		curl "https://forecast.weather.gov/MapClick.php?lat=$LAT&lon=$LON&unit=1&FcstType=digitalDWML"
	)"
}


weatherdata() {
	XPATH="$1"
	GREP="$2"
	echo "$WEATHERXML" |
		xmllint --xpath "$XPATH" - |
		grep "$GREP" |
		sed 's/<[^>]*>/ /g' |
		sed 's/  / /g' |
		awk '{$1=$1};1'
}

printtables() {
	NOWDAY="$(date +%s)"
	NOWHR="$(echo "$TIME" | cut -c 1-2)"
	# shellcheck disable=SC2034

	tl=$(((${#TIME}+1)/3))
	time5=""
	for i in $(seq "$tl"); do
		time1=$(echo $TIME | cut -f$i -d' ')
		time2=$(echo $((10#$time1)))
		time3=$(($time2%12))
		if [ "$time3" == 0 ]; then
			time3=12
		fi
		if [ "$(($time2/12))" == 0 ]; then
			time4=$(echo $(($time3))a)
		else
			time4=$(echo $(($time3))p)
		fi
		time5="${time5} ${time4}"
	done
	timef=$(echo $time5)

	di=0
	date +"%A"
	echo "Time"$'\t'"T(C)"$'\t'"Hum"
	echo "----------------------------"
	for i in $(seq "$tl"); do
		timefc=$(echo $timef | cut -f$i -d' ')
		tempc=$(echo $TEMP | cut -f$i -d' ')
		humidityc=$(echo $HUMIDITY | cut -f$i -d' ')
		echo $timefc$'\t'$tempc$'\t'$humidityc
		if [ "$timefc" == "11a" ]; then
			read -n1 -rsp $''
		fi
		if [ "$timefc" == "11p" ]; then
			di=$(($di+1))
			if [ "$di" == 1 ]; then
				date2=$(echo $(date --date='1 day' +"%A"))
			elif [ "$di" == 2 ]; then
				date2=$(echo $(date --date='2 days' +"%A"))
			elif [ "$di" == 3 ]; then
				date2=$(echo $(date --date='3 days' +"%A"))
			elif [ "$di" == 4 ]; then
				date2=$(echo $(date --date='4 days' +"%A"))
			elif [ "$di" == 5 ]; then
				date2=$(echo $(date --date='5 days' +"%A"))
			elif [ "$di" == 6 ]; then
				date2=$(echo $(date --date='6 days' +"%A"))
			elif [ "$di" == 7 ]; then
				date2=$(echo $(date --date='7 days' +"%A"))
			fi

			read -n1 -rsp $''
			echo ""
			echo $date2
			echo "Time"$'\t'"T(C)"$'\t'"Hum"
			echo "----------------------------"
		fi
	done
}

getweathertexttable() {
	LAT="$1"
	LON="$2"
	PLACE="$3"

	while true; do
		clear
		downloadweatherxml "$LAT" "$LON" 2>/dev/null
		TEMP="$(weatherdata "//temperature" "hourly")"
		RAIN="$(weatherdata "//probability-of-precipitation" ".")"
		DIRECTION="$(weatherdata "//direction" ".")"
		HUMIDITY="$(weatherdata "//humidity" "percent")"
		WIND="$(weatherdata "//wind-speed" ".")"
		#LOCATION="$(weatherdata "//location/description" ".")"
		TIME="$(
			weatherdata "//start-valid-time" "." |
			grep -oE 'T[0-9]{2}' | tr -d 'T' | tr '\n' ' '
		)"
		tput rev; echo "$PLACE"; tput sgr0
		printtables
		read -r
	done
}

weathermenu() {
	CHOICE="$(
		printf %b "$(
			echo "Close Menu";
			echo "$SXMO_GPSLOCATIONSFILES" |
				tr "," "\n" |
				xargs cat |
				grep "United States" # Note only US latlons work on weather.gov
		)" |
		grep -vE '^#' |
		sed "s/\t/: /g" |
		sxmo_dmenu_with_kb.sh -i -c -l 10 -p "Locations"
	)"
	if [ "$CHOICE" = "Close Menu" ]; then
		exit 0
	else
		PLACE="$(printf %b "$CHOICE" | cut -d: -f1 | awk '{$1=$1};1')"
		LAT="$(printf %b "$CHOICE" | cut -d: -f2- | awk '{$1=$1};1' | cut -d ' ' -f1)"
		LON="$(printf %b "$CHOICE" | cut -d: -f2- | awk '{$1=$1};1' | cut -d ' ' -f2)"
		sxmo_terminal.sh "$0" getweathertexttable "$LAT" "$LON" "$PLACE"
	fi
}

if [ -z "$1" ]; then
	weathermenu
else
  "$@"
fi
