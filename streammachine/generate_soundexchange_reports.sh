# Run the setup script (see _setup.sh for more details)
. _setup.sh

echo "Generating SoundExchange report..."
ruby -W0 ${SRC_DIR}/ruby_scripts/parse_w3c_logs_for_soundexchange.rb $FULL_LOG
