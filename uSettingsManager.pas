UNIT uSettingsManager;

{ ****************************************************************************** }
{ * GESTIONNAIRE DE PARAMÈTRES - VERSION MASTER                               * }
{ * Fusion V1 (SaveControlState) + V2 (ApplyAll Optimisé) + V3 (Property)     * }
{ * - Thread-Safe avec TCriticalSection                                        * }
{ * - Singleton avec Property CLASS (V3)                                       * }
{ * - Sauvegarde État Contrôles (V1)                                           * }
{ * - Validation Position Écran Multi-Moniteurs (V1/V2)                        * }
{ * - Statistiques d'Utilisation (V1/V2)                                       * }
{ ****************************************************************************** }
INTERFACE

USES System.SysUtils, System.Classes, System.IniFiles, System.IOUtils, System.DateUtils, System.SyncObjs, System.Types,
  Vcl.Forms, Vcl.Graphics, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Themes,
  Vcl.Styles.FormStyleHooks, Winapi.Windows, Winapi.Messages, Winapi.MultiMon, dnSplitter, uConstants, uStyleManager,
  uFontManager, uSimpleLogger;

TYPE
  TSettingsManager = CLASS
  PRIVATE
    CLASS VAR FInstance:  TSettingsManager;
    CLASS VAR FLock:      TCriticalSection;
    CLASS VAR FStartTime: TDateTime;

  CLASS VAR
    FSettings:   TApplicationSettings; // V3: Class var pour property
    FConfigPath: STRING;
    FIsLoaded:   Boolean;
    CONSTRUCTOR Create;
    // Validation Position (V1/V2)
    FUNCTION IsPositionVisible(ALeft, ATop, AWidth, AHeight: Integer): Boolean;
    // Chargement Sections
    PROCEDURE LoadWindowSettings(AConfig: TMemIniFile);
    PROCEDURE LoadAppearanceSettings(AConfig: TMemIniFile);
    PROCEDURE LoadOptionsSettings(AConfig: TMemIniFile);
    PROCEDURE LoadStatisticsSettings(AConfig: TMemIniFile);
    // Sauvegarde Sections
    PROCEDURE SaveWindowSettings(AConfig: TMemIniFile; AForm: TForm);
    PROCEDURE SaveAppearanceSettings(AConfig: TMemIniFile);
    PROCEDURE SaveOptionsSettings(AConfig: TMemIniFile);
    PROCEDURE SaveStatisticsSettings(AConfig: TMemIniFile);
    // V3: Getters/Setters pour Property CLASS
    CLASS FUNCTION GetSettings: TApplicationSettings; STATIC;
    CLASS PROCEDURE SetSettings(CONST Value: TApplicationSettings); STATIC;
    // Getters pour properties d'instance
    FUNCTION GetWindowSettings: TWindowSettings;
    FUNCTION GetAppearanceSettings: TAppearanceSettings;
    FUNCTION GetUserOptions: TUserOptions;
    FUNCTION GetUsageStatistics: TUsageStatistics;
  PUBLIC
    CLASS FUNCTION GetInstance: TSettingsManager;
    DESTRUCTOR Destroy; OVERRIDE;
    CLASS CONSTRUCTOR CreateClass;
    CLASS DESTRUCTOR DestroyClass;
    // V3: Property CLASS pour accès facile
    CLASS PROPERTY Settings: TApplicationSettings READ GetSettings WRITE SetSettings;
    // Chargement/Sauvegarde Principal
    PROCEDURE LoadSettings; OVERLOAD;
    PROCEDURE LoadSettings(AForm: TForm); OVERLOAD; // V1 Compatible
    PROCEDURE SaveSettings; OVERLOAD;
    PROCEDURE SaveSettings(AForm: TForm); OVERLOAD; // V1 Compatible
    // V1: Sauvegarde/Chargement État Contrôles
    PROCEDURE SaveControlState(AControl: TControl; CONST Section: STRING);
    PROCEDURE LoadControlState(AControl: TControl; CONST Section: STRING);
    // Application Paramètres
    PROCEDURE ApplyAll(AForm: TForm);
    PROCEDURE ApplyWindow(AForm: TForm);
    PROCEDURE ApplyAppearance(AForm: TForm);
    PROCEDURE ApplyFont(AForm: TForm);
    PROCEDURE ApplyOptions(AForm: TForm);
    // Statistiques
    PROCEDURE UpdateStats;
    // Getters Individuels (V1 Compatible)
    FUNCTION GetAccessCount: Integer;
    FUNCTION GetLastAccessDate: TDateTime;
    FUNCTION GetTotalRunTime: Integer;
    FUNCTION GetIsLoaded: Boolean;
    // Setters Individuels (V1 Compatible)
    PROCEDURE SetStyleName(CONST AStyle: STRING);
    PROCEDURE SetFontSettings(CONST AFontName: STRING; AFontSize: Integer);
    PROCEDURE SetFontStyle(ABold, AItalic, AUnderline: Boolean);
    PROCEDURE SetNCColor(AColor: TColor);
    PROCEDURE SetNCColorEnabled(AEnabled: Boolean);
    PROCEDURE SetEdgeColor(AColor: TColor);
    PROCEDURE SetEdgeColorEnabled(AEnabled: Boolean);
    PROCEDURE SetShowHints(AEnabled: Boolean);
    PROCEDURE SetShowStatusBar(AEnabled: Boolean);
    PROCEDURE SetAlwaysOnTop(AEnabled: Boolean);
    PROCEDURE SetWindowSize(AWidth, AHeight: Integer);
    // Properties V1 Compatible (utilisant des getters)
    PROPERTY IsLoaded: Boolean READ GetIsLoaded;
    PROPERTY WindowSettings: TWindowSettings READ GetWindowSettings;
    PROPERTY AppearanceSettings: TAppearanceSettings READ GetAppearanceSettings;
    PROPERTY UserOptions: TUserOptions READ GetUserOptions;
    PROPERTY UsageStatistics: TUsageStatistics READ GetUsageStatistics;
  END;

IMPLEMENTATION

{ TSettingsManager }
CLASS CONSTRUCTOR TSettingsManager.CreateClass;
BEGIN
  FLock := TCriticalSection.Create;
  FSettings.ResetToDefaults;
END;

CLASS DESTRUCTOR TSettingsManager.DestroyClass;
BEGIN
  FLock.Free;
END;

CLASS FUNCTION TSettingsManager.GetInstance: TSettingsManager;
BEGIN
  FLock.Enter;
  TRY
    IF FInstance = NIL THEN BEGIN
      FInstance := TSettingsManager.Create;
      FStartTime := Now;
    END;
    Result := FInstance;
  FINALLY FLock.Leave;
  END;
END;

CONSTRUCTOR TSettingsManager.Create;
BEGIN
  INHERITED Create;
  FConfigPath := GetConfigFilePath;
  FIsLoaded := False;
  TSimpleLogger.Instance.Log('TSettingsManager', 'Instance créée');
END;

DESTRUCTOR TSettingsManager.Destroy;
BEGIN
  TSimpleLogger.Instance.Log('TSettingsManager', 'Instance détruite');
  INHERITED Destroy;
END;

CLASS FUNCTION TSettingsManager.GetSettings: TApplicationSettings;
BEGIN
  Result := FSettings;
END;

CLASS PROCEDURE TSettingsManager.SetSettings(CONST Value: TApplicationSettings);
BEGIN
  FSettings := Value;
END;

FUNCTION TSettingsManager.GetWindowSettings: TWindowSettings;
BEGIN
  Result := FSettings.Window;
END;

FUNCTION TSettingsManager.GetAppearanceSettings: TAppearanceSettings;
BEGIN
  Result := FSettings.Appearance;
END;

FUNCTION TSettingsManager.GetUserOptions: TUserOptions;
BEGIN
  Result := FSettings.Options;
END;

FUNCTION TSettingsManager.GetUsageStatistics: TUsageStatistics;
BEGIN
  Result := FSettings.Statistics;
END;

{ ============================================================================== }
{ VALIDATION POSITION FENÊTRE (V1/V2) }
{ ============================================================================== }
FUNCTION TSettingsManager.IsPositionVisible(ALeft, ATop, AWidth, AHeight: Integer): Boolean;
VAR FormRect, WorkRect: TRect; I: Integer;
BEGIN
  Result := False;
  FormRect := Rect(ALeft, ATop, ALeft + AWidth, ATop + AHeight);
  // Vérifier sur tous les moniteurs
  FOR I := 0 TO Screen.MonitorCount - 1 DO BEGIN
    WorkRect := Screen.Monitors[I].WorkareaRect;
    IF IntersectRect(FormRect, FormRect, WorkRect) THEN BEGIN
      Result := True;
      Break;
    END;
  END;
END;

{ ============================================================================== }
{ CHARGEMENT PARAMÈTRES }
{ ============================================================================== }
PROCEDURE TSettingsManager.LoadSettings;
BEGIN
  LoadSettings(NIL);
END;

PROCEDURE TSettingsManager.LoadSettings(AForm: TForm);
VAR Config: TMemIniFile; IsFirstRun: Boolean;
BEGIN
  IsFirstRun := NOT TFile.Exists(FConfigPath);
  IF IsFirstRun THEN BEGIN
    TSimpleLogger.Instance.Log('TSettingsManager', 'Premier démarrage détecté');
    FSettings.ResetToDefaults;
    IF Assigned(AForm) THEN BEGIN
      AForm.Position := poScreenCenter;
      AForm.Width := DEFAULT_WINDOW_WIDTH;
      AForm.Height := DEFAULT_WINDOW_HEIGHT;
      AForm.WindowState := wsNormal;
    END;
    FIsLoaded := True;
    Exit;
  END;
  // Charger depuis INI
  Config := TMemIniFile.Create(FConfigPath);
  TRY
    LoadWindowSettings(Config);
    LoadAppearanceSettings(Config);
    LoadOptionsSettings(Config);
    LoadStatisticsSettings(Config);
    // Appliquer position fenêtre si fournie
    IF Assigned(AForm) THEN BEGIN
      WITH FSettings.Window DO BEGIN
        IF (Top >= 0) AND (Left >= 0) AND IsPositionVisible(Left, Top, Width, Height) THEN BEGIN
          AForm.Position := poDesigned;
          AForm.Left := Left;
          AForm.Top := Top;
          AForm.Width := Width;
          AForm.Height := Height;
        END ELSE BEGIN
          AForm.Position := poScreenCenter;
          AForm.Width := Width;
          AForm.Height := Height;
        END;
        AForm.WindowState := WindowState;
      END;
    END;
    FIsLoaded := True;
    TSimpleLogger.Instance.Log('TSettingsManager', 'Paramètres chargés avec succès');
  FINALLY Config.Free;
  END;
END;

PROCEDURE TSettingsManager.LoadWindowSettings(AConfig: TMemIniFile);
BEGIN
  WITH FSettings.Window DO BEGIN
    Top := AConfig.ReadInteger(INI_SECTION_WINDOW, INI_KEY_TOP, DEFAULT_WINDOW_TOP);
    Left := AConfig.ReadInteger(INI_SECTION_WINDOW, INI_KEY_LEFT, DEFAULT_WINDOW_LEFT);
    Width := AConfig.ReadInteger(INI_SECTION_WINDOW, INI_KEY_WIDTH, DEFAULT_WINDOW_WIDTH);
    Height := AConfig.ReadInteger(INI_SECTION_WINDOW, INI_KEY_HEIGHT, DEFAULT_WINDOW_HEIGHT);
    WindowState := TWindowState(AConfig.ReadInteger(INI_SECTION_WINDOW, INI_KEY_STATE, Ord(wsNormal)));
    Maximized := AConfig.ReadBool(INI_SECTION_WINDOW, INI_KEY_MAXIMIZED, False);
    AlwaysOnTop := AConfig.ReadBool(INI_SECTION_WINDOW, INI_KEY_ALWAYS_ON_TOP, False);
  END;
END;

PROCEDURE TSettingsManager.LoadAppearanceSettings(AConfig: TMemIniFile);
BEGIN
  WITH FSettings.Appearance DO BEGIN
    StyleName := AConfig.ReadString(INI_SECTION_APPEARANCE, INI_KEY_STYLE, DEFAULT_STYLE_NAME);
    FontName := AConfig.ReadString(INI_SECTION_APPEARANCE, INI_KEY_FONT_NAME, DEFAULT_FONT_NAME);
    FontSize := AConfig.ReadInteger(INI_SECTION_APPEARANCE, INI_KEY_FONT_SIZE, DEFAULT_FONT_SIZE);
    Bold := AConfig.ReadBool(INI_SECTION_APPEARANCE, INI_KEY_FONT_BOLD, False);
    Italic := AConfig.ReadBool(INI_SECTION_APPEARANCE, INI_KEY_FONT_ITALIC, False);
    Underline := AConfig.ReadBool(INI_SECTION_APPEARANCE, INI_KEY_FONT_UNDERLINE, False);
    EdgeColor := TColor(AConfig.ReadInteger(INI_SECTION_APPEARANCE, INI_KEY_NC_COLOR, DEFAULT_NC_COLOR));
    EdgeColorEnabled := AConfig.ReadBool(INI_SECTION_APPEARANCE, INI_KEY_NC_ENABLED, False);
  END;
END;

PROCEDURE TSettingsManager.LoadOptionsSettings(AConfig: TMemIniFile);
BEGIN
  WITH FSettings.Options DO BEGIN
    ShowHints := AConfig.ReadBool(INI_SECTION_OPTIONS, INI_KEY_SHOW_HINTS, True);
    ShowStatusBar := AConfig.ReadBool(INI_SECTION_OPTIONS, INI_KEY_SHOW_STATUSBAR, True);
  END;
END;

PROCEDURE TSettingsManager.LoadStatisticsSettings(AConfig: TMemIniFile);
BEGIN
  WITH FSettings.Statistics DO BEGIN
    AccessCount := AConfig.ReadInteger(INI_SECTION_STATISTICS, INI_KEY_ACCESS_COUNT, 0);
    LastAccessDate := AConfig.ReadDateTime(INI_SECTION_STATISTICS, INI_KEY_LAST_ACCESS, Now);
    TotalRunTime := AConfig.ReadInteger(INI_SECTION_STATISTICS, INI_KEY_TOTAL_RUNTIME, 0);
    FirstUse := AConfig.ReadDateTime(INI_SECTION_STATISTICS, INI_KEY_FIRST_USE, Now);
  END;
END;

{ ============================================================================== }
{ SAUVEGARDE PARAMÈTRES }
{ ============================================================================== }
PROCEDURE TSettingsManager.SaveSettings;
BEGIN
  SaveSettings(Application.MainForm);
END;

PROCEDURE TSettingsManager.SaveSettings(AForm: TForm);
VAR Config: TMemIniFile;
BEGIN
  Config := TMemIniFile.Create(FConfigPath);
  TRY
    SaveWindowSettings(Config, AForm);
    SaveAppearanceSettings(Config);
    SaveOptionsSettings(Config);
    SaveStatisticsSettings(Config);
    Config.UpdateFile;
    TSimpleLogger.Instance.Log('TSettingsManager', 'Paramètres sauvegardés');
  FINALLY Config.Free;
  END;
END;

PROCEDURE TSettingsManager.SaveWindowSettings(AConfig: TMemIniFile; AForm: TForm);
BEGIN
  AConfig.WriteInteger(INI_SECTION_WINDOW, INI_KEY_STATE, Ord(FSettings.Window.WindowState));
  AConfig.WriteBool(INI_SECTION_WINDOW, INI_KEY_MAXIMIZED, FSettings.Window.Maximized);
  AConfig.WriteBool(INI_SECTION_WINDOW, INI_KEY_ALWAYS_ON_TOP, FSettings.Window.AlwaysOnTop);
  // Sauvegarder position actuelle si fenêtre normale
  IF Assigned(AForm) AND (AForm.WindowState = wsNormal) THEN BEGIN
    AConfig.WriteInteger(INI_SECTION_WINDOW, INI_KEY_TOP, AForm.Top);
    AConfig.WriteInteger(INI_SECTION_WINDOW, INI_KEY_LEFT, AForm.Left);
    AConfig.WriteInteger(INI_SECTION_WINDOW, INI_KEY_WIDTH, AForm.Width);
    AConfig.WriteInteger(INI_SECTION_WINDOW, INI_KEY_HEIGHT, AForm.Height);
  END ELSE BEGIN
    AConfig.WriteInteger(INI_SECTION_WINDOW, INI_KEY_TOP, FSettings.Window.Top);
    AConfig.WriteInteger(INI_SECTION_WINDOW, INI_KEY_LEFT, FSettings.Window.Left);
    AConfig.WriteInteger(INI_SECTION_WINDOW, INI_KEY_WIDTH, FSettings.Window.Width);
    AConfig.WriteInteger(INI_SECTION_WINDOW, INI_KEY_HEIGHT, FSettings.Window.Height);
  END;
END;

PROCEDURE TSettingsManager.SaveAppearanceSettings(AConfig: TMemIniFile);
BEGIN
  WITH FSettings.Appearance DO BEGIN
    AConfig.WriteString(INI_SECTION_APPEARANCE, INI_KEY_STYLE, StyleName);
    AConfig.WriteString(INI_SECTION_APPEARANCE, INI_KEY_FONT_NAME, FontName);
    AConfig.WriteInteger(INI_SECTION_APPEARANCE, INI_KEY_FONT_SIZE, FontSize);
    AConfig.WriteBool(INI_SECTION_APPEARANCE, INI_KEY_FONT_BOLD, Bold);
    AConfig.WriteBool(INI_SECTION_APPEARANCE, INI_KEY_FONT_ITALIC, Italic);
    AConfig.WriteBool(INI_SECTION_APPEARANCE, INI_KEY_FONT_UNDERLINE, Underline);
    AConfig.WriteInteger(INI_SECTION_APPEARANCE, INI_KEY_NC_COLOR, Integer(EdgeColor));
    AConfig.WriteBool(INI_SECTION_APPEARANCE, INI_KEY_NC_ENABLED, EdgeColorEnabled);
  END;
END;

PROCEDURE TSettingsManager.SaveOptionsSettings(AConfig: TMemIniFile);
BEGIN
  WITH FSettings.Options DO BEGIN
    AConfig.WriteBool(INI_SECTION_OPTIONS, INI_KEY_SHOW_HINTS, ShowHints);
    AConfig.WriteBool(INI_SECTION_OPTIONS, INI_KEY_SHOW_STATUSBAR, ShowStatusBar);
  END;
END;

PROCEDURE TSettingsManager.SaveStatisticsSettings(AConfig: TMemIniFile);
VAR SessionTime, TotalRunTime: Integer;
BEGIN
  // Incrémenter compteur accès
  Inc(FSettings.Statistics.AccessCount);
  FSettings.Statistics.LastAccessDate := Now;
  // Calculer temps session
  SessionTime := SecondsBetween(Now, FStartTime);
  TotalRunTime := FSettings.Statistics.TotalRunTime + SessionTime;
  FSettings.Statistics.TotalRunTime := TotalRunTime;
  WITH FSettings.Statistics DO BEGIN
    AConfig.WriteInteger(INI_SECTION_STATISTICS, INI_KEY_ACCESS_COUNT, AccessCount);
    AConfig.WriteDateTime(INI_SECTION_STATISTICS, INI_KEY_LAST_ACCESS, LastAccessDate);
    AConfig.WriteInteger(INI_SECTION_STATISTICS, INI_KEY_TOTAL_RUNTIME, TotalRunTime);
    IF NOT AConfig.ValueExists(INI_SECTION_STATISTICS, INI_KEY_FIRST_USE) THEN
        AConfig.WriteDateTime(INI_SECTION_STATISTICS, INI_KEY_FIRST_USE, Now);
  END;
END;

{ ============================================================================== }
{ V1: SAUVEGARDE/CHARGEMENT ÉTAT CONTRÔLES }
{ ============================================================================== }
PROCEDURE TSettingsManager.SaveControlState(AControl: TControl; CONST Section: STRING);
VAR Config: TMemIniFile; ControlSection: STRING;
BEGIN
  IF AControl = NIL THEN Exit;
  Config := TMemIniFile.Create(FConfigPath);
  TRY
    ControlSection := Section + '_' + AControl.Name;
    // ComboBox
    IF AControl IS TComboBox THEN BEGIN
      Config.WriteInteger(ControlSection, 'ItemIndex', TComboBox(AControl).ItemIndex);
      Config.WriteString(ControlSection, 'Text', TComboBox(AControl).Text);
    END
    // CheckBox
    ELSE IF AControl IS TCheckBox THEN Config.WriteBool(ControlSection, 'Checked', TCheckBox(AControl).Checked)
      // RadioButton
    ELSE IF AControl IS TRadioButton THEN Config.WriteBool(ControlSection, 'Checked', TRadioButton(AControl).Checked)
      // Edit
    ELSE IF AControl IS TEdit THEN Config.WriteString(ControlSection, 'Text', TEdit(AControl).Text)
      // Memo
    ELSE IF AControl IS TMemo THEN Config.WriteString(ControlSection, 'Lines', TMemo(AControl).Lines.Text)
      // ListBox
    ELSE IF AControl IS TListBox THEN Config.WriteInteger(ControlSection, 'ItemIndex', TListBox(AControl).ItemIndex)
      // TrackBar
    ELSE IF AControl IS TTrackBar THEN Config.WriteInteger(ControlSection, 'Position', TTrackBar(AControl).Position)
      // ColorBox
    ELSE IF AControl IS TColorBox THEN Config.WriteInteger(ControlSection, 'Color', TColorBox(AControl).Selected)
      // Panel
    ELSE IF AControl IS TPanel THEN BEGIN
      Config.WriteInteger(ControlSection, 'Width', AControl.Width);
      Config.WriteInteger(ControlSection, 'Height', AControl.Height);
    END
    // Ton splitter personnalisé
    ELSE IF AControl IS TdnSplitter THEN BEGIN
      Config.WriteBool(ControlSection, 'Snapped', TdnSplitter(AControl).IsSnapped);
      Config.WriteInteger(ControlSection, 'Snapped_sise', TdnSplitter(AControl).ControlSize);
    END;
    Config.UpdateFile;
  FINALLY Config.Free;
  END;
END;

PROCEDURE TSettingsManager.LoadControlState(AControl: TControl; CONST Section: STRING);
VAR Config: TMemIniFile; ControlSection: STRING;
BEGIN
  IF (AControl = NIL) OR (NOT TFile.Exists(FConfigPath)) THEN Exit;
  Config := TMemIniFile.Create(FConfigPath);
  TRY
    ControlSection := Section + '_' + AControl.Name;
    IF AControl IS TComboBox THEN BEGIN
      TComboBox(AControl).ItemIndex := Config.ReadInteger(ControlSection, 'ItemIndex', -1);
      TComboBox(AControl).Text := Config.ReadString(ControlSection, 'Text', '');
    END ELSE IF AControl IS TCheckBox THEN
        TCheckBox(AControl).Checked := Config.ReadBool(ControlSection, 'Checked', False)
    ELSE IF AControl IS TRadioButton THEN
        TRadioButton(AControl).Checked := Config.ReadBool(ControlSection, 'Checked', False)
    ELSE IF AControl IS TEdit THEN TEdit(AControl).Text := Config.ReadString(ControlSection, 'Text', '')
    ELSE IF AControl IS TMemo THEN TMemo(AControl).Lines.Text := Config.ReadString(ControlSection, 'Lines', '')
    ELSE IF AControl IS TListBox THEN
        TListBox(AControl).ItemIndex := Config.ReadInteger(ControlSection, 'ItemIndex', -1)
    ELSE IF AControl IS TTrackBar THEN TTrackBar(AControl).Position := Config.ReadInteger(ControlSection, 'Position', 0)
    ELSE IF AControl IS TColorBox THEN
        TColorBox(AControl).Selected := TColor(Config.ReadInteger(ControlSection, 'Color', 0))
    ELSE IF AControl IS TPanel THEN BEGIN
      AControl.Width := Config.ReadInteger(ControlSection, 'Width', AControl.Width);
      AControl.Height := Config.ReadInteger(ControlSection, 'Height', AControl.Height);
    END ELSE IF AControl IS TdnSplitter THEN BEGIN
      TdnSplitter(AControl).IsSnapped := Config.ReadBool(ControlSection, INI_KEY_SNAPPED, False);
      TdnSplitter(AControl).ControlSize := Config.ReadInteger(ControlSection, INI_KEY_SNAPPED_SIZE,
        TdnSplitter(AControl).ControlSize);
    END;

  FINALLY Config.Free;
  END;
END;

{ ============================================================================== }
{ APPLICATION PARAMÈTRES (V2 Optimisé) }
{ ============================================================================== }
PROCEDURE TSettingsManager.ApplyAll(AForm: TForm);
BEGIN
  IF NOT Assigned(AForm) THEN Exit;
  TSimpleLogger.Instance.Log('TSettingsManager', '=== DÉBUT ApplyAll ===');
  AForm.DisableAlign;
  IF AForm.HandleAllocated THEN SendMessage(AForm.Handle, WM_SETREDRAW, 0, 0);
  TRY
    ApplyAppearance(AForm); // Style + EdgeColor
    ApplyFont(AForm); // Police
    ApplyOptions(AForm); // Hints, StatusBar, AlwaysOnTop
  FINALLY
    IF AForm.HandleAllocated THEN BEGIN
      SendMessage(AForm.Handle, WM_SETREDRAW, 1, 0);
      RedrawWindow(AForm.Handle, NIL, 0, RDW_ERASE OR RDW_FRAME OR RDW_INVALIDATE OR RDW_ALLCHILDREN);
    END;
    AForm.EnableAlign;
  END;
  TSimpleLogger.Instance.Log('TSettingsManager', '=== FIN ApplyAll ===');
END;

PROCEDURE TSettingsManager.ApplyWindow(AForm: TForm);
BEGIN
  // Position déjà appliquée dans LoadSettings
END;

PROCEDURE TSettingsManager.ApplyAppearance(AForm: TForm);
VAR CurrentStyleName: STRING; NeedStyleChange: Boolean;
BEGIN
  // Style
  IF Assigned(TStyleManager.ActiveStyle) THEN CurrentStyleName := TStyleManager.ActiveStyle.Name
  ELSE CurrentStyleName := '';

  // ? CORRECTION CRITIQUE: Vérifier si changement nécessaire
  NeedStyleChange := (FSettings.Appearance.StyleName <> '') AND
    (NOT SameText(FSettings.Appearance.StyleName, CurrentStyleName));

  IF NeedStyleChange THEN BEGIN
    TSimpleLogger.Instance.Log('TSettingsManager', Format('Changement style: %s ? %s',
      [CurrentStyleName, FSettings.Appearance.StyleName]));

    // ? CORRECTION: Ne pas crasher si le style n'existe pas
    TRY
      // IF TStyleMgr.GetInstance.ApplyStyle(FSettings.Appearance.StyleName) THEN
      TStyleManager.SetStyle(FSettings.Appearance.StyleName);

      // EdgeColor
      TStyleMgr.GetInstance.SetNCColor(AForm, FSettings.Appearance.EdgeColor, FSettings.Appearance.EdgeColorEnabled);
    EXCEPT
      ON E: Exception DO TSimpleLogger.Instance.LogError('Exception ApplyStyle: ' + E.Message);

    END;
    BEGIN
      TSimpleLogger.Instance.LogDebug('TSettingsManager', Format('Style inchangé: %s', [CurrentStyleName]));
    END;

  END;
END;

PROCEDURE TSettingsManager.ApplyFont(AForm: TForm);
VAR Cfg: TFontConfig;
BEGIN
  Cfg.Name := FSettings.Appearance.FontName;
  Cfg.Size := FSettings.Appearance.FontSize;
  Cfg.Bold := FSettings.Appearance.Bold;
  Cfg.Italic := FSettings.Appearance.Italic;
  Cfg.Underline := FSettings.Appearance.Underline;
  Cfg.ParentFont := False;
  TFontManager.ApplyToForm(AForm, Cfg);
END;

PROCEDURE TSettingsManager.ApplyOptions(AForm: TForm);
VAR SB: TComponent;
BEGIN
  Application.ShowHint := FSettings.Options.ShowHints;
  IF FSettings.Window.AlwaysOnTop THEN AForm.FormStyle := fsStayOnTop
  ELSE AForm.FormStyle := fsNormal;
  SB := AForm.FindComponent('StatusBar');
  IF Assigned(SB) AND (SB IS TStatusBar) THEN TStatusBar(SB).Visible := FSettings.Options.ShowStatusBar;
END;

{ ============================================================================== }
{ STATISTIQUES }
{ ============================================================================== }
PROCEDURE TSettingsManager.UpdateStats;
BEGIN
  Inc(FSettings.Statistics.AccessCount);
  FSettings.Statistics.LastAccessDate := Now;
  SaveSettings;
END;

{ ============================================================================== }
{ GETTERS/SETTERS INDIVIDUELS (V1 Compatible) }
{ ============================================================================== }
FUNCTION TSettingsManager.GetAccessCount: Integer;
BEGIN
  Result := FSettings.Statistics.AccessCount;
END;

FUNCTION TSettingsManager.GetLastAccessDate: TDateTime;
BEGIN
  Result := FSettings.Statistics.LastAccessDate;
END;

FUNCTION TSettingsManager.GetTotalRunTime: Integer;
BEGIN
  Result := FSettings.Statistics.TotalRunTime;
END;

FUNCTION TSettingsManager.GetIsLoaded: Boolean;
BEGIN
  Result := FIsLoaded;
END;

PROCEDURE TSettingsManager.SetStyleName(CONST AStyle: STRING);
BEGIN
  FSettings.Appearance.StyleName := AStyle;
END;

PROCEDURE TSettingsManager.SetFontSettings(CONST AFontName: STRING; AFontSize: Integer);
BEGIN
  FSettings.Appearance.FontName := AFontName;
  FSettings.Appearance.FontSize := AFontSize;
END;

PROCEDURE TSettingsManager.SetFontStyle(ABold, AItalic, AUnderline: Boolean);
BEGIN
  FSettings.Appearance.Bold := ABold;
  FSettings.Appearance.Italic := AItalic;
  FSettings.Appearance.Underline := AUnderline;
END;

PROCEDURE TSettingsManager.SetNCColor(AColor: TColor);
BEGIN
  FSettings.Appearance.EdgeColor := AColor;
END;

PROCEDURE TSettingsManager.SetNCColorEnabled(AEnabled: Boolean);
BEGIN
  FSettings.Appearance.EdgeColorEnabled := AEnabled;
END;

PROCEDURE TSettingsManager.SetEdgeColor(AColor: TColor);
BEGIN
  FSettings.Appearance.EdgeColor := AColor;
END;

PROCEDURE TSettingsManager.SetEdgeColorEnabled(AEnabled: Boolean);
BEGIN
  FSettings.Appearance.EdgeColorEnabled := AEnabled;
END;

PROCEDURE TSettingsManager.SetShowHints(AEnabled: Boolean);
BEGIN
  FSettings.Options.ShowHints := AEnabled;
END;

PROCEDURE TSettingsManager.SetShowStatusBar(AEnabled: Boolean);
BEGIN
  FSettings.Options.ShowStatusBar := AEnabled;
END;

PROCEDURE TSettingsManager.SetAlwaysOnTop(AEnabled: Boolean);
BEGIN
  FSettings.Window.AlwaysOnTop := AEnabled;
END;

PROCEDURE TSettingsManager.SetWindowSize(AWidth, AHeight: Integer);
BEGIN
  FSettings.Window.Width := AWidth;
  FSettings.Window.Height := AHeight;
END;

END.
