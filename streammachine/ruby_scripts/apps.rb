# The case doesn't matter in these. It will be ignored.
APPS = [
  ["KPCCPublicRadioiPhoneApp/2\.0", "KPCC App 2.0"],
  ["KPCCRadio/1\.2", "KPCC App 1.2"],
  ["AppleCoreMedia/1\.0.+?iPad", "iPad"],
  ["AppleCoreMedia/1\.0", "Other iOS"],
  ["NPRRadio", "NPR App"],
  ["Mozilla", "Web Player"],
  ["iTunes/10", "iTunes"],
  ["TuneIn Radio", "TuneIn Radio"],
  ["PublicRadioTuner", "APM App"],
  ["Roku SoundBridge", "Roku"],
  ["SHOUTcast Metadata Puller", "SHOUTCAST Meta"],
  ["Lavf", "LAVF"],
  ["iheartradio", "iHeartRadio"],
  ["NSPlayer", "NSPlayer"],
  ["WMPlayer", "WMPlayer"]
]

TITLES = APPS.map { |a| a[1] }
