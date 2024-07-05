#!/bin/bash

#!/bin/bash

# usage menu
echo
echo "---------------------- Usage ----------------------"
echo -e "\n   bash $0\n\n    -n <number of white-list to generate> \n    -t <list_type> (WI or WL) \n    -o <opt. delete_file.XML> (y-n)\n    -s <service_provider code> (ex. 151) \n    -c <toll_charger> (ex. 6) \n    -a <apduIdentifier> \n    -p <progressive_number> (to generate plate automatically) \n    -f <first_plate_chars> (ex. AB) \n    -l <last_plate_chars> (ex. CD) \n    -r <PRG_white_list> \n"
echo

while getopts n:t:o:s:c:a:p:f:l:r: flag
do
    	case "${flag}" in
		n) n=${OPTARG};;
        t) LIST_TYPE=${OPTARG};;
        o) FLAG_gen=${OPTARG};;
        s) S_PROVIDER=${OPTARG};;
        c) T_CHARGER=${OPTARG};;
        a) C_APDU=${OPTARG};;
        p) PRG=${OPTARG};;
        f) plate_f=${OPTARG};;
        l) plate_l=${OPTARG};;
        r) fn_PRG_WL=${OPTARG};;
		\?) echo -e "\n Argument error! \n"; exit 0 ;;
	esac
done

# params check
if [ $# != 18 ] && [ $# != 20 ] ; then
        echo "Argument error: please digit right command."
	echo
	exit 0
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

function generate_PLATE
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


# vars delcaration
current_timestamp=$(date +"%Y%m%d")
OUT_DIR="OUT_DIR_WL"
tmp_filename_WL="tmp_filename_white_list.xml"


LIST_TYPE=$(extract_WL_type $LIST_TYPE)

# create OUT_DIR if not exist
if ! [ -d $OUT_DIR ] ; then
	mkdir $OUT_DIR
	path_OUT_dir=$(realpath $OUT_DIR)
    echo -e "...create '$OUT_DIR' at path: '$path_OUT_dir' \n"
    chmod 0777 "$path_OUT_dir"
else
	path_OUT_dir=$(realpath $OUT_DIR)
fi

# gen seq plate number
MIN=$(expr $PRG + 1)
MAX=$(expr $MIN + $n - 1)
list_PRG=( $(seq $MIN $MAX) )

# start the loop

for ((i=0; i<n; i++)) 
do
PRG=${list_PRG[i]}

echo -e "...create white list n° $(expr $i + 1) \n"

# gen PAN
PAN=$(generate_PAN $PRG)
echo -e "...generate PAN: $PAN"

# gen PLATE
PLATE=$(generate_PLATE $PRG $plate_f $plate_l)
echo -e "...generate PLATE: $PLATE \n"

HEX_PLATE=$(convert_PLATE_to_HEX $PLATE)
#echo -e "...generate HEX_PLATE: $HEX_PLATE \n"

# create tmp file for the WL
touch "$path_OUT_dir/$tmp_filename_WL"
chmod 0777 "$path_OUT_dir/$tmp_filename_WL"

#echo -e "...create '$tmp_filename_WL' at path: $(realpath $tmp_filename_WL): OK \n"

#echo -e "...generate white list with: Service Provider $S_PROVIDER, Toll Charger $T_CHARGER and apduIdentifer $C_APDU: OK \n"

# insert params into WL file
cat << EOF > "$path_OUT_dir/$tmp_filename_WL"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<infoExchange>
	<infoExchangeContent>
		<apci>
			<aidIdentifier>3</aidIdentifier>
			<apduOriginator>
				<countryCode>0110000001</countryCode>
				<providerIdentifier>${S_PROVIDER}</providerIdentifier>
			</apduOriginator>
			<informationSenderId>
				<countryCode>0110000001</countryCode>
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
									<countryCode>0110000001</countryCode>
									<providerIdentifier>${T_CHARGER}</providerIdentifier>
								</contractProvider>
								<typeOfContract>001D</typeOfContract>
								<contextVersion>9</contextVersion>
							</efcContextMark>
						</ExceptionListEntry>
					</exceptionListEntries>
				</ExceptionListAdu>
			</exceptionListAdus>
		</adus>
	</infoExchangeContent>
</infoExchange>
EOF

# modify white list filename

# pattern filename WL: DA06A56.F<naz_SP>00<cod_SP(5 chars)>T<naz_TC>00<cod_TC (5 chars)>.SET.<list_TYPE>.<unix_timestamp>.000<PRG (10 chars)>.XML

const_DA_A="DA06A56.F"
naz_SP="IT" #per ora costante
naz_TC="IT"
const_T="T"
const_SET="SET"
unix_timestamp=$(date +%s)

fn_S_PROVIDER=$(extract_offset_pad $S_PROVIDER 5)
fn_T_CHARGER=$(extract_offset_pad $T_CHARGER 5)

fn_PRG_WL=$(extract_offset_pad $fn_PRG_WL 10)

filename_WL="$const_DA_A$naz_SP$fn_S_PROVIDER$const_T$naz_TC$fn_T_CHARGER.$const_SET.$LIST_TYPE.$unix_timestamp.$fn_PRG_WL.XML"

mv "$path_OUT_dir/$tmp_filename_WL" "$path_OUT_dir/$filename_WL"
#echo -e "...change filename from '$tmp_filename_WL' to '$filename_WL': OK \n"

filename_WL_ZIP="$filename_WL.ZIP"
zip -r -q "$path_OUT_dir/$filename_WL_ZIP" "$path_OUT_dir/$filename_WL"
#echo "...zipped file white list: '$filename_WL_ZIP'"
#echo

# to do creare il file di ack relativo (NOTA: SP e TC sono swappati in caso di file di ack!)
# pattern filename ACK: DA06A56.F<naz_TC>00<cod_TC (5 chars)>T<naz_SP>00<cod_SP(5 chars)>.SET.<ACK_list_TYPE>.000<PRG (10 chars)>.XML

ACK_TIPE=$(extract_ACK_type $LIST_TYPE)
filename_ACK="$const_DA_A$naz_TC$fn_T_CHARGER$const_T$naz_SP$fn_S_PROVIDER.$const_SET.$ACK_TIPE.$fn_PRG_WL.XML"

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
                <countryCode>0110000001</countryCode>
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
zip -r -q "$path_OUT_dir/$filename_ACK_ZIP" "$path_OUT_dir/$filename_ACK"
#echo "...zipped file ACK: '$filename_ACK_ZIP'"
#echo

# increment apduIdentifier and fn_PRG_file
let "C_APDU++"
fn_PRG_WL="$(expr $fn_PRG_WL + 1)"
fn_PRG_WL=$(extract_offset_pad $fn_PRG_WL 10)

# to return unix_timestamp !=
sleep 1

done
echo
# to delete file .XML
if [[ $FLAG_gen  =~ ^([yY])$ ]] ; then
    rm "$path_OUT_dir"/*.XML
fi

