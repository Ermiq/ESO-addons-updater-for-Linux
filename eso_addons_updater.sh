#!/bin/bash

CWD=$(dirname $(realpath $0))
TMPDIR="/tmp/esoaddons"
ADDONS_PATH="" # Must contain '/AddOns' because the usual ESO addons path is: .../Elder Scrolls Online/live/AddOns
TTC_PRICE_TABLE="" # If not provided, the 'https://eu.tamrieltradecentre.com/download/PriceTable' will be used

if [[ ! -f "$CWD/addons.txt" ]] || [[ ! -s "$CWD/addons.txt" ]]; then
	echo "Please add your addons to addons.txt, one per line using the URL from https://www.esoui.com"
	exit 1
fi

# Read the 'addons.txt' to set up the path to addons and the TTC prices URL provided by the user:
while read line; do
	if [[ $line =~ ^ADDONS_PATH= && $line == *"/AddOns" ]]; then
		ADDONS_PATH=$(echo "$line" | cut -d\= -f2)
		echo -e "\nAddons path provided:\n"$ADDONS_PATH""
		continue
	elif [[ $line =~ ^TTC_PRICES= ]]; then
		TTC_PRICE_TABLE=$(echo "$line" | cut -d\= -f2)
		echo -e "\nTTC prices URL provided:\n"$TTC_PRICE_TABLE""
		continue
	fi
done < "$CWD/addons.txt"

if [[ $ADDONS_PATH == "" ]]; then
	echo -e "\nPut the correct full path to the addons in the game's subfolder to the addons.txt.\nIt must be like this: ADDONS_PATH=/path/to/addons"
	exit 1
fi

if [[ $TTC_PRICE_TABLE == "" ]]; then
	echo -e "\nNo TTC prices URL provided.\nThe default URL (https://eu.tamrieltradecentre.com/download/PriceTable) will be used."
	TTC_PRICE_TABLE='https://eu.tamrieltradecentre.com/download/PriceTable'
fi

echo

mkdir -p "$TMPDIR"
rm -rf "$TMPDIR/*"

# del url name ver dirs
while read line; do
	if [[ ! $line =~ ^https:// ]]; then
		continue
	fi

	AURI=$(echo "$line" | cut -d\  -f1)
	ANAME=$(echo "$line" | cut -d\  -f2)
	AVERS=$(echo "$line" | cut -d\  -f3)

	if [[ $ANAME == $AURI ]]; then
		ANAME=$(echo "$line" | grep -Poi "info\d+-[^.]+" | cut -d- -f2)
	fi
	if [[ $AVERS == $AURI ]]; then
		AVERS=""
	fi

	RVERS=$(curl -s $AURI 2> /dev/null | grep -Poi "<div\s+id=\"version\">Version:\s+[^<]+" | cut -d\  -f3)
	if [[ $RVERS == "" ]];  then
		echo "Error finding version of addon $ANAME on esoui.com"
		sleep 1
		continue
	fi

	if [[ $RVERS == $AVERS ]]; then
		echo "Addon $ANAME is up to date."
		continue
	fi

	DURI=$(curl -s $(echo "$AURI" | sed "s#/info#/download#" | sed "s#.html##") 2> /dev/null | grep -m1 -Poi "https://cdn.esoui.com/downloads/file[^\"]*")
	wget -q -O "$TMPDIR/addon.zip" "$DURI"
	unzip -o -qq -d "$TMPDIR" "$TMPDIR/addon.zip"
	rm "$TMPDIR/addon.zip"

	for dir in $(ls -d "$TMPDIR/"*); do
		dir=$(basename "$dir")
		rm -rf "$ADDONS_PATH/$dir"
		mv -f "$TMPDIR/$dir" "$ADDONS_PATH/"
	done
	# Insert 'url name version' to the addon's line:
	sed -i "s#$line#$AURI $ANAME $RVERS#" "$CWD/addons.txt"

	echo "Updated addon $ANAME"
	sleep 1
done < "$CWD/addons.txt"

echo "Downloading new TTC prices table..."
wget -q -nv -O /tmp/PriceTable.zip $TTC_PRICE_TABLE
if [[ -f /tmp/PriceTable.zip ]]; then
	unzip -qq -o -d "$ADDONS_PATH/TamrielTradeCentre" /tmp/PriceTable.zip
	rm -f /tmp/PriceTable.zip
fi
