#!/bin/sh
# ============================================================
# netcalc.sh - Petit calculateur IP/CIDR/Masque en pur shell
# ============================================================

# --- Fonctions utilitaires ---------------------------------
ip_to_int() { # 192.168.1.1 -> 3232235777
    local ip="$1"
    local a b c d
    IFS=. read -r a b c d <<EOF
$ip
EOF
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

int_to_ip() { # 3232235777 -> 192.168.1.1
    local n=$1
    echo "$(( (n >> 24) & 255 )).$(( (n >> 16) & 255 )).$(( (n >> 8) & 255 )).$(( n & 255 ))"
}

cidr_to_mask() { # 24 -> 255.255.255.0
    local c=$1
    local v=$(( 0xFFFFFFFF << (32 - c) & 0xFFFFFFFF ))
    int_to_ip $v
}

mask_to_cidr() { # 255.255.255.0 -> 24
    local n=$(ip_to_int "$1")
    local count=0
    local i=0
    while [ $i -lt 32 ]; do
        if [ $(( (n >> (31 - i)) & 1 )) -eq 1 ]; then
            count=$((count + 1))
        else
            break
        fi
        i=$((i + 1))
    done
    echo $count
}

# ------------------------------------------------------------
usage() {
    echo "Usage:"
    echo "  $0 cidr <ip>/<prefix>          - Infos réseau (ex: 192.168.1.0/24)"
    echo "  $0 mask <ip> <masque>          - Infos réseau (ex: 192.168.1.0 255.255.255.0)"
    echo "  $0 split <ip>/<prefix> <nb>    - Découpe le réseau en <nb> sous-réseaux"
    exit 1
}

# ------------------------------------------------------------
[ $# -lt 1 ] && usage

mode=$1; shift

case "$mode" in
    cidr)
        [ $# -ne 1 ] && usage
        ip=${1%/*}
        prefix=${1#*/}
        mask=$(cidr_to_mask $prefix)
        ipint=$(ip_to_int "$ip")
        maskint=$(ip_to_int "$mask")
        net=$((ipint & maskint))
        bcast=$((net | (~maskint & 0xFFFFFFFF)))
        
        echo "Adresse IP     : $ip"
        echo "Préfixe CIDR   : /$prefix"
        echo "Masque         : $mask"
        echo "Réseau         : $(int_to_ip $net)"
        echo "Broadcast      : $(int_to_ip $bcast)"
        echo "Plage hôtes    : $(int_to_ip $((net + 1))) - $(int_to_ip $((bcast - 1)))"
        echo "Nombre d'hôtes : $(( (1 << (32 - prefix)) - 2 ))"
        ;;
    mask)
        [ $# -ne 2 ] && usage
        ip=$1; mask=$2
        prefix=$(mask_to_cidr "$mask")
        "$0" cidr "$ip/$prefix"
        ;;
    split)
        [ $# -ne 2 ] && usage
        base=${1%/*}
        prefix=${1#*/}
        count=$2
        addbits=0
        while [ $((1 << addbits)) -lt $count ]; do
            addbits=$((addbits + 1))
        done
        newprefix=$((prefix + addbits))
        subnet_size=$((1 << (32 - newprefix)))
        baseint=$(ip_to_int "$base")
        
        echo "Découpage de $base/$prefix en $count sous-réseaux de /$newprefix :"
        for i in $(seq 0 $((count - 1))); do
            net=$((baseint + i * subnet_size))
            echo "  - $(int_to_ip $net)/$newprefix"
        done
        ;;
    *)
        usage
        ;;
esac