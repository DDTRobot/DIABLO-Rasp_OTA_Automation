#!/bin/bash
filext="zip"
boot_check() {
    Whiptail_Command_Check
    calculate_size
}

# Note: Check whether whipptail is installed
Whiptail_Command_Check() {
	if ! command -v whiptail > /dev/null; then
		echo "whiptail not found"
		echo "Please install whiptail :"
		echo "    sudo apt-get install whiptail  "
    	sleep 5
    	return 1
  	fi
}

calculate_size() {
  WT_HEIGHT=20
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-5))
}

# Note: Exit Programe
Exit_Normal() {
	whiptail  --title "程序退出" \
			  --msgbox "程序退出!" 8 25 1
	exit 0
}

# Note: Exit Programe
Exit_Abnormal() {
	whiptail --title "程序退出" \
			 --msgbox "程序异常退出!" 8 25 1
	exit 1
}

LocalFirmWareUpdata() {   
    #check and print folder
    if [ -z $2 ] ; then
        dir_list=$(ls -lhp  | awk -F ' ' ' { print $9 " " $5 } ')
    else
        cd "$2"
        dir_list=$(ls -lhp  | awk -F ' ' ' { print $9 " " $5 } ')
    fi

    curdir=$(pwd)
    if [ "$curdir" == "/" ] ; then  # Check if you are at root folder
        selection=$(whiptail --title "$1" \
                              --menu "使用箭头方向键选择固件压缩包的位置\n\n\n$curdir" 0 0 0 \
                              --cancel-button Cancel \
                              --ok-button Select $dir_list 3>&1 1>&2 2>&3)
    else   # Not Root Dir so show ../ BACK Selection in Menu
        selection=$(whiptail --title "$1" \
                              --menu "使用箭头方向键选择固件压缩包的位置\n\n\n$curdir" 0 0 0 \
                              --cancel-button Cancel \
                              --ok-button Select ../ BACK $dir_list 3>&1 1>&2 2>&3)
    fi

    RET=$?
    if [ $RET -eq 1 ]; then  
       return 0
    elif [ $RET -eq 0 ]; then
       if [[ -d "$selection" ]]; then  
          LocalFirmWareUpdata "$1" "$selection"
       elif [[ -f "$selection" ]]; then  
          if [[ $selection == *$filext ]]; then   
            if (whiptail --title "选择固件压缩包" --yesno "路径 : $curdir\n文件名: $selection" 0 0 \
                         --yes-button "选择" \
                         --no-button "返回"); then
                filename="$selection"
                filepath="$curdir"    
            else
                LocalFirmWareUpdata "$1" "$curdir"
            fi
          else   
             whiptail --title "错误: 压缩包文件必须是 $filext 类型" \
                      --msgbox "$selection 不是 $filext 类型 !\n你必须选择 $filext 类型的压缩包" 0 0
             LocalFirmWareUpdata "$1" "$curdir"
          fi
       else
          whiptail --title "错误: 选择错误" \
                   --msgbox "$selection 文件路径选择出错" 0 0
          LocalFirmWareUpdata "$1" "$curdir"
       fi
    fi
    LocalFWUpdata_Server
}


LocalUpdata() {
    if [[ $selection == *$filext ]]; then 
        if (whiptail --title "信息确认" --yesno "路径地址 : $curdir\n固件名: $selection" 0 0 \
                            --yes-button "升级" \
                            --no-button "返回"); then
                    filename="$selection"
                    filepath="$curdir"    
        fi
    else   
            whiptail --title "错误: 固件压缩包必须是 $filext 类型" \
                     --msgbox "$selection 不是 $filext 类型的文件 !\n你必须选择 $filext 类型文件" 0 0
            return 0
    fi

    IAPUpdataFail="$diablo_whereami/logs/error/IAPUpdataFail"
    APPEnterFail="$diablo_whereami/logs/error/APPEnterFail"
    ReceiveDataTimeOut="$diablo_whereami/logs/error/ReceiveDataTimeOut"
    CRCFail="$diablo_whereami/logs/error/CRCFail"
    EOFFail="$diablo_whereami/logs/error/EOFFail"
    NAKTimeOut="$diablo_whereami/logs/error/NAKTimeOut"
    ACKTimeOut="$diablo_whereami/logs/error/ACKTimeOut"
    DataSendFail="$diablo_whereami/logs/error/DataSendFail"
    FlashWRFail="$diablo_whereami/logs/error/FlashWRFail"
    UpdataFail="$diablo_whereami/logs/error/UpdataFail"

    touch $diablo_whereami/logs/LocalUpdateRecord
    rm -rf $diablo_whereami/logs/error/*

    check_UpdateIAP=`(grep -a -o "start update iap" $diablo_whereami/logs/LocalUpdateRecord)`
    check_EnterApp=`(grep -a -o "start send enter app cmd" $diablo_whereami/logs/LocalUpdateRecord)`
    check_FileStream=`(grep -a -o "start send file stream" $diablo_whereami/logs/LocalUpdateRecord)`
    check_EnterCRC=`(grep -a -o "enter crc mode start send header" $diablo_whereami/logs/LocalUpdateRecord)` 
    check_EOF=`(grep -a -o "Reached EOF" $diablo_whereami/logs/LocalUpdateRecord)`
    check_AwaitNAK=`(grep -a -o "Received NAK" $diablo_whereami/logs/LocalUpdateRecord)`
    check_ReceivedACK=`(grep -a -o "EOT sent and awaiting ACK" $diablo_whereami/logs/LocalUpdateRecord)`
    check_InfoBlock=`(grep -a -o "Preparing info block" $diablo_whereami/logs/LocalUpdateRecord)`
    check_FlashFinish=`(grep -a -o "OK feedback received, flash finished" $diablo_whereami/logs/LocalUpdateRecord)`
    check_UpdateSuccess=`(grep -a -o "update successfully" $diablo_whereami/logs/LocalUpdateRecord)`
        wait `$diablo_whereami/bin/Local_Updata_tools $selection > $diablo_whereami/logs/LocalUpdateRecord&`
        Diablo_Local_Update_process_id=$!
        wait $Diablo_Local_Update_process_id && {
            for ((i=0; i<=100; i+=1)); do
            sleep 0.2
            echo $i
            done 
        } | whiptail --title "Attention" --gauge "Now preparing to update...  " 6 60 0
        {
            if [ "$check_UpdateIAP" == "start update iap" ]; then
            echo -e "XXX\n10\nNow update IAP...  \nXXX"
            sleep 0.3
                if [ "$check_EnterApp" == "start send enter app cmd" ]; then
                echo -e "XXX\n25\nNow enter APP...  \nXXX"
                sleep 0.3
                    if [ "$check_FileStream" == "start send file stream" ]; then
                    echo -e "XXX\n30\nNow start send file stream...  \nXXX"
                    sleep 0.3
                        if [ "$check_EnterCRC" == "enter crc mode start send header" ]; then
                        echo -e "XXX\n35\nNow enter crc mode...  \nXXX"
                        sleep 0.3
                            if [ "$check_EOF" == "Reached EOF" ]; then
                            echo -e "XXX\n50\nNow try to reach EOF...  \nXXX"
                            sleep 0.4
                                if [ "$check_AwaitNAK" == "Received NAK" ]; then
                                echo -e "XXX\n60\nNow try to receive NAK...  \nXXX"
                                sleep 0.7
                                    if [ "$check_ReceivedACK" == "EOT sent and awaiting ACK" ]; then
                                    echo -e "XXX\n65\nNow awaiting ACK...  \nXXX"
                                    sleep 0.6
                                        if [ "$check_InfoBlock" == "Preparing info block" ]; then
                                        echo -e "XXX\n70\nNow preparing info block... \nXXX"
                                        sleep 0.5
                                            if [ "$check_FlashFinish" == "OK feedback received, flash finished" ]; then
                                            echo -e "XXX\n90\nNow try to receive feedback...  \nXXX"
                                            sleep 0.3
                                                if [ "$check_UpdateSuccess" == "update successfully" ]; then
                                                echo -e "XXX\n100\nUpdate Successfully!  \nXXX"
                                                sleep 6
                                                else
                                                echo "XXX\n100\nUpdate Failed!\nXXX"
                                                touch $FlashWRFail  
                                                sleep 2
                                                fi
                                            else
                                            echo "XXX\n100\nError!!! Failed to receive feedback! Flash R&W Failed! Now exit to program!\nXXX"
                                            touch $FlashWRFail  
                                            sleep 2
                                            fi
                                        else
                                        echo "XXX\n100\nError!!! Failed to send Info block! Now exit the program!\nXXX"
                                        touch $DataSendFail  
                                        sleep 2
                                        fi
                                    else
                                    echo "XXX\n100\nError!!! Failed to receive ACK! Now exit the program!\nXXX"
                                    touch $ACKTimeOut  
                                    sleep 2
                                    fi
                                else
                                echo "XXX\n100\nError!!! Failed to receive NAK! Now exit the program!\nXXX"
                                touch $NAKTimeOut  
                                sleep 2
                                fi
                            else
                            echo "XXX\n100\nError!!! Failed to reach EOF! Now exit the program!\nXXX"
                            touch $EOFFail
                            sleep 2
                            fi
                        else
                        echo "XXX\n100\nError!!! Failed to enter CRC mode! Now exit the program!\nXXX"
                        touch $CRCFail
                        sleep 2
                        fi
                    else
                    echo "XXX\n100\nError!!! Failed to send file stream! Now exit the program!\nXXX"
                    touch $ReceiveDataTimeOut
                    sleep 2
                    fi
                else
                echo "XXX\n100\nError!!! Failed to enter APP! Now exit the program! \nXXX"
                touch $APPEnterFail
                sleep 2
                fi
            else
            echo "XXX\n100\nError!!! Failed to Update IAP! Now exit the program! \nXXX"
            touch $IAPUpdataFail
            sleep 2
            fi
        } | whiptail --title "Firmware Update Now..." \
                        --gauge "Please wait patiently, do not power off..." 6 60 0

    if test -f $IAPUpdataFail; then
    whiptail --title "Updata Fail" \
            --msgbox "IAP Updata Fail\nPlease restart device and try upgrade again!" 8 25 1
    sleep 2
    exit 1
    fi

    if test -f $APPEnterFail; then
    whiptail --title "Updata Fail" \
            --msgbox "APP Enter Fail\nPlease restart device and try upgrade again!" 8 25 1
    sleep 2
    exit 1
    fi

    if test -f $ReceiveDataTimeOut; then
    whiptail --title "Updata Fail" \
            --msgbox "Receive data timeout\nPlease restart device and try upgrade again!" 8 25 1
    sleep 2
    exit 1
    fi

    if test -f $CRCFail; then
    whiptail --title "Updata Fail" \
            --msgbox "CRC verification failed\nPlease restart device and try upgrade again!" 8 25 1
    sleep 2
    exit 1
    fi

    if test -f $EOFFail; then
    whiptail --title "Updata Fail" \
            --msgbox "EOF Fail\nPlease restart device and try upgrade again!" 8 25 1
    sleep 2
    exit 1
    fi

    if test -f $NAKTimeOut; then
    whiptail --title "Updata Fail" \
            --msgbox "NAK TimeOut\nPlease restart device and try upgrade again!" 8 25 1
    sleep 2
    exit 1
    fi

    if test -f $ACKTimeOut; then
    whiptail --title "Updata Fail" \
            --msgbox "ACK TimeOut\nPlease restart device and try upgrade again!" 8 25 1
    sleep 2
    exit 1
    fi

    if test -f $DataSendFail; then
    whiptail --title "Updata Fail" \
            --msgbox "Data send Fail\nPlease restart device and try upgrade again!" 8 25 1
    sleep 2
    exit 1
    fi

    if test -f $FlashWRFail; then
    whiptail --title "Updata Fail" \
            --msgbox "Flash write and read Fail\nPlease restart device and try upgrade again!" 8 25 1
    sleep 2
    exit 1
    fi

    if test -f $UpdataFail; then
    whiptail --title "Updata Fail" \
            --msgbox "Please try updata again!\nPlease restart device and try upgrade again!" 8 25 1
    sleep 2
    exit 1
    fi
    unset Diablo_OTA_process_id
    unset MqttConnectFail
    unset EnterBootLoaderFail
    unset VersionSearchFail
    unset IAPUpdataFail
    unset APPEnterFail
    unset ReceiveDataTimeOut
    unset CRCFail
    unset EOFFail
    unset NAKTimeOut
    unset ACKTimeOut
    unset DataSendFail
    unset FlashWRFail
    unset UpdataFail
    unset check_BL
    unset check_UpdateIAP
    unset check_EnterApp
    unset check_FileStream
    unset check_EnterCRC
    unset check_EOF
    unset check_AwaitNAK
    unset check_ReceivedACK
    unset check_InfoBlock
    unset check_FlashFinish
    unset check_UpdateSuccess
}
##############################################

LocalFWUpdata_Server() {
    FUN=$(whiptail --title "刑天机器人离线固件升级"	\
         	   --menu "请选择您下载的固件压缩包\n您当前选择的固件压缩包是:\n$curdir/$selection" 40 140 5 \
			   --cancel-button Back --ok-button Select \
				   "1 本地固件压缩包搜索" "选择固件压缩包       ❖ " \
				   "2 本地固件升级" "固件离线升级         ❖ " \
				   3>&1 1>&2 2>&3)
	RET=$?
	if [ $RET -eq 1 ]; then
	  Menu_System
	elif [ $RET -eq 0 ]; then
		case "$FUN" in
		1\ *) LocalFirmWareUpdata ;;
		2\ *) LocalUpdata ;;
		*) whiptail --title "错误信息" \
					--msgbox "  错误！请重试！" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT ;;
		esac || whiptail  --title "错误信息" \
						  --msgbox "程序运行错误！终止！" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT
	else 
		Exit_Abnormal
	fi
}

ReadMedforUpdata() {
	whiptail  --title "使用说明" \
			  --msgbox "欢迎您使用Diablo Tools工具\n\n本工具提供刑天机器人离线固件更新服务\n \
                        使用 ❖ 离线固件更新时 时，您无需解压下载下来的固件包，先在Diablo Tools界面中谨慎选择目标固件安装包，选定后执行离线更新即可\n\n \
                        无论您选择何种方式更新，请务必在更新前将机器人处于匍匐状态或者失能状态，同时确保机器人电量充足！\
                        \n固件更新大约花费1~2分钟！" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT
}

# Note: Menu System
Menu_System() {
diablo_whereami=`pwd`
FUN=$(whiptail --title "欢迎使用刑天机器人配置界面 Diablo Tools"	\
         	   --menu "请选择您需要的帮助" 40 140 5 \
			   --cancel-button Finish --ok-button Select \
				   "1 本地固件离线更新" "搜索本地固件压缩包   ❖ " \
                   "2 首次使用请阅读" "相关说明事项         ❖ " \
				   3>&1 1>&2 2>&3)
	RET=$?
	if [ $RET -eq 1 ]; then
	  Exit_Normal
	elif [ $RET -eq 0 ]; then
		case "$FUN" in
		1\ *) LocalFWUpdata_Server ;;
        2\ *) ReadMedforUpdata ;;
		*) whiptail --title "错误信息" \
					--msgbox "  错误！请重试！" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT ;;
		esac || whiptail  --title "错误信息" \
						  --msgbox "程序运行错误！终止！" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT
	else 
		Exit_Abnormal
	fi
}


boot_check
# Note: Start Program!
while true; do
Menu_System
done
