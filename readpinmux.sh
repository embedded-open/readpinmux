#!/bin/bash
#
# Copyright (c) 2011 Hans Little [embedded.open@googlemail.com]
# All Rights Reserved.
# 
# Script for read the Pad Configuration Register setting of OMAP4430 processor 
# Usage:
#       sudo ./readpinmux.sh address1 [address2]
# address1: the hexadicimal address offset of the pad configuration register to be displayed 
# address2: the last address offset (HEX) of the pad configuration registers to be displayed
# 
# This script reqires the root privilege and the preinstalled devmem2.
# 
# The interpration of the register values is based on the section §18.4.8 and §18.6.6 of
# OMAP4430 Multimedia Device Silicon Revision 2.x Technical Reference Manual Version Z (SWPU231Z) 
# 
# The base address of the SYSCTRL_PADCONF_CORE register on OMAP4430 is "0x4A100000" (§18.6.6) 
# The offsets of registers are given in Table 18-9 or refer to the u-boot code:
# ./arch/arm/include/asm/arch-omap4/mux_omap4.h

# Define the base address for OMAP4430 
ADDR_BASE=0x4A100000 # for PADCONF_CORE registers
#ADDR_BASE=0x4A31E000 # for PADCONF_WKUP registers


# Check the arguments 
if [ $# -lt 1 -o $# -gt 3 ] ; then
	echo "Usage: sudo ./readpinmux.sh 0xSTARTADDR [0xSTOPADDR]"  
	exit 
else
    STARTADDR=$(( $1 + ADDR_BASE ))
    STOPADDR=$((${2:-$1} + ADDR_BASE))
#    echo \$STARTADDR $STARTADDR 
#    echo \$STOPADDR $STOPADDR
    if [ $STOPADDR -lt $STARTADDR ]; then
	echo "Error! The 0xSTOPADDR must be higher than the 0xSTARTADDR!"
	exit 1
    else
	printf "Start addr.: 0x%08X; Stop addr.: 0x%08X \n" $STARTADDR $STOPADDR
        #$("ibase=16; obase=2; `printf "%08X" $1`" | bc)  $("ibase=16; obase=2; `printf "%08X" $2`" | bc)
    fi 
fi


# Check if the devmem2 utility is available
if [ ! -x `which devmem2` ]; then
    echo "The utility devmem2 is not installed! Leaving without doing anything ..."
    exit 1
else
    echo "calling devmem2 ..."
# Precessing each address
    ADDR=$STARTADDR
    while [ $ADDR -le $STOPADDR  ]; 
    do 
	ADDR_HEX=$(printf "0x%08X" $ADDR)
#	printf " Processing $ADDR_HEX \n" 
	DEVMEM2OUT=$(devmem2 $ADDR_HEX h | awk 'END {print$NF}')
	printf "Address: $ADDR_HEX; Setting(HEX): $DEVMEM2OUT; Setting (BIN):  $(echo "ibase=16; obase=2; `printf "%08X" $DEVMEM2OUT`" | bc) \n"


        # Exam the MUXMODE value
	printf "{ M%d |" $(($DEVMEM2OUT & 7 ))
    
        # Exam the Pull setting
	TESTVALUE=$(( ($DEVMEM2OUT >> 3) & 3))
	case $TESTVALUE in
	    0 | 2) # 00 or 10 means PULLUD Disabled
		PULLUD=""
		;;
	    1) # 01 means PTD
		PULLUD=" PTD |"
		;;
	    3) # 11 means PTU
		PULLUD=" PTU |"
		;;
	esac
	printf "$PULLUD"

        # Exam INPUT setting
	if [ $((($DEVMEM2OUT >> 8) & 1 )) -eq 1 ]; then
	    printf " IEN }"
	else 
	    printf " IDIS }"
	fi 

        # Exam the OFF MODE settings
	if [ $(($DEVMEM2OUT >> 9 & 1)) -eq 1 ]; then
	    printf " OFFMODEENABLE = 1 "
	    # Exam the OFFMODEOUT settings
	    if [ $(($DEVMEM2OUT >> 10 & 1)) -eq 0 ]; then 
		printf " OFFMODEOUTENABLE = 0 (ENABLED) "
		if [ $(($DEVMEM2OUT >> 11 & 1)) -eq 1 ]; then
		    printf " OFFMODEOUTVALUE = 1 "
		else 
		    printf " OFFMODEOUTVALUE = 0 "
		fi 
	    else 
		printf " OFFMODEOUTENABLE = 1(DISABLED) "
	    fi
	    # Exam the OFFMODEPULLUD settings
	    if [ $((($DEVMEM2OUT >> 12) & 1 )) ]; then
		printf " OFFMODEPULLUDENABLE = 1(ENABLED) "
		if [  $((($DEVMEM2OUT >> 13) & 1 )) ]; then
		    printf " OFFMODEPULLTYPESELECT = 1(PTU) "
		else
		    printf " OFFMODEPULLTYPESELECT = 0(PTD) "
		fi
	    else
		printf " OFFMODEPULLUDENABLE = 0(DISABLED) "
	    fi
	else
	    printf " OFFMODEENABLE = 0 (DISABLED) "
	fi

        # Exam the WAKEUP mode settings
	if [ $(( ($DEVMEM2OUT >> 14) & 1)) -eq 1 ]; then
	    printf " WAKEUPENABLE = 1(ENABLED) "
	    if [ $(( ($DEVMEM2OUT >> 15) & 1)) -eq 1 ]; then
		printf " WAKEUPEVENT = 1 "
	    else
		printf " WAKEUPEVENT = 0 "
	    fi 
	else
	    printf " WAKEUPENABLE = 0(DISABLED) "
	fi 
	printf "\n"
	(( ADDR++ )) 
	(( ADDR++ ))
    done
fi 
