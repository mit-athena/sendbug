#!/bin/sh
# $Id: sendbug.sh,v 1.21 2003-07-30 19:16:12 zacheiss Exp $

visual=false

help () {
    echo "Usage: $0 [program]"
    echo "Assist a user in sending an accurate and useful bug report."
}

TEMP="$(getopt -n "$0" -o '' -l gnome,help -- "$@")" || exit $?
eval set -- "$TEMP"

while true; do
    case "$1" in
        # This is how we are invoked from the panel menu
        --gnome) gnome=true; shift;;
        --help) help; exit;;
        --) shift; break;;
    esac
done

subject=$1
bugs_address=bugs@mit.edu
sendmail="/usr/sbin/sendmail -t -oi"
report_file=$(mktemp -t "sendbug.$USER.XXXX")
machtype=$(machtype)
cpu=$(machtype -c)
hostname=$(hostname)
dpy=$(machtype -d)

localacct=
shell=`awk -F: '/^'$USER':/ { print $7; exit; }' /etc/passwd 2>/dev/null`
if [ -z "$shell" ]; then
    shell=`getent passwd $USER 2>/dev/null | cut -d ':' -f 7`
else
    localacct="(local account)"
fi
case $shell in
$SHELL)
  ;;
"")
  shell="$SHELL (?)"
  ;;
*)
  shell="$shell ($SHELL?)"
  ;;
esac

if [ -z "$subject" ]; then
  text="Please enter the name of the program or locker with which you are"
  text="$text having problems."
  if [ true = "$gnome" ]; then
      if ! subject=$(zenity --entry --text="$text"); then
          exit
      fi
  else
    echo "$text" || fmt
    echo -n ' --> '
    read subject
  fi
fi

cat > $report_file << EOF
To: $bugs_address
Subject: Debathena: $subject

System name:		$hostname
Type:			$cpu
Display type:		$dpy

Shell:			$shell $localacct
Window manager:		${WINDOW_MANAGER:-unknown}
Desktop session:	${GDMSESSION:-unknown}

1) What were you trying to do?


2) What happened?


3) What should have happened?


4) Does this problem happen only on this workstation, or other workstations?


5) If you were following instructions, please include the URL or a
   description of the documentation:
   (e.g. a "problem set for 18.03" or http://ist.mit.edu)


EOF

if [ true = "$gnome" ]; then
  text="After you click OK, an editor window will appear with the bug report"
  text="$text contents.  Please fill out the form, then save and exit.  If"
  text="$text you change your mind, you will have a chance to cancel before"
  text="$text the bug report is sent."
  zenity --info --text="$text"
  gnome-text-editor "$report_file"
  # zenity doesn't let us specify the buttons on a question, and the
  # list dialog is awkward.  So while we'd like to do something more
  # like what we do in the terminal case, we'll compromise a bit.
  question="Do you still want to send the bug report?"
  if ! zenity --question --text="$question"; then
    text="Cancelled.  Your text is in $report_file if you wish to recover it."
    zenity --info --no-wrap --text="$text"
    exit
  fi

  if $sendmail < $report_file; then
    text="Thank you for your bug report."
    zenity --info --text="$text"
  else
    text="Failed to send the bug report!  Please contact olc@mit.edu for"
    text="$text\nassistance.  Your text is in $report_file"
    text="$text\nif you wish to recover it and submit it to $bugs_address"
    zenity --error --no-wrap --text="$text"
  fi
else
  : ${EDITOR=nano}
  helpstr=
  case "$EDITOR" in
    nano|pico)
      helpstr="(Ctrl-O, then Enter to save; Ctrl-X to quit after saving)"
      ;;
    emacs)
      helpstr="(Ctrl-X, Ctrl-S to save; Ctrl-X, Ctrl-C to quit after saving)"
      ;;
  esac
  fmt << EOF

After you press <Enter>, an editor will now open with the bug report
form.  Some fields have been filled out already.  Please answer the
numbered questions with as much detail as possible.  
Remember to save the file before exiting the editor.  
$helpstr

Press <Enter> to continue.
EOF
  read dummy
  $EDITOR "$report_file"
  while true; do
    fmt << EOF

Please enter "send" to send the report, "edit" to re-edit it, or
"quit" to quit.
EOF
    echo -n ' --> '
    read reply
    [ send = "$reply" ] && break
    [ quit = "$reply" ] && exit
    [ edit = "$reply" ] && $EDITOR "$report_file"
  done

  if $sendmail < $report_file; then
    echo "Thank you for your bug report."
  else
    fmt << EOF
Failed to send the bug report!  This shouldn't happen!
Your text is in $report_file if you wish to recover it,
and you can submit it to $bugs_address.
EOF
  fi
fi
