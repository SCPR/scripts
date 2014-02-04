# Run the setup script (see _setup.sh for more details)
. _setup.sh

echo "Converting to CSV..."
ruby -W0 ${SRC_DIR}/ruby_scripts/parse_w3c_logs_to_csv.rb $FULL_LOG

# Parse Stream Starts
echo "Generating Stream Starts Stats..."
ruby -W0 ${SRC_DIR}/ruby_scripts/parse_stream_starts.rb $CSV_LOG > parsed/${FN_DATE}_stream_starts.csv

# Parse Hours Listened
echo "Generating Hours Listened Stats..."
ruby -W0 ${SRC_DIR}/ruby_scripts/parse_dates.rb $CSV_LOG > parsed/${FN_DATE}_hours_listened.csv
