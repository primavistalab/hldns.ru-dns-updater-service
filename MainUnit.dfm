object HLDNSService: THLDNSService
  OldCreateOrder = False
  AllowPause = False
  DisplayName = 'HLDNSService'
  OnExecute = ServiceExecute
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
