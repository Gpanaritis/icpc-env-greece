#!/bin/bash

SSHPORT=2222
SSHKEY="configs/ssh_key"
PIDFILE="tmp/qemu.pid"
SNAPSHOT="-snapshot"
ALIVE=0

function usage() {
  echo "Usage: build-final.sh (32|64)"
  echo "Usage: build-final.sh (i386|amd64)"
  echo ""
  echo "32,i386       Build a 32bit contestant image"
  echo "64,amd64      Build a 64bit contestant image"
  exit 1
}

while [[ $# -ge 1 ]]; do
  key="$1"
  case $key in
    32|i386)
      BASEIMG="base-i386.img"
      ;;
    64|amd64)
      BASEIMG="base-amd64.img"
      ;;
    *)
      usage
      ;;
    esac
    shift
done
if [ -z "$BASEIMG" ]; then
  usage
fi

function runssh() {
  ssh -i $SSHKEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null imageadmin@localhost -p$SSHPORT $@ 2>/dev/null
}

function cleanup() {
  if [ $ALIVE -eq 1 ]; then
    echo "Attempting graceful shutdown"
    runssh sudo poweroff
  else
    echo "Forcing shutdown(poweroff)"
    kill $(cat $PIDFILE)
  fi
  rm -f $PIDFILE
}

function waitforssh() {
  # wait for it to boot
  echo -n "Waiting for ssh "
  TIMEOUT=60
  X=0

  while [[ $X -lt $TIMEOUT ]]; do
    let X+=1
    OUT=$(ssh -i $SSHKEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null imageadmin@localhost -p$SSHPORT echo "ok" 2>/dev/null)
    if [[ "$OUT" == "ok" ]]; then
      ALIVE=1
      break
    fi
    echo -n "."
    sleep 1
  done
  echo ""

  if [ $ALIVE -eq 0 ]; then
    echo "Timed out waiting for host to respond"
    cleanup
    exit 1
  else
    echo "Host is alive! You can ssh in now"
  fi
}

function runansible() {
  echo "Running ansible"
  echo "Started at " `date`
  ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "localhost:$SSHPORT," --diff --become -u imageadmin --private-key $SSHKEY main.yml
  echo "Ansible finished at " `date`

  echo "Rebooting..."
  ssh -i $SSHKEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null imageadmin@localhost -p$SSHPORT sudo reboot
  # Wait 5 seconds for reboot to happen so we don't ssh back in before it actually reboots
  sleep 5
  ALIVE=0
  waitforssh
}
function launchssh() {
  echo "Launching ssh session"
  ssh -i $SSHKEY -o BatchMode=yes -o ConnectTimeout=1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null imageadmin@localhost -p$SSHPORT
}

qemu-system-x86_64 -smp 1 -m 1024 -hda output/$BASEIMG -global isa-fdc.driveA= --enable-kvm -net user,hostfwd=tcp::$SSHPORT-:22 -net nic --daemonize --pidfile $PIDFILE $SNAPSHOT -vnc :0 -vga qxl -spice port=5901,disable-ticketing -usbdevice tablet
ALIVE=0
waitforssh
runansible

CMD=1
while [ $CMD != 0 ]; do
  echo "Select an action"
  echo "    1. Launch SSH Session"
  echo "    2. Run ansible again"
  echo "    0. Halt VM"
  read -p "Action(Default 1): " CMD
  CMD=${CMD:-1}
  case $CMD in
    0) break ;;
    1) launchssh ;;
    2) runansible ;;
    *) launchssh ;;
  esac
done

echo
echo
read -p "Press enter to halt"

cleanup
exit 0
