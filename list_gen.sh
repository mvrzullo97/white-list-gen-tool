#!/bin/bash

# usage menu
echo
echo "---------------------- Usage ----------------------"
echo -e "\n   bash $0\n\n    -n < number of wl to generate > \n    -t < list type > (WI or WL) \n    -o < delete *.XML at the end > (yY-nN)\n    -s < service provider code > (ex. 151) \n    -c < toll charger code > (ex. 6) \n    -a < apduIdentifier code > \n    -f < plate number chars > (ex. ABCD) \n    -d < discount ID > (ex. 22) \n    -p < progressive plate number > (0 < x < 999 - #iterations) \n    -r < progressive WL filename > \n"
echo

while getopts n:t:o:s:c:a:p:f:d:r: flag
do
    case "${flag}" in
		n) n=${OPTARG};;
        t) LIST_TYPE=${OPTARG};;
        o) BOOL_delete_xml=${OPTARG};;
        s) S_PROVIDER=${OPTARG};;
        c) T_CHARGER=${OPTARG};;
        a) C_APDU=${OPTARG};;
        p) PRG=${OPTARG};;
        f) PLATE_NUMBER=${OPTARG};;
        d) DISCOUNT=${OPTARG};;
        r) fn_PRG_WL=${OPTARG};;
		\?) echo -e "\n Argument error! \n"; exit 0 ;;
	esac
done

# params check
if [ $# != 16 ] && [ $# != 18 ] && [ $# != 20 ]; then
    echo "Argument error: please digit right command."
	echo
	exit 0
fi

# vars delcaration
current_timestamp=$(date +"%Y%m%d")
OUT_DIR="OUT_DIR_WL"
tmp_filename_WL="tmp_filename_white_list.xml"
plate_f=${PLATE_NUMBER:0:2}
plate_l=${PLATE_NUMBER:2:2}
providers_code=('151' '2321' '3000' '7' '49')
naz_providers=('IT' 'IT' 'IT' 'DE' 'FR')
keys=( {A..Z} )
values=('11000' '10011' '01110' '10010' '10000' '10110' '01011' '00101' '01100' '11010' '11110' '01001' '00111' # baudot encoding
        '00110' '00011' '01101' '11101' '01010' '10100' '00001' '11100' '01111' '11001' '10111' '10101' '10001') 
discounts=('22')
BOOL_discount=false
upper_bound=$(expr $PRG + $n)

# input validation
if [[ $LIST_TYPE != 'WI' ]] && [[ $LIST_TYPE != 'WF' ]] ; then
    echo -e "Param error: please digit a valid type of white list (WI or WF) \n"
    exit 0
elif ! [[ "$BOOL_delete_xml" =~ ^([yY])$ ]] && ! [[ "$BOOL_delete_xml" =~ ^([nN])$ ]] ; then
    echo -e "Param error: please digit valid value for -o param (yY-nN) \n"
    exit 0
elif ! [[ ${providers_code[@]} =~ $S_PROVIDER ]] ; then
    echo -e "Param error: service provider's code '$S_PROVIDER' doesn't exist. \n"
    exit 0
elif ! [[ ${discounts[@]} =~ $DISCOUNT ]] ; then
    echo -e "Param error: discount '$DISCOUNT' doesn't exist. \n"
    exit 0
elif ! [ $upper_bound -lt 999 ] ; then 
    echo -e "Param error: progressive plate number out of bounds (0 < PLATE_NUMBER < 999 - number of iterations) \n"
    exit 0
elif [ $T_CHARGER != '6' ] ; then 
    echo -e "Param error: toll charger must be 6 \n"
    exit 0
elif [ ${#PLATE_NUMBER} != 4 ] ; then 
    echo -e "Param error: length of PLATE_NUMBER must be 4 \n"
    exit 0
fi

if [ $DISCOUNT != '' ] ; then
    BOOL_discount=true
fi

# create OUT_DIR if not exist
if ! [ -d $OUT_DIR ] ; then
	mkdir $OUT_DIR
	path_OUT_dir=$(realpath $OUT_DIR)
    echo -e "...create '$OUT_DIR' at path: '$path_OUT_dir' \n"
    chmod 0777 "$path_OUT_dir"
else
	path_OUT_dir=$(realpath $OUT_DIR)
fi

# functions
function generate_PAN 
{
    PRG=$1
    pad_NUM="0"
    pad_F="F"
    pad_PRG_F=$PRG$pad_F
    len_PAN=19
    str=$current_timestamp
    offset=$(expr $len_PAN - ${#pad_PRG_F})
    while [ ${#str} != $offset ] 
    do
        str=$str$pad_NUM
    done 
    str=$str$pad_NUM$pad_PRG_F
    echo ${str}
}

function generate_PLATE_NUMBER
{
    PRG=$1
    plate_f=$2
    plate_l=$3
    pad_NUM="0"
    len_PLATE=7
    offset=$(expr $len_PLATE - ${#plate_f} - ${#PRG})
    while [ ${#plate_f} != $offset ] 
    do
        plate_f=$plate_f$pad_NUM
    done
    PLATE=$plate_f$PRG$plate_l
    echo ${PLATE}
}

function convert_PLATE_to_HEX 
{
    plate=$1
    pad_plate="07"
    hex_plate="$(printf '%s' "$plate" | xxd -p -u)"
    hex_plate=$pad_plate$hex_plate
    echo ${hex_plate}
}

function extract_offset_pad 
{
    code=$1
    length_code=$2
    pad_num="0"
    offset=$(expr $length_code - ${#code})
    while [ ${#final_code} != $offset ] 
    do
        final_code=$final_code$pad_num
    done
    final_code=$final_code$code
    echo ${final_code}
}

function extract_WL_type 
{
    LIST_TYPE=$1
    if [ $LIST_TYPE == "WI" ] ; then
        LIST_TYPE="WIWI"
    else
        LIST_TYPE="WFWF"
    fi
    echo ${LIST_TYPE}
}

function extract_ACK_type 
{
    LIST_TYPE=$1
    if [ $LIST_TYPE == "WIWI" ] ; then
        ACK_TYPE="WIAK"
    else
        ACK_TYPE="WFAK"
    fi
    echo ${ACK_TYPE}
}

function get_naz_from_pvd
{
    pvd=$1
    echo ${hash_PVD_NAZ[$pvd]}
}

function generate_BAUDOT
{
    NAZ=$1
    first_ch=${NAZ:0:1}
    second_ch=${NAZ:1:1}
    first_baudot=${hash_baudot[$first_ch]}
    second_baudot=${hash_baudot[$second_ch]}

    baudot_code=$first_baudot$second_baudot
    echo ${baudot_code}
}

declare -A hash_PVD_NAZ
length=${#providers_code[@]}

for ((i=0; i<$length; i++)) ; do
	hash_PVD_NAZ["${providers_code[i]}"]="${naz_providers[i]}"
done

declare -A hash_baudot
length=${#keys[@]}

for ((i=0; i<$length; i++)) ; do
	hash_baudot["${keys[i]}"]="${values[i]}"
done

NAZ_S_PROVIDER=$(get_naz_from_pvd $S_PROVIDER)
BAUDOT_CODE=$(generate_BAUDOT $NAZ_S_PROVIDER)
LIST_TYPE=$(extract_WL_type $LIST_TYPE)


MIN=$(expr $PRG)
MAX=$(expr $MIN + $n)
list_PRG=( $(seq $MIN $MAX) )

# start the loop
for ((i=0; i<n; i++)) 
do
    PRG=${list_PRG[i]}
    echo -e "...creating white list n° $(expr $i + 1) \n"

    PAN=$(generate_PAN $PRG)
    PLATE_NUMBER=$(generate_PLATE_NUMBER $PRG $plate_f $plate_l)
    HEX_PLATE=$(convert_PLATE_to_HEX $PLATE_NUMBER)

    echo -e "...generated PAN: $PAN"
    echo -e "...generated PLATE_NUMBER: $PLATE_NUMBER \n"

    # create tmp file for the WL
    touch "$path_OUT_dir/$tmp_filename_WL"
    chmod 0777 "$path_OUT_dir/$tmp_filename_WL"

cat << EOF > "$path_OUT_dir/$tmp_filename_WL"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<infoExchange>
	<infoExchangeContent>
		<apci>
			<aidIdentifier>3</aidIdentifier>
			<apduOriginator>
				<countryCode>${BAUDOT_CODE}</countryCode>
				<providerIdentifier>${S_PROVIDER}</providerIdentifier>
			</apduOriginator>
			<informationSenderId>
				<countryCode>${BAUDOT_CODE}</countryCode>
				<providerIdentifier>${S_PROVIDER}</providerIdentifier>
			</informationSenderId>
			<informationRecipientId>
				<countryCode>0110000001</countryCode>
				<providerIdentifier>${T_CHARGER}</providerIdentifier>
			</informationRecipientId>
			<apduIdentifier>${C_APDU}</apduIdentifier>
			<apduDate>20230316175200Z</apduDate>
		</apci>
		<adus>
			<exceptionListAdus>
				<ExceptionListAdu>
					<aduIdentifier>12</aduIdentifier>
					<exceptionListVersion>1</exceptionListVersion>
					<exceptionListType>12</exceptionListType>
					<exceptionValidityStart>20230203085452Z</exceptionValidityStart>
					<exceptionListEntries>
						<ExceptionListEntry>
							<userId>
								<pan>${PAN}</pan>
								<licencePlateNumber>
									<countryCode>0110000001</countryCode>
									<alphabetIndicator>000000</alphabetIndicator>
									<licencePlateNumber>${HEX_PLATE}</licencePlateNumber>
								</licencePlateNumber>
							</userId>
							<statusType>0</statusType>
							<reasonCode>0</reasonCode>
							<entryValidityStart>20230104140028Z</entryValidityStart>
							<actionRequested>3</actionRequested>
							<efcContextMark>
								<contractProvider>
									<countryCode>${BAUDOT_CODE}</countryCode>
									<providerIdentifier>${S_PROVIDER}</providerIdentifier>
								</contractProvider>
								<typeOfContract>001D</typeOfContract>
								<contextVersion>9</contextVersion>
							</efcContextMark>
EOF
if [ $BOOL_discount ] ; then
cat << EOF >> "$path_OUT_dir/$tmp_filename_WL"
<applicableDiscounts>
<discountId>${DISCOUNT}</discountId>
</applicableDiscounts>
EOF
fi
cat << EOF >> "$path_OUT_dir/$tmp_filename_WL"             
						</ExceptionListEntry>
					</exceptionListEntries>
				</ExceptionListAdu>
			</exceptionListAdus>
		</adus>
	</infoExchangeContent>
</infoExchange>
EOF

    # pattern filename WL: DA06A56.F<naz_SP>00<cod_SP(5 chars)>T<naz_TC>00<cod_TC (5 chars)>.SET.<list_TYPE>.<unix_timestamp>.000<PRG (10 chars)>.XML
    
    const_DA_A="DA06A56.F"
    naz_TC="IT" # per ora costante
    const_T="T"
    const_SET="SET"
    unix_timestamp=$(date +%s)

    fn_S_PROVIDER=$(extract_offset_pad $S_PROVIDER 5)
    fn_T_CHARGER=$(extract_offset_pad $T_CHARGER 5)

    fn_PRG_WL=$(extract_offset_pad $fn_PRG_WL 10)
    filename_WL="$const_DA_A$NAZ_S_PROVIDER$fn_S_PROVIDER$const_T$naz_TC$fn_T_CHARGER.$const_SET.$LIST_TYPE.$unix_timestamp.$fn_PRG_WL.XML"

    mv "$path_OUT_dir/$tmp_filename_WL" "$path_OUT_dir/$filename_WL"
    filename_WL_ZIP="$filename_WL.ZIP"
    zip -q -j "$path_OUT_dir/$filename_WL_ZIP" "$path_OUT_dir/$filename_WL"
    
    # pattern filename ACK: DA06A56.F<naz_TC>00<cod_TC (5 chars)>T<naz_SP>00<cod_SP(5 chars)>.SET.<ACK_list_TYPE>.000<PRG (10 chars)>.XML

    ACK_TIPE=$(extract_ACK_type $LIST_TYPE)
    filename_ACK="$const_DA_A$naz_TC$fn_T_CHARGER$const_T$NAZ_S_PROVIDER$fn_S_PROVIDER.$const_SET.$ACK_TIPE.$fn_PRG_WL.XML"

cat << EOF > "$path_OUT_dir/$filename_ACK"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<infoExchange>
	<infoExchangeContent>
		<apci>
			<aidIdentifier>3</aidIdentifier>
			<apduOriginator>
				<countryCode>0110000001</countryCode>
				<providerIdentifier>${T_CHARGER}</providerIdentifier>
			</apduOriginator>
			<informationSenderId>
				<countryCode>0110000001</countryCode>
				<providerIdentifier>${T_CHARGER}</providerIdentifier>
			</informationSenderId>
			<informationRecipientId>
				<countryCode>${BAUDOT_CODE}</countryCode>
				<providerIdentifier>${S_PROVIDER}</providerIdentifier>
			</informationRecipientId>
			<apduIdentifier>927</apduIdentifier>
			<apduDate>20240222143716Z</apduDate>
		</apci>
		<adus>
			<ackAdus>
				<AckAdu>
					<apduIdentifier>${C_APDU}</apduIdentifier>
					<apduAckCode>2</apduAckCode>
					<actionCode>0</actionCode>
				</AckAdu>
			</ackAdus>
		</adus>
	</infoExchangeContent>
</infoExchange>    
EOF

    filename_ACK_ZIP="$filename_ACK.ZIP"
    zip -q -j "$path_OUT_dir/$filename_ACK_ZIP" "$path_OUT_dir/$filename_ACK"
   
    # increment apduIdentifier and fn_PRG_file
    let "C_APDU++"
    fn_PRG_WL="$(expr $fn_PRG_WL + 1)"
    fn_PRG_WL=$(extract_offset_pad $fn_PRG_WL 10)

    # to get different unix_timestamp
    sleep 1

done
echo
# to delete file .XML
if [[ $BOOL_delete_xml  =~ ^([yY])$ ]] ; then
    rm "$path_OUT_dir"/*.XML
fi
echo -e "...all files are present at path: '$path_OUT_dir' \n"