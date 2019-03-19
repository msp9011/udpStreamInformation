#!/bin/bash
#Ver:0004 ( added video and audio PID, debugged SAR and DAR regex)
#Last-Modified:12-11-18

INPUT_FILE=$ScriptPath/ChannelInput.txt    #This file should have the channel details as --> Multicast|UDP|ProgramNo|channelName 

#Give Blade IPs in BLADE_INFO array
#BLADE_INFO=(sshIP-UdpReceiverIP)
BLADE_INFO=(10.55.0.26-10.55.1.16)

DATE=`date +"%d%b%y_%H%M%S"`
ScriptPath=/opt/support
LOG=$ScriptPath/log/Final/$DATE
[ ! -d $LOG ] && mkdir -p $LOG
CSV_FILE=$LOG/Stream_info.csv

echo -e "Blade,Channel Name,Multicast IP,UDP Port,Source IP,Program No,Stream Order,Video PID,Audio PID,Video Codec, Intralize Type,Closed Caption,Video Bitrate,Video Resolution,Fps,Audio Codec,Sar,Dar" > $CSV_FILE

for INPUT in `cat $INPUT_FILE`
do
	MulticastIP=`echo $INPUT | awk -F "|" '{print $1}'`
	UdpPort=`echo $INPUT | awk -F "|" '{print $2}'`
	ProgramNo=`echo $INPUT | awk -F "|" '{print $3}'`	
	channelName=`echo $INPUT | awk -F "|" '{print $4}' | tr "'()/" "----"`	
	LOG_FILE=$LOG/$channelName.log

	for BladeIPS in ${BLADE_INFO[@]}
	do	
		BladeIP=`echo $BladeIPS | awk -F '-' '{print $1}'`
		ETH1=`echo $BladeIPS | awk -F '-' '{print $2}'`
		LOG_FILE=$LOG/$channelName.log	
		ffmpeg -timeout 30000 -i "udp://$MulticastIP:$UdpPort?fifo_size=50000000&overrun_nonfatal=1&buffer_size=50000000&localaddr=$ETH1"  2>&1 |  sed -n '/Program '$ProgramNo'\b/,/Program/{/Program/!p}' > $LOG_FILE 2>/dev/null
		if [ `cat $LOG_FILE | wc -l` -gt 1 ]; then
			STREAM_ORDER=`awk -F ':' '/Stream/ {print $3}' $LOG_FILE | sed 's/^ //' | tr '\n' ':'`
			VIDEO_PID=`awk -F ':' '/Stream/ {print $3}' $LOG_FILE  | nl -v 0 | awk '/Video/ {print $1}' | head -n1`
			AUDIO_PID=`awk -F ':' '/Stream/ {print $3}' $LOG_FILE  | nl -v 0 | awk '/Audio/ {print $1}' | head -n1`
			VIDEO_CODEC=`awk '/Stream/ && /Video/ {print $4}' $LOG_FILE`
			INTRALYZE_TYPE=`awk -F '[, ]' '/Stream/ && /Video/ ' $LOG_FILE  | sed -n 's/.*tv, \([^)]*\).*/\1/p' | sed 's/)//;s/,/:/' `
			CLOSE_CAPTION=`grep -q 'Closed Captions' $LOG_FILE && echo 'Available' || echo 'NA'`
			VIDEO_BITRATE=`awk  -F 'kb/s' '/Stream/ && /Video/ && /kb\/s/ {print $1}' $LOG_FILE | awk  '{print $NF" kb/s"}'`
			VIDEO_RESOLUTION=`awk   '/Stream/ && /Video/  {print $0}' $LOG_FILE | grep -Po '\d{3,4}x\d{3,4}'`
			FPS=`awk -F 'fps' '/Stream/ && /Video/ && /fps/ {print $1}' $LOG_FILE | awk  '{print $NF}'`
			AUDIO_CODEC=`awk '/Stream/ && /Audio/ {print $4}' $LOG_FILE | tr '\n' ':' | tr -d ','`
			SAR=`awk '/Video/ && /SAR/ {gsub(/.*SAR |].*/,""); print $1}' $LOG_FILE `
			DAR=`awk '/Video/ && /DAR/ {gsub(/.*DAR |].*/,""); print $1}' $LOG_FILE `
			echo -e "$BladeIP,$channelName,$MulticastIP,$UdpPort,$SourceIP,$ProgramNo,$STREAM_ORDER,$VIDEO_PID,$AUDIO_PID,$VIDEO_CODEC,$INTRALYZE_TYPE,$CLOSE_CAPTION,$VIDEO_BITRATE,$VIDEO_RESOLUTION,$FPS,$AUDIO_CODEC,$SAR,$DAR" >> $CSV_FILE
		else
			OUTPUT_CHECK=`grep  "^$BladeIP,$channelName" $CSV_FILE | wc -l`
		    [ $OUTPUT_CHECK -eq "0" ] && echo -e "$BladeIP,$channelName,NO STREAMS" >> $CSV_FILE
		fi
	done
done
