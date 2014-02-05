# First, download all the necessary reports and place them in a directory.
# Pass the path to that directory to this script.

# Date for filename
FN_DATE=$(date "+%Y-%m-%d")

# The directory of this script.
SRC_DIR=$(cd "$(dirname "$0")"; pwd)


# The path to files we need
LOG_DIR=${SRC_DIR}/logs
PARSED_DIR=${SRC_DIR}/parsed

if [ ! -d "${LOG_DIR}" ]; then
    mkdir $LOG_DIR
fi

if [ ! -d "${PARSED_DIR}" ]; then
    mkdir $PARSED_DIR
fi
