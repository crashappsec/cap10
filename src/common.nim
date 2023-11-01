## :Author: John Viega (john@crashoverride.com)
## :Copyright: 2023, Crash Override, Inc.

type
  CaptureContentType = enum CctInput, CctOutput
  CaptureState* = object
    includeInput*:    bool
    fd*:              cint

  WriteHeader* = object
    timeStamp*:      uint64
    contentLen*:     int
