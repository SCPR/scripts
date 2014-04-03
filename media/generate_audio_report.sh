# Run the setup script (see _setup.sh for more details)
. _setup.sh

# Usage:
# ./generate_audio_report.sh logs/media-access.log
echo "Generating Audio report... (Ctrl-C to cancel)"
echo "First log line is: "
head -n1 $1
ruby -W0 ${SRC_DIR}/ruby_scripts/parse_media_log.rb $1
