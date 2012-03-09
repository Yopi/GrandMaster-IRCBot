#!/bin/bash
nick="GrandMaster";
version="v0.02";

server="irc.network.net";
port=6697;
channel="#Channel";

# Reset output file
echo -n "" > ircecho.bot;

function run_irc {
	run=1;
	write "NICK $nick";
	sleep 1.2
	write "USER $nick 0 * :Megatomte BashBot $version";
	sleep 1.2
	write "JOIN $channel";
	sleep 1.2

	while read data; do
		echo $data;
		output=(${data//:/ });

		# Combine all outputs
		oldIFS=$IFS;
		IFS=":";
		msg=${output[@]};
		msg="${msg//${output[0]}/}"
		msg="${msg//${output[1]}/}"
		msg="${msg//${output[2]}/}"
		msg=$(echo $msg | sed 's/^ *//g');
		IFS=$oldIFS;

		case "${output[0]}" in
		*PING*)
			write "PONG :${output[1]}";
			;;
		esac;

		case "$data" in
			*"PRIVMSG #"*)
				echo "Message in channel ${output[2]}";
				msg=${msg%?};
				# LastFM command?
				if [[ "$msg" =~ ^\!lfm\ [a-zA-Z0-9]*$ ]]; then
					user=$(echo "$msg" | sed 's/\!lfm\ \([a-zA-Z_]*\)/\1/');
					url=$(echo 'http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user='${user}'&api_key=b25b959554ed76058ac220b7b2e0a026');
					info=`curl -s $url`;
					if [[ "$info" =~ error ]]; then
						echo "PRIVMSG ${output[2]} :Kan inte hitta användaren";
					else
						artist=$(echo -e "$info" | grep -m 1 "artist" | sed 's/<artist mbid=.*>\(.*\)<\/artist>/\1/i');
						song=$(echo -e "$info" | grep -m 1 "name" | sed 's/<name>\(.*\)<\/name>/\1/i');
						plays=$(echo -e "$info" | grep -m 1 "recenttracks" | sed 's/.*total\=\"\(.*\)\".*/\1/i');
						echo "($user) $artist - $song $info";
						lfm=$(echo "$artist - $song" | sed 's/^ *//g');
						if [[ -n "$artist" && -n "$song" ]]; then
							write "PRIVMSG ${output[2]} :$user ($plays spelade) senast: $lfm";
						fi;
					fi;
				fi;
				
				# Webpage title?
				url=$(echo "$data" | sed -n 's/.*\(https\?:\/\/[a-zA-Z0-9\.\/\?\=\&-\_]*\).*/\1/p');
				if [[ -n "$url" ]]; then
					echo $url;
					webpage=$(curl -s -L "$url");
					encoding=$(echo "$webpage" | grep -m 1 "charset=" | sed -n 's/.*charset\=\([A-Za-z0-9-]*\).*/\1/p');
					title=$(echo "$webpage" | grep -B2 -A3 "<title>");
					title=$(echo "$title" | iconv -f "$encoding");
					title=$(echo "$title" | sed 's/\&quot\;/\"/g' | sed 's/\&aring\;/å/g' | sed 's/\&auml\;/ä/ig' | sed 's/\&ouml\;/ö/ig');
					title=$(echo "$title" | tr '\n' ' ' | sed -n 's/.*<title>\s\?\(.*\)\s\?<\/title>.*/\1/p' | sed 's/\(\&\#[0-9]*\;\)//' | sed 's/\s\s\+//');
					if [[ -n "$title" ]]; then
						write "PRIVMSG ${output[2]} :Titel: $title";
					fi;
				fi;
				;;
			*"PRIVMSG $nick"*)
				user=$(echo $output[0] | sed 's/\(.*\)\!.*/\1/');
				case "$msg" in
					*VERSION*)
						write "NOTICE $user :\001Megatomte BashBot $version";
					;;
					*PING*)
						write "NOTICE $user :PONG";
					;;
					*)
						write "PRIVMSG $user :${msg}";
					;;
				esac;
				;;
			*)
				echo -n "";
				;;
		esac;
	done
}

# Output text to irc pipe via reading echo file
function write {
	echo "$1";
	echo "$1" >> ircecho_$nick.bot;
}
function echo_irc {
	while tail -f ircecho_$nick.bot; do
		echo "$line";
		sleep 0.1
	done
}

# String all functions together with output file
echo_irc | nc $server $port | tee output | run_irc
