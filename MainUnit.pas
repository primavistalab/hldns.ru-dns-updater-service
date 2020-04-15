unit MainUnit;

interface

uses
  Windows, Messages, SysUtils, Graphics, Controls, SvcMgr, Dialogs,  Classes,
  httpsend, IniFiles;

type
  THLDNSService = class(TService)
    procedure ServiceExecute(Sender: TService);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
  private
    { Private declarations }
    log : TextFile;
    logReady : boolean;
    http : THTTPSend;
    DNS_UPDATE_URL : String;
    DNS_UPDATE_TIME_MIN : Integer;
    procedure SendUpdateRequest;
    procedure ReadConfig;
    procedure WriteLog(const AText : String);
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  hldnsupdate: THLDNSService;

implementation


{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  hldnsupdate.Controller(CtrlCode);
end;

function THLDNSService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure THLDNSService.WriteLog(const AText: String);
begin
  if (logReady) then
    begin
      Writeln(log, DateTimeToStr(Now) + ' ' + AText);
      Flush(log);
    end;
end;

procedure THLDNSService.ReadConfig;
var
  ini : TIniFile;
begin
  ini := TIniFile.Create(ExtractFileDir(ParamStr(0)) + '\config.ini');
  try
    DNS_UPDATE_URL := ini.ReadString('HLDNSService', 'URL', '');
    DNS_UPDATE_TIME_MIN := ini.ReadInteger('HLDNSService', 'Interval', 5);
    if (DNS_UPDATE_TIME_MIN < 5) then
      DNS_UPDATE_TIME_MIN := 5;
  finally
    FreeAndNil(ini);
  end;
end;

procedure THLDNSService.SendUpdateRequest;
var
  stream : TStringStream;
begin
  http.Cookies.Clear;
  http.Headers.Clear;
  http.Document.Clear;

  if (http.HTTPMethod('GET', DNS_UPDATE_URL)) then
    begin
      if (http.ResultCode = 200) then
        begin
          stream := TStringStream.Create('');
          try
            http.Document.SaveToStream(stream);
            WriteLog('HTTP request answer: ' + stream.DataString);
          finally
            FreeAndNil(stream);
          end;
        end
      else
        WriteLog('HTTP request code is ' + IntToStr(http.ResultCode));
    end
  else
    WriteLog('HTTP request is failed');
end;

procedure THLDNSService.ServiceExecute(Sender: TService);
var
  lastUpdate, diffUpdate, updateTimeInDays : TDateTime;
begin
  updateTimeInDays := DNS_UPDATE_TIME_MIN / 60.0 / 24.0;
  lastUpdate := 0;
  while not Terminated do
  begin
    diffUpdate := Now - lastUpdate;
    if (updateTimeInDays <= diffUpdate) then
      begin
        SendUpdateRequest;
        lastUpdate := Now;
      end;

    Sleep(100);
    ServiceThread.ProcessRequests(False);
  end;
end;

procedure THLDNSService.ServiceStart(Sender: TService; var Started: Boolean);
var
  logName : string;
begin
  http := THTTPSend.Create;
  http.Timeout := 1000;

  ReadConfig;

  logName := ExtractFileDir(ParamStr(0)) + '\log' + FormatDateTime('_yyymmdd_hhnnss', Now) + '.txt';
  {$I-}
  AssignFile(log, logName);
  Rewrite(log);
  logReady := (IOResult = 0);
  {$I+}
  WriteLog('---=== hldns.ru update client ===---');
  WriteLog('Update URL: ' + DNS_UPDATE_URL);
  WriteLog('Update interval: ' + IntToStr(DNS_UPDATE_TIME_MIN) + ' min.');
  WriteLog('Service is started');
end;

procedure THLDNSService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  http.Free;

  WriteLog('Service is stopped');
  if (logReady) then
    CloseFile(log);
end;

end.
