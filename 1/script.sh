#!/bin/bash
set -eux

IMAGE_NAME="jammy-server-cloudimg-amd64.img"
DATA_NAME="cloud-data.iso"
SSH_KEY="id_ed25519"
HTML_DIR_NAME="html"

VM_NAME="${VM_NAME:-ubuntu-kvm}"
RAM="${RAM:-2048}"
VCPUS="${VCPUS:-2}"

up() {
    local vm_name="${1:-$VM_NAME}"
    local ram="${2:-$RAM}"
    local vcpus="${3:-$VCPUS}"
    
    if [ ! -e "$IMAGE_NAME" ]; then
		curl "https://cloud-images.ubuntu.com/jammy/current/$IMAGE_NAME" --output "$IMAGE_NAME"
    fi
    genisoimage -output "$DATA_NAME" -volid cidata -rational-rock -joliet user-data meta-data
    virsh --connect=qemu:///system net-create mynet.xml
    cp -fr "$IMAGE_NAME" "$DATA_NAME" "$HTML_DIR_NAME" /tmp

    virt-install --connect=qemu:///system \
      --name="$vm_name" --ram "$ram" --vcpus "$vcpus" \
      --disk path="/tmp/$IMAGE_NAME",format=qcow2 \
      --disk path="/tmp/$DATA_NAME",device=cdrom \
      --network network=mynet,model=virtio \
      --os-variant ubuntu22.04 --virt-type kvm \
      --import --noautoconsole \
      --filesystem source=/tmp/"$HTML_DIR_NAME",target=html
      
    echo "Server should be available at http://192.168.123.2/ in a few seconds"
}

down() {
    local vm_name="${1:-$VM_NAME}"
    virsh --connect=qemu:///system shutdown "$vm_name" || true
    virsh --connect=qemu:///system destroy "$vm_name" || true
    virsh --connect=qemu:///system undefine "$vm_name" --remove-all-storage || true
    virsh --connect=qemu:///system net-destroy mynet || true
    rm -f "$DATA_NAME"
}

console() {
    local vm_name="${1:-$VM_NAME}"    
    virsh --connect=qemu:///system console "$vm_name"
}

ssh_vm() {
    chmod 0400 "$SSH_KEY"
    ssh -o StrictHostKeyChecking=no -i "./$SSH_KEY" user@192.168.123.2
}

clear() {
    sudo rm -rf /tmp/"$HTML_DIR_NAME" /tmp/"$IMAGE_NAME" /tmp/"$DATA_NAME"
}

main() {
    local command="${1:-help}"
    
    case "$command" in
        up)
            up "${@:2}"
            ;;
        down)
            down "${@:2}"
            ;;
        console)
            console "${@:2}"
            ;;
        ssh)
            ssh_vm "${@:2}"
            ;;
        clear-tml)
            clear "${@:2}"
            ;;
        help|--help|-h)
            echo "Usage: $0 <command> [parameters]"
            echo "Commands:"
            echo "up [vm_name] [ram] [vcpus] - launch VM"
            echo "down [vm_name] - delete VM"
            echo "console [vm_name] - virsh into VM (login=user password=password)"
            echo "ssh - ssh into VM"
            echo "clear-tmp - delete created files from /tmp (prompt sudo password)"
            ;;
        *)
            echo "Error: Unknown command '$command'"
            exit 1
            ;;
    esac
}

main "$@"
