# Run the setup script (see _setup.sh for more details)
. _setup.sh

# Usage:
# ./generate_soundexchange_reports.sh
echo "Generating SoundExchange report..."
ruby -W0 ${SRC_DIR}/ruby_scripts/parse_w3c_logs_for_soundexchange.rb $FULL_LOG > ${PARSED_DIR}/StreamMachine-SoundExchange-${FN_DATE}.txt
