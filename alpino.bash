#!/bin/bash

script='
@parts = ("/");
$p = "";
foreach $part (split m!/!, $ENV{dir}) {
	if ($part ne "") {
		$p .= "/" . $part;
		push @parts, $p;
	}
}
foreach $p (@parts) {
	$s = `stat -c %A "$p"`;
	if ($s =~ /d(...){0,2}..-/) {
		print "$p";
		exit;
	}
}
'

if [ $# -lt 1 ]
then
	echo
	echo Usage: $0 workdir [command [arg...]]
	echo
	echo See: https://github.com/rug-compling/alpino-docker
	echo
	exit
fi

DIR="$1"
shift

if [ ! -d "$DIR" -o ! -r "$DIR" ]
then
	echo
	echo "'$DIR'" is not a readable directory
	echo
	exit
fi

set -e

os=`docker version -f {{.Client.Os}}`

if [ "$os" = "windows" ]
then
	case "$DIR" in
	/c/Users|/c/Users/*)
		;;
	*)
		echo
		echo workdir must start with /c/Users
		echo
		exit
		;;
	esac
elif [ "$os" = "darwin" ]
then
	case "$DIR" in
	/Users|/Users/*)
		;;
	*)
		echo
		echo workdir must start with /Users
		echo
		exit
		;;
	esac
elif [ "$os" = "linux" ]
then
	case "$DIR" in
	/*)
		;;
	*)
		echo
		echo workdir must be an absolute path
		echo "'$DIR'" is not an absolute path
		echo
		exit
		;;
	esac
	st=`stat -f -c %T "$DIR"`
	case "$st" in
	nfs*)
		P=`dir="$DIR" perl -e "$script"`
		if [ "$P" != "" ]
		then
		echo
		echo path "'$P'" must be executable for everybody
		echo please do:
		echo
		echo "  chmod a+x $P"
		echo
		exit
		fi
		;;
	esac
else
	echo
	echo Unknown OS: $os
	echo
	exit
fi

if [ "$os" = "linux" ]
then
	docker run \
		-d \
		-e DISPLAY \
		--net=host \
		--user=`id -u`:`id -g` \
		--rm \
		-i -t \
		-v "$DIR":/work/data \
		rugcompling/alpino:latest "$@"
elif [ "$os" = "darwin" ]
then
	if [ -d /tmp/.X11-unix ]
	then
	echo THIS WAS NOT TESTED
	set -x
		ip=$(ifconfig en0 | grep inet | awk '$1=="inet" {print $2}')
		xhost + $ip
		docker run \
			-d \
			-e DISPLAY=$ip:0 \
			-v /tmp/.X11-unix:/tmp/.X11-unix \
			--net=host \
			--rm \
			-i -t \
			-v "$DIR":/work/data \
			rugcompling/alpino:latest "$@"
	set +x
	else
	echo Directory /tmp/.X11-unix not found, no GUI available
	docker run \
		-d \
		--rm \
		-i -t \
		-v "$DIR":/work/data \
		rugcompling/alpino:latest "$@"
	fi
else
	docker run -d \
		--rm \
		-i -t \
		-v "$DIR":/work/data \
		rugcompling/alpino:latest "$@"
fi
