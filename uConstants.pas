UNIT uConstants;

{ ****************************************************************************** }
{ * UNITÉ DE CONSTANTES - VERSION MASTER                                      * }
{ * Combine V1/V2/V3 : Chemins, Types, Fonctions Globales                     * }
{ ****************************************************************************** }

INTERFACE

USES System.SysUtils, System.UITypes, System.Classes, System.IOUtils, Vcl.Graphics, Vcl.Forms, Winapi.Windows;

CONST
  // === APPLICATION ===
    APP_NAME = 'Grh_accdb'; APP_VERSION = '4.0 Master Edition'; WM_APPLY_SETTINGS = 1026;

  // === CHEMINS ===
  DIR_DATABASE = 'Database'; DIR_STYLES = 'VCLStyles'; DIR_CONFIG = 'Parametres'; DIR_PRESETS = 'Presets';
  DIR_LOGS     = 'Logs';

  // === FICHIERS ===
  FILE_DATABASE = 'Grh_db.accdb'; FILE_CONFIG_SUFFIX = '_cfg.ini'; FILE_STYLE_EXTENSION = '*.vsf';
  FILE_PRESETS  = 'Presets.json'; FILE_LOG = 'Application.log';

  // === SECTIONS INI (V1/V2 Compatible) ===
  INI_SECTION_WINDOW     = 'Window'; INI_SECTION_APPEARANCE = 'Appearance'; INI_SECTION_OPTIONS = 'Options';
  INI_SECTION_STATISTICS = 'Statistics'; INI_SECTION_CONTROLS = 'Controls';

  // === CLÉS INI ===
  INI_KEY_TOP   = 'Top'; INI_KEY_LEFT = 'Left'; INI_KEY_WIDTH = 'Width'; INI_KEY_HEIGHT = 'Height';
  INI_KEY_STATE = 'State'; INI_KEY_MAXIMIZED = 'Maximized'; INI_KEY_STYLE = 'Style'; INI_KEY_FONT_NAME = 'FontName';
  INI_KEY_FONT_SIZE = 'FontSize'; INI_KEY_FONT_BOLD = 'FontBold'; INI_KEY_FONT_ITALIC = 'FontItalic';
  INI_KEY_FONT_UNDERLINE = 'FontUnderline'; INI_KEY_NC_COLOR = 'NCColor'; INI_KEY_NC_ENABLED = 'NCColorEnabled';
  INI_KEY_ALWAYS_ON_TOP  = 'AlwaysOnTop'; INI_KEY_SHOW_HINTS = 'ShowHints'; INI_KEY_SHOW_STATUSBAR = 'ShowStatusBar';
  INI_KEY_ACCESS_COUNT   = 'AccessCount'; INI_KEY_LAST_ACCESS = 'LastAccess'; INI_KEY_TOTAL_RUNTIME = 'TotalRunTime';
  INI_KEY_FIRST_USE      = 'FirstUse'; INI_KEY_SNAPPED = 'Snapped'; INI_KEY_SNAPPED_SIZE = 'Snapped_sise';

  // === VALEURS PAR DÉFAUT ===
  DEFAULT_WINDOW_WIDTH = 900; DEFAULT_WINDOW_HEIGHT = 600; DEFAULT_WINDOW_LEFT = 100; DEFAULT_WINDOW_TOP = 100;
  DEFAULT_FONT_NAME    = 'Segoe UI'; DEFAULT_FONT_SIZE = 9; DEFAULT_FONT_SIZE_APP = 9; DEFAULT_NC_COLOR = $002F4F4F;
  // DarkSlategray
  DEFAULT_BG_COLOR   = $002F4F2F; // DarkOliveGreen
  DEFAULT_STYLE_NAME = 'Windows';

TYPE
  { ** Structure Fenêtre (V1/V2/V3 Fusionné) ** }
  TWindowSettings = RECORD
    Top, Left, Width, Height: Integer;
    WindowState: TWindowState;
    Maximized: Boolean; // V3
    AlwaysOnTop: Boolean; // V2/V3
    PROCEDURE ResetToDefaults;
  END;

  { ** Structure Apparence (V1/V2/V3 Fusionné) ** }
  TAppearanceSettings = RECORD
    StyleName: STRING;
    FontName: STRING;
    FontSize: Integer;
    Bold, Italic, Underline: Boolean; // V1 Séparé
    EdgeColor: TColor; // V1/V2 (alias NCColor V3)
    EdgeColorEnabled: Boolean; // V1/V2 (alias NCEnabled V3)
    PROCEDURE ResetToDefaults;
    // V3 Alias pour compatibilité
    FUNCTION GetNCColor: TColor;
    PROCEDURE SetNCColor(AColor: TColor);
    FUNCTION GetNCEnabled: Boolean;
    PROCEDURE SetNCEnabled(AEnabled: Boolean);
    PROPERTY NCColor: TColor READ GetNCColor WRITE SetNCColor;
    PROPERTY NCEnabled: Boolean READ GetNCEnabled WRITE SetNCEnabled;
  END;

  { ** Structure Options (V2/V3 Fusionné) ** }
  TUserOptions = RECORD
    ShowHints: Boolean;
    ShowStatusBar: Boolean;
    PROCEDURE ResetToDefaults;
  END;

  { ** Structure Statistiques (V1/V2 Compatible) ** }
  TUsageStatistics = RECORD
    AccessCount: Integer;
    LastAccessDate: TDateTime;
    TotalRunTime: Integer;
    FirstUse: TDateTime;
    PROCEDURE ResetToDefaults;
  END;

  { ** Structure Complète (V1/V2/V3 Unifié) ** }
  TApplicationSettings = RECORD
    Window: TWindowSettings;
    Appearance: TAppearanceSettings;
    Options: TUserOptions;
    Statistics: TUsageStatistics;
    PROCEDURE ResetToDefaults;
  END;

  // === FONCTIONS GLOBALES (V1/V2/V3 Unifié) ===
FUNCTION GetAppPath: STRING;
FUNCTION GetConfigDirectory: STRING;
FUNCTION GetConfigFilePath: STRING;
FUNCTION GetDatabasePath: STRING;
FUNCTION GetStylesDirectory: STRING;
FUNCTION GetPresetsDirectory: STRING;
FUNCTION GetLogsDirectory: STRING;
FUNCTION GetPresetFileName: STRING;
FUNCTION GetLogFilePath: STRING;

// V3 Addition
PROCEDURE EnsureDirectoriesExist;
PROCEDURE DebugPaths;
// V1 Utilities
FUNCTION NormalizeColor(C: TColor): TColor;
PROCEDURE AlphaBlendForm(Frm: TForm);

IMPLEMENTATION

{ TWindowSettings }
PROCEDURE TWindowSettings.ResetToDefaults;
BEGIN
  Top := DEFAULT_WINDOW_TOP;
  Left := DEFAULT_WINDOW_LEFT;
  Width := DEFAULT_WINDOW_WIDTH;
  Height := DEFAULT_WINDOW_HEIGHT;
  WindowState := wsNormal;
  Maximized := False;
  AlwaysOnTop := False;
END;

{ TAppearanceSettings }
PROCEDURE TAppearanceSettings.ResetToDefaults;
BEGIN
  StyleName := DEFAULT_STYLE_NAME;
  FontName := DEFAULT_FONT_NAME;
  FontSize := DEFAULT_FONT_SIZE;
  Bold := False;
  Italic := False;
  Underline := False;
  EdgeColor := DEFAULT_NC_COLOR;
  EdgeColorEnabled := False;
END;

FUNCTION TAppearanceSettings.GetNCColor: TColor;
BEGIN
  Result := EdgeColor;
END;

PROCEDURE TAppearanceSettings.SetNCColor(AColor: TColor);
BEGIN
  EdgeColor := AColor;
END;

FUNCTION TAppearanceSettings.GetNCEnabled: Boolean;
BEGIN
  Result := EdgeColorEnabled;
END;

PROCEDURE TAppearanceSettings.SetNCEnabled(AEnabled: Boolean);
BEGIN
  EdgeColorEnabled := AEnabled;
END;

{ TUserOptions }
PROCEDURE TUserOptions.ResetToDefaults;
BEGIN
  ShowHints := True;
  ShowStatusBar := True;
END;

{ TUsageStatistics }
PROCEDURE TUsageStatistics.ResetToDefaults;
BEGIN
  AccessCount := 0;
  LastAccessDate := Now;
  TotalRunTime := 0;
  FirstUse := Now;
END;

{ TApplicationSettings }
PROCEDURE TApplicationSettings.ResetToDefaults;
BEGIN
  Window.ResetToDefaults;
  Appearance.ResetToDefaults;
  Options.ResetToDefaults;
  Statistics.ResetToDefaults;
END;

{ ============================================================================== }
{ FONCTIONS GLOBALES }
{ ============================================================================== }

FUNCTION GetAppPath: STRING;
BEGIN
  // Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));     //
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName));
END;

FUNCTION GetConfigDirectory: STRING;
BEGIN
  Result := TPath.Combine(GetAppPath, DIR_CONFIG);
END;

FUNCTION GetConfigFilePath: STRING;
BEGIN
  Result := TPath.Combine(GetConfigDirectory, ChangeFileExt(ExtractFileName(Application.ExeName), FILE_CONFIG_SUFFIX));
  // ChangeFileExt(ExtractFileName(ParamStr(0)), FILE_CONFIG_SUFFIX));
END;

FUNCTION GetDatabasePath: STRING;
BEGIN
  Result := TPath.Combine(TPath.Combine(GetAppPath, DIR_DATABASE), FILE_DATABASE);
END;

FUNCTION GetStylesDirectory: STRING;
BEGIN
  Result := TPath.Combine(GetAppPath, DIR_STYLES);
END;

FUNCTION GetPresetsDirectory: STRING;
BEGIN
  Result := TPath.Combine(GetAppPath, DIR_PRESETS);
END;

FUNCTION GetLogsDirectory: STRING;
BEGIN
  Result := TPath.Combine(GetAppPath, DIR_LOGS);
END;

FUNCTION GetPresetFileName: STRING;
BEGIN
  Result := TPath.Combine(GetPresetsDirectory, FILE_PRESETS);
END;

FUNCTION GetLogFilePath: STRING;
BEGIN
  Result := TPath.Combine(GetLogsDirectory, FILE_LOG);
END;

PROCEDURE EnsureDirectoriesExist;
BEGIN
  ForceDirectories(GetConfigDirectory);
  ForceDirectories(GetStylesDirectory);
  ForceDirectories(GetPresetsDirectory);
  ForceDirectories(GetLogsDirectory);
  ForceDirectories(TPath.GetDirectoryName(GetDatabasePath));
END;

// Dans uConstants.txt, ajoutez cette procédure
PROCEDURE DebugPaths;
VAR LogFile: TextFile; LogPath: STRING;
BEGIN
  LogPath := GetAppPath + 'PathDebug.txt';
  AssignFile(LogFile, LogPath);
  Rewrite(LogFile);
  TRY
    WriteLn(LogFile, '=== DIAGNOSTIC DES CHEMINS ===');
    WriteLn(LogFile, 'Date: ' + DateTimeToStr(Now));
    WriteLn(LogFile, '');
    WriteLn(LogFile, 'ParamStr(0): ' + ParamStr(0));
    WriteLn(LogFile, 'Application.ExeName: ' + Application.ExeName);
    WriteLn(LogFile, 'GetAppPath: ' + GetAppPath);
    WriteLn(LogFile, 'GetStylesDirectory: ' + GetStylesDirectory);
    WriteLn(LogFile, 'Current Dir: ' + GetCurrentDir);
    WriteLn(LogFile, '');
    WriteLn(LogFile, '=== VÉRIFICATION RÉPERTOIRES ===');
    IF DirectoryExists(GetStylesDirectory) THEN WriteLn(LogFile, '✓ VCLStyles existe: ' + GetStylesDirectory)
    ELSE WriteLn(LogFile, '✗ VCLStyles introuvable: ' + GetStylesDirectory);
  FINALLY CloseFile(LogFile);
  END;
END;

FUNCTION NormalizeColor(C: TColor): TColor;
BEGIN
  Result := ColorToRGB(C);
END;

PROCEDURE AlphaBlendForm(Frm: TForm);
BEGIN
  IF NOT Assigned(Frm) THEN Exit;
  Frm.AlphaBlend := True;
  Frm.AlphaBlendValue := 0;

  TThread.CreateAnonymousThread(PROCEDURE
    VAR i: Integer;
    BEGIN
      FOR i := 0 TO 255 DO BEGIN
        TThread.Synchronize(NIL, PROCEDURE
          BEGIN
            IF Assigned(Frm) THEN Frm.AlphaBlendValue := i;
          END);
        Sleep(1);
      END;
      TThread.Synchronize(NIL, PROCEDURE
        BEGIN
          IF Assigned(Frm) THEN Frm.AlphaBlend := False;
        END);
    END).Start;
END;

END.
