# Run the setup script (see _setup.sh for more details)
. _setup.sh

# Usage:
# ./generate_audio_report.sh logs/media-access.log audio_2014-01.csv
echo "Generating Audio report..."
ruby -W0 ${SRC_DIR}/ruby_scripts/parse_media_log.rb $1 > ${PARSED_DIR}/$2
