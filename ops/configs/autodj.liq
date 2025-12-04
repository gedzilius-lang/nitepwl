#!/usr/bin/liquidsoap
set("log.stdout", false) # Disable logs to stdout so we don't corrupt the audio pipe
set("log.file", true)
set("log.file.path", "/var/log/liquidsoap/radio.log")
set("init.allow_root", true)

# Playlist
audio = playlist("/var/www/autodj/music")
audio = mksafe(audio)

# Output RAW audio to STDOUT (Pipe)
output.file(
  %wav, 
  "/dev/stdout", 
  audio
)
