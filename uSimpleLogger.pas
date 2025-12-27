UNIT uSimpleLogger;

{ ****************************************************************************** }
{ * LOGGER SIMPLE - VERSION MASTER (Basé V2, Amélioré)                        * }
{ * Fonctionnalités:                                                           * }
{ *   - Thread-Safe avec TCriticalSection                                      * }
{ *   - Niveaux: Debug, Info, Warning, Error                                   * }
{ *   - Rotation automatique (limite 10 MB)                                    * }
{ *   - OutputDebugString pour IDE                                             * }
{ ****************************************************************************** }

INTERFACE

USES System.SysUtils, System.Classes, System.IOUtils, System.SyncObjs, Winapi.Windows, uConstants;

TYPE
  TLogLevel = (llDebug, llInfo, llWarning, llError);

  TSimpleLogger = CLASS
  PRIVATE
    CLASS VAR FInstance: TSimpleLogger;

  CLASS VAR
    FLock: TCriticalSection;

    FLogFile:     STRING;
    FEnabled:     Boolean;
    FMaxFileSize: Int64; // 10 MB par défaut

    CONSTRUCTOR Create;
    PROCEDURE WriteToFile(CONST AText: STRING);
    PROCEDURE CheckFileSize;
    FUNCTION GetLevelStr(ALevel: TLogLevel): STRING;
  PUBLIC
    CLASS FUNCTION Instance: TSimpleLogger;
    CLASS DESTRUCTOR DestroyClass;

    PROCEDURE Log(CONST AComponent, AMessage: STRING); OVERLOAD;
    PROCEDURE LogEx(ALevel: TLogLevel; CONST AComponent, AMessage: STRING); OVERLOAD;
    PROCEDURE LogError(CONST AMessage: STRING);
    PROCEDURE LogWarning(CONST AMessage: STRING);
    PROCEDURE LogDebug(CONST AComponent, AMessage: STRING);

    FUNCTION GetEnabled: Boolean;
    PROCEDURE SetEnabled(AValue: Boolean);

    PROPERTY Enabled: Boolean READ GetEnabled WRITE SetEnabled;
  END;

IMPLEMENTATION

{ TSimpleLogger }

CONSTRUCTOR TSimpleLogger.Create;
BEGIN
  INHERITED Create;
  FLogFile := GetLogFilePath;
  FEnabled := True;
  FMaxFileSize := 10 * 1024 * 1024; // 10 MB

  // Créer le dossier si nécessaire
  ForceDirectories(ExtractFilePath(FLogFile));

  // Message de démarrage
  WriteToFile(StringOfChar('=', 80));
  WriteToFile('APPLICATION STARTED - ' + DateTimeToStr(Now));
  WriteToFile(StringOfChar('=', 80));
END;

CLASS FUNCTION TSimpleLogger.Instance: TSimpleLogger;
BEGIN
  IF FInstance = NIL THEN BEGIN
    IF NOT Assigned(FLock) THEN FLock := TCriticalSection.Create;

    FLock.Enter;
    TRY
      IF FInstance = NIL THEN FInstance := TSimpleLogger.Create;
    FINALLY FLock.Leave;
    END;
  END;
  Result := FInstance;
END;

CLASS DESTRUCTOR TSimpleLogger.DestroyClass;
BEGIN
  IF Assigned(FLock) THEN BEGIN
    FLock.Enter;
    TRY
      IF Assigned(FInstance) THEN BEGIN
        FInstance.WriteToFile('APPLICATION STOPPED - ' + DateTimeToStr(Now));
        FreeAndNil(FInstance);
      END;
    FINALLY FLock.Leave;
    END;
    FreeAndNil(FLock);
  END;
END;

PROCEDURE TSimpleLogger.WriteToFile(CONST AText: STRING);
VAR LFile: TextFile;
BEGIN
  IF NOT FEnabled THEN Exit;

  FLock.Enter;
  TRY
    CheckFileSize;

    AssignFile(LFile, FLogFile);
    IF FileExists(FLogFile) THEN Append(LFile)
    ELSE Rewrite(LFile);

    TRY WriteLn(LFile, AText);
    FINALLY CloseFile(LFile);
    END;
  FINALLY FLock.Leave;
  END;
END;

PROCEDURE TSimpleLogger.CheckFileSize;
VAR LBackup: STRING;
BEGIN
  IF FileExists(FLogFile) THEN BEGIN
    IF TFile.GetSize(FLogFile) > FMaxFileSize THEN BEGIN
      LBackup := ChangeFileExt(FLogFile, '.old.log');
      IF FileExists(LBackup) THEN DeleteFile(pchar(LBackup));
      RenameFile(FLogFile, LBackup);
    END;
  END;
END;

FUNCTION TSimpleLogger.GetLevelStr(ALevel: TLogLevel): STRING;
BEGIN
  CASE ALevel OF
  llDebug: Result := '[DEBUG]  ';
  llInfo: Result := '[INFO]   ';
  llWarning: Result := '[WARNING]';
  llError: Result := '[ERROR]  ';
ELSE Result := '[UNKNOWN]';
  END;
END;

PROCEDURE TSimpleLogger.Log(CONST AComponent, AMessage: STRING);
BEGIN
  LogEx(llInfo, AComponent, AMessage);
END;

PROCEDURE TSimpleLogger.LogEx(ALevel: TLogLevel; CONST AComponent, AMessage: STRING);
VAR LLine, LDebugMsg: STRING;
BEGIN
  LLine := Format('%s %s [%s] %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), GetLevelStr(ALevel), AComponent,
    AMessage]);

  WriteToFile(LLine);

  // Envoi vers OutputDebugString pour Delphi IDE
  LDebugMsg := Format('[%s] %s', [AComponent, AMessage]);
  OutputDebugString(pchar(LDebugMsg));
END;

PROCEDURE TSimpleLogger.LogError(CONST AMessage: STRING);
BEGIN
  LogEx(llError, 'SYSTEM', AMessage);
END;

PROCEDURE TSimpleLogger.LogWarning(CONST AMessage: STRING);
BEGIN
  LogEx(llWarning, 'SYSTEM', AMessage);
END;

PROCEDURE TSimpleLogger.LogDebug(CONST AComponent, AMessage: STRING);
BEGIN
{$IFDEF DEBUG}
  LogEx(llDebug, AComponent, AMessage);
{$ENDIF}
END;

FUNCTION TSimpleLogger.GetEnabled: Boolean;
BEGIN
  Result := FEnabled;
END;

PROCEDURE TSimpleLogger.SetEnabled(AValue: Boolean);
BEGIN
  FEnabled := AValue;
END;

END.
