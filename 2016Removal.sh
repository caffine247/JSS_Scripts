#!/bin/sh
#set -x

TOOL_NAME="Microsoft Office 2016 for Mac Removal Tool"
TOOL_VERSION="1.5"

## Copyright (c) 2017 Microsoft Corp. All rights reserved.
## Scripts are not supported under any Microsoft standard support program or service. The scripts are provided AS IS without warranty of any kind.
## Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a 
## particular purpose. The entire risk arising out of the use or performance of the scripts and documentation remains with you. In no event shall
## Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever 
## (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary 
## loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility
## of such damages.

## Set up logging
# All stdout and sterr will go to the log file. Console alone can be accessed through >&3. For console and log use | tee /dev/fd/3
SCRIPT_NAME=$(basename "$0")
WORKING_FOLDER=$(dirname "$0")
LOG_FILE="$TMPDIR""$SCRIPT_NAME.log"
touch "$LOG_FILE"
exec 3>&1 1>>${LOG_FILE} 2>&1

## Formatting support
TEXT_RED='\033[0;31m'
TEXT_YELLOW='\033[0;33m'
TEXT_GREEN='\033[0;32m'
TEXT_BLUE='\033[0;34m'
TEXT_NORMAL='\033[0m'

## Initialize global variables
FORCE_PERM=false
PRESERVE_DATA=true
APP_RUNNING=false
KEEP_LYNC=false
SAVE_LICENSE=false

## Path constants
PATH_WORD2016="/Applications/Microsoft Word.app"
PATH_EXCEL2016="/Applications/Microsoft Excel.app"
PATH_PPT2016="/Applications/Microsoft PowerPoint.app"
PATH_OUTLOOK2016="/Applications/Microsoft Outlook.app"
PATH_ONENOTE2016="/Applications/Microsoft OneNote.app"
PATH_MAU="/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app"

## Functions
function LogMessage {
	echo $(date) "$*"
}

function ConsoleMessage {
	echo "$*" >&3
}

function FormattedConsoleMessage {
	FUNCDENT="$1"
	FUNCTEXT="$2"
	printf "$FUNCDENT" "$FUNCTEXT" >&3
}

function AllMessage {
	echo $(date) "$*"
	echo "$*" >&3
}

function LogDevice {
	LogMessage "In function 'LogDevice'"
	system_profiler SPSoftwareDataType -detailLevel mini
	system_profiler SPHardwareDataType -detailLevel mini
}

function ShowUsage {
	LogMessage "In function 'ShowUsage'"
	ConsoleMessage "Usage: $SCRIPT_NAME [--Force] [--Help] [--KeepLync] [--SaveLicense]"
	ConsoleMessage "Use --Force to bypass warnings and forcibly remove Office 2016 applications and data"
	ConsoleMessage ""
}

function GetDestructivePerm {
	LogMessage "In function 'GetDestructivePerm'"
	if [ $FORCE_PERM = false ]; then
		LogMessage "Script is not running with force - asking user for permission to continue"
		ConsoleMessage "${TEXT_RED}WARNING: This procedure will remove application and data files.${TEXT_NORMAL}"
		ConsoleMessage "${TEXT_RED}Be sure to have a backup before continuing.${TEXT_NORMAL}"
		ConsoleMessage "Do you wish to continue? (y/n)"
		read -p "" "GOAHEAD"
		if [ "$GOAHEAD" == "y" ] || [ "$GOAHEAD" == "Y" ]; then
			LogMessage "Destructive permissions granted by user"
			return
		else
			LogMessage "Destructive permissions DENIED by user"
			ConsoleMessage ""
			exit 0
		fi
	fi
}

function GetDestructiveDataPerm {
	LogMessage "In function 'GetDestructiveDataPerm'"
	if [ $FORCE_PERM = false ]; then
		LogMessage "Script is not running with force - asking user for permission to remove data files"
		ConsoleMessage "${TEXT_RED}This tool can either preserve or remove Outlook data files.${TEXT_NORMAL}"
		ConsoleMessage "Do you wish to preserve Outlook data? (y/n)"
		read -p "" "GOAHEAD"
		if [ "$GOAHEAD" == "y" ] || [ "$GOAHEAD" == "Y" ]; then
			LogMessage "User chose to preserve Outlook data"
			PRESERVE_DATA=true
		else
			LogMessage "User chose to remove Outlook data"
			PRESERVE_DATA=false
		fi
	fi
}

function GetDestructiveLicensePerm {
	LogMessage "In function 'GetDestructiveLicensePerm'"
	if [ $FORCE_PERM = false ]; then
		LogMessage "Script is not running with force - asking user for permission to remove license file"
		if [ $SAVE_LICENSE = false ]; then
			LogMessage "SAVE_LICENSE is false - asking user if they want to remove it"
			ConsoleMessage "${TEXT_RED}This tool can either preserve or remove your product activation license.${TEXT_NORMAL}"
			ConsoleMessage "Do you wish to preserve the license? (y/n)"
			read -p "" "GOAHEAD"
			if [ "$GOAHEAD" == "y" ] || [ "$GOAHEAD" == "Y" ]; then
				LogMessage "User chose to preserve the license"
				SAVE_LICENSE=true
			else
				LogMessage "User chose to remove the license"
				SAVE_LICENSE=false
			fi
		fi
	fi
}
function GetSudo {
	LogMessage "In function 'GetSudo'"
	if [ "$EUID" != "0" ]; then
		LogMessage "Script is not running as root - asking user for admin password"
		sudo -p "Enter administrator password: " echo
		if [ $? -eq 0 ] ; then
			LogMessage "Admin password entered successfully"
			ConsoleMessage ""
			return
		else
			LogMessage "Admin password is INCORRECT"
			exit 1
		fi
	fi
}

function CheckRunning {
	FUNCPROC="$1"
	LogMessage "In function 'CheckRunning' with argument $FUNCPROC"
	local RUNNING_RESULT=$(ps ax | grep -v grep | grep "$FUNCPROC")
	if [ "${#RUNNING_RESULT}" -gt 0 ]; then
		LogMessage "$FUNCPROC is currently running"
		APP_RUNNING=true
	fi
}

function CheckRunning2016 {
	LogMessage "In function 'CheckRunning2016'"
	CheckRunning "$PATH_WORD2016" "Word 2016"
	CheckRunning "$PATH_EXCEL2016" "Excel 2016"
	CheckRunning "$PATH_PPT2016" "PowerPoint 2016"
	CheckRunning "$PATH_OUTLOOK2016" "Outlook 2016"
	CheckRunning "$PATH_ONENOTE2016" "OneNote 2016"
}

function Close2016 {
	LogMessage "In function 'Close2016'"
	if [ $FORCE_PERM = false ]; then
		LogMessage "Script is not running with force - asking user for permission to continue"
		GetForcePerms
	fi
	ForceQuit2016
}

function GetForcePerms {
	LogMessage "In function 'GetForcePerms'"
	ConsoleMessage "${TEXT_YELLOW}WARNING: Office applications are currently open and need to be closed.${TEXT_NORMAL}"
	ConsoleMessage "Do you want this program to forcibly close open applications? (y/n)"
	read -p "" "GOAHEAD"
	if [ "$GOAHEAD" == "y" ] || [ "$GOAHEAD" == "Y" ]; then
		LogMessage "User gave permission for the script to close running apps"
		FORCE_PERM=true
		ConsoleMessage ""
	else
		LogMessage "User DENIED permissions for the script to close running apps"
		ConsoleMessage ""
		exit 0
	fi
}

function ForceTerminate {
	FUNCPROC="$1"
	LogMessage "In function 'ForceTerminate' with argument $FUNCPROC"
	$(ps ax | grep -v grep | grep "$FUNCPROC" | cut -d' ' -f1 | xargs kill -9 2> /dev/null)
}

function ForceQuit2016 {
	LogMessage "In function 'ForceQuit2016'"
	FormattedConsoleMessage "%-55s" "Shutting down all Office 2016 applications"
	ForceTerminate "$PATH_WORD2016" "Word 2016"
	ForceTerminate "$PATH_EXCEL2016" "Excel 2016"
	ForceTerminate "$PATH_PPT2016" "PowerPoint 2016"
	ForceTerminate "$PATH_OUTLOOK2016" "Outlook 2016"
	ForceTerminate "$PATH_ONENOTE2016" "OneNote 2016"
	
	ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
}

function RemoveComponent {
	FUNCPATH="$1"
	FUNCTEXT="$2"
	LogMessage "In function 'RemoveComponent with arguments $FUNCPATH and $FUNCTEXT'"
	FormattedConsoleMessage "%-55s" "Removing $FUNCTEXT"
	if [ -d "$FUNCPATH" ] || [ -e "$FUNCPATH" ] ; then
		LogMessage "Removing path $FUNCPATH"
		$(sudo rm -r -f "$FUNCPATH")
	else
		LogMessage "$FUNCPATH was not detected"
		ConsoleMessage "${TEXT_YELLOW}Not detected${TEXT_NORMAL}"
		return
	fi
	if [ -d "$FUNCPATH" ] || [ -e "$FUNCPATH" ] ; then
		LogMessage "Path $FUNCPATH still exists after deletion"
		ConsoleMessage "${TEXT_RED}Failed${TEXT_NORMAL}"
	else
		LogMessage "Path $FUNCPATH was successfully removed"
		ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
	fi
}

function RemoveUserComponent {
	FUNCPATH="$1"
	FUNCTEXT="$2"
	LogMessage "In function 'RemoveUserComponent with arguments $FUNCPATH and $FUNCTEXT'"
	for u in `ls /Users`; do
		FULLPATH="/Users/$u/$FUNCPATH"
		$(sudo rm -r -f $FULLPATH)
	done
}

function PreserveUserComponent {
	FUNCPATH="$1"
	FUNCTEXT="$2"
	LogMessage "In function 'remove_PreserveComponent with arguments $FUNCPATH and $FUNCTEXT'"
	FormattedConsoleMessage "%-55s" "Preserving $FUNCTEXT"
	for u in `ls /Users`; do
		FULLPATH="/Users/$u/$FUNCPATH"
		if [ -d "$FULLPATH" ] || [ -e "$FULLPATH" ] ; then
			LogMessage "Renaming path $FULLPATH"
			$(sudo mv -fv "$FULLPATH" "$FULLPATH-Preserved")
		fi
	done
	ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
}

function Remove2016Receipts {
	LogMessage "In function 'Remove2016Receipts'"
	FormattedConsoleMessage "%-55s" "Removing Package Receipts"
	RECEIPTCOUNT=0
	RemoveReceipt "com.microsoft.office.all.*"
	RemoveReceipt "com.microsoft.office.en.*"
	RemoveReceipt "com.microsoft.merp.*"
	RemoveReceipt "com.microsoft.mau.*"
	if (( $RECEIPTCOUNT > 0 )) ; then
		ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
	else
		ConsoleMessage "${TEXT_YELLOW}Not detected${TEXT_NORMAL}"
	fi
}

function RemoveReceipt {
	FUNCPATH="$1"
	LogMessage "In function 'RemoveReceipt' with argument $FUNCPATH"
	PKGARRAY=($(pkgutil --pkgs=$FUNCPATH))
	for p in "${PKGARRAY[@]}"
	do
		LogMessage "Forgetting package $p"
		sudo pkgutil --forget $p
		if [ $? -eq 0 ] ; then
			((RECEIPTCOUNT++))
		fi
	done
}

function Remove2016Preferences {
	LogMessage "In function 'Remove2016Preferences'"
	FormattedConsoleMessage "%-55s" "Removing Preferences"
	PREFCOUNT=0
	RemovePref "/Library/Preferences/com.microsoft.Word.plist"
	RemovePref "/Library/Preferences/com.microsoft.Excel.plist"
	RemovePref "/Library/Preferences/com.microsoft.Powerpoint.plist"
	RemovePref "/Library/Preferences/com.microsoft.Outlook.plist"
	RemovePref "/Library/Preferences/com.microsoft.outlook.databasedaemon.plist"
	RemovePref "/Library/Preferences/com.microsoft.DocumentConnection.plist"
	RemovePref "/Library/Preferences/com.microsoft.office.setupassistant.plist"
	RemovePref "/Library/Preferences/com.microsoft.onenote.mac.plist"
	RemovePref "/Library/Preferences/com.microsoft.office.licensingV2.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.Word.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.Excel.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.Powerpoint.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.Outlook.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.outlook.databasedaemon.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.outlook.office_reminders.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.DocumentConnection.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.office.setupassistant.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.office.plist"
	RemoveUserPref "Library/Preferences/com.microsoft.error_reporting.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.Word.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.Excel.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.Powerpoint.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.Outlook.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.outlook.databasedaemon.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.DocumentConnection.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.office.setupassistant.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.registrationDB.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.e0Q*.*.plist"
	RemoveUserPref "Library/Preferences/ByHost/com.microsoft.Office365.*.plist"
	if (( $PREFCOUNT > 0 )); then
		ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
	else
		ConsoleMessage "${TEXT_YELLOW}Not detected${TEXT_NORMAL}"
	fi
}

function RemovePref {
	FUNCPATH="$1"
	LogMessage "In function 'RemovePref' with argument $FUNCPATH"
	ls $FUNCPATH
	if [ $? -eq 0 ] ; then
		LogMessage "Found preference $FUNCPATH"
		$(sudo rm -f $FUNCPATH)
		if [ $? -eq 0 ] ; then
			LogMessage "Preference $FUNCPATH removed"
			((PREFCOUNT++))
		else
			LogMessage "Preference $FUNCPATH could NOT be removed"
		fi
	fi
}

function RemoveUserPref {
	FUNCPATH="$1"
	LogMessage "In function 'RemoveUserPref' with argument $FUNCPATH"
	for u in `ls /Users`; do
		FULLPATH="/Users/$u/$FUNCPATH"
		$(sudo rm -f $FULLPATH)
		((PREFCOUNT++))
	done
}

function CleanDock {
	LogMessage "In function 'CleanDock'"
	FormattedConsoleMessage "%-55s" "Cleaning icons in dock"
	if [ -e "$WORKING_FOLDER/dockutil" ]; then
		LogMessage "Found DockUtil tool"
		sudo "$WORKING_FOLDER"/dockutil --remove "file:///Applications/Microsoft%20Word.app/" --no-restart
		sudo "$WORKING_FOLDER"/dockutil --remove "file:///Applications/Microsoft%20Excel.app/" --no-restart
		sudo "$WORKING_FOLDER"/dockutil --remove "file:///Applications/Microsoft%20PowerPoint.app/" --no-restart
		sudo "$WORKING_FOLDER"/dockutil --remove "file:///Applications/Microsoft%20Outlook.app/"
		LogMessage "Completed dock clean-up"
		ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
	else
		ConsoleMessage "${TEXT_YELLOW}Not detected${TEXT_NORMAL}"
	fi
}

function RelaunchCFPrefs {
	LogMessage "In function 'RelaunchCFPrefs'"
	FormattedConsoleMessage "%-55s" "Restarting Preferences Daemon"
	sudo ps ax | grep -v grep | grep "cfprefsd" | cut -d' ' -f1 | xargs sudo kill -9
	if [ $? -eq 0 ] ; then
		LogMessage "Successfully terminated all preferences daemons"
		ConsoleMessage "${TEXT_GREEN}Success${TEXT_NORMAL}"
	else
		LogMessage "FAILED to terminate all preferences daemons"
		ConsoleMessage "${TEXT_RED}Failed${TEXT_NORMAL}"
	fi
}

function MainLoop {
	LogMessage "In function 'MainLoop'"
	# Show warning about destructive behavior of the script and ask for permission to continue
	GetDestructivePerm
	GetDestructiveDataPerm
	GetDestructiveLicensePerm
	# If appropriate, elevate permissions so the script can perform all actions
	GetSudo
	# Check to see if any of the 2016 apps are currently open
	CheckRunning2016
	if [ $APP_RUNNING = true ]; then
		LogMessage "One of more 2016 apps are running"
		Close2016
	fi
	# Remove Office 2016 apps
	RemoveComponent "$PATH_WORD2016" "Word 2016"
	RemoveComponent "$PATH_EXCEL2016" "Excel 2016"
	RemoveComponent "$PATH_PPT2016" "PowerPoint 2016"
	RemoveComponent "$PATH_OUTLOOK2016" "Outlook 2016"
	RemoveComponent "$PATH_ONENOTE2016" "OneNote 2016"
	
	# Remove Office 2016 helpers
	RemoveComponent "/Library/LaunchDaemons/com.microsoft.office.licensingV2.helper.plist" "Launch Daemon: Licensing Helper"
	RemoveComponent "/Library/LaunchDaemons/com.microsoft.office.autoupdate.helper.plist" "Launch Daemon: AutoUpdate Helper"
	RemoveComponent "/Library/PrivilegedHelperTools/com.microsoft.office.licensingV2.helper" "Helper Tools: Licensing Helper"
	RemoveComponent "/Library/PrivilegedHelperTools/com.microsoft.office.autoupdate.helper" "Helper Tools: AutoUpdate Helper"
	# Remove Office 2016 application support
	RemoveComponent "/Library/Application Support/Microsoft/MERP2.0" "Error Reporting"
	RemoveUserComponent "Library/Application Support/Microsoft/Office" "Application Support"
	# Remove Office 2016 caches
	RemoveUserComponent "Library/Caches/com.microsoft.browserfont.cache" "Browser Font Cache"
	RemoveUserComponent "Library/Caches/com.microsoft.office.setupassistant" "Setup Assistant Cache"
	RemoveUserComponent "Library/Caches/Microsoft/Office" "Office Cache"
	RemoveUserComponent "Library/Caches/Outlook" "Outlook Identity Cache"
	RemoveUserComponent "Library/Caches/com.microsoft.Outlook" "Outlook Cache"
	# Remove Office 2016 preferences
	Remove2016Preferences
	# Remove Office 2016 package receipts
	Remove2016Receipts
	# Clean up icons on the dock
	CleanDock
	# Restart cfprefs
	RelaunchCFPrefs
}

## Main
LogMessage "Starting $SCRIPT_NAME"
AllMessage "${TEXT_BLUE}=== $TOOL_NAME $TOOL_VERSION ===${TEXT_NORMAL}"
LogDevice

# Evaluate command-line arguments
if [[ $# = 0 ]]; then
	LogMessage "No command-line arguments passed, going into interactive mode"
	MainLoop
else
	LogMessage "Command-line arguments passed, attempting to parse"
	while [[ $# > 0 ]]
	do
	key="$1"
	LogMessage "Argument: $key"
	case "$key" in
    	--Help|-h|--help)
    	ShowUsage
    	exit 0
	shift # past argument
    	;;
    	--Force|-f|--force)
    	LogMessage "Force mode set to TRUE"
    	FORCE_PERM=true
    	shift # past argument
    	;;
    	--SaveLicense|-s|--savelicense)
    	LogMessage "SaveLicense set to TRUE"
    	SAVE_LICENSE=true
    	shift # past argument
    	;;
    	*)
    	ShowUsage
    	echo "Ignoring unrecognized argument: $key"
    	;;
	esac
	shift # past argument or value
	done
	MainLoop
fi

ConsoleMessage ""
ConsoleMessage "All events and errors were logged to $LOG_FILE"
ConsoleMessage ""
LogMessage "Exiting script"
exit 0