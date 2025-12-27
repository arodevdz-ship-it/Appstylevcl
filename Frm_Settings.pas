UNIT Frm_Settings;

{ ****************************************************************************** }
{ * FORMULAIRE PARAMÈTRES - VERSION MASTER                                    * }
{ * Fusion V1 (Surveillance Presets) + V3 (Preview + Summary)                 * }
{ ****************************************************************************** }

INTERFACE

USES System.SysUtils, System.Classes, System.UITypes, System.Types, System.IOUtils, Winapi.Windows, Winapi.ShellAPI,
  Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Graphics, Vcl.Themes, Vcl.Styles, Vcl.Controls,
  uConstants, uSettingsManager, uStyleManager, uFontManager, uPresetManager, uSimpleLogger;

TYPE
  TFrmSettings = CLASS(TForm)
    PageControl1: TPageControl;
    TabAppearance: TTabSheet;
    TabOptions: TTabSheet;
    TabPresets: TTabSheet;
    TabSystem: TTabSheet;

    // Apparence
    GroupBox3: TGroupBox;
    CbxStyles: TComboBox;
    ImgPreview: TImage;
    LblStylesLoaded: TLabel;
    BtnReloadStyles: TButton;
    BtnDiagnoseStyles: TButton;

    GroupBox2: TGroupBox;
    LblFontPreview: TLabel;
    BtnChangeFont: TButton;
    BtnResetFont: TButton;

    GbxNCColor: TGroupBox;
    ChkNCEnabled: TCheckBox;
    BtnChooseColor: TButton;
    Shape2: TShape;

    // Options
    ChkShowHints: TCheckBox;
    ChkShowStatusBar: TCheckBox;
    ChkAlwaysOnTop: TCheckBox;
    BtnResetPosition: TButton;
    BtnResetSize: TButton;
    BtnResetAll: TButton;

    // Presets
    GroupBox1: TGroupBox;
    CbxPresets: TComboBox;
    BtnApplyPreset: TButton;
    BtnEnregistrerPresets: TButton;
    BtnDeletePreset: TButton;
    BtnOpenPresetNotepad: TButton;
    BtnOpenPresetDefault: TButton;
    BtnReloadPresets: TButton;
    BtnPresetInfo: TButton;
    MemoSummary: TMemo;

    // Système
    MemoPaths: TMemo;
    BtnOpenAppData: TButton;

    // Boutons
    Pna_Setting: TPanel;
    BtnOK: TButton;
    BtnCancel: TButton;

    // Dialogues
    FontDialog1: TFontDialog;
    ColorDialog1: TColorDialog;

    // Timer V1
    TimerPresetWatch: TTimer;

    PROCEDURE FormCreate(Sender: TObject);
    PROCEDURE FormShow(Sender: TObject);
    PROCEDURE FormClose(Sender: TObject; VAR Action: TCloseAction);

    // Apparence
    PROCEDURE CbxStylesChange(Sender: TObject);
    PROCEDURE BtnChangeFontClick(Sender: TObject);
    PROCEDURE BtnResetFontClick(Sender: TObject);
    PROCEDURE BtnChooseColorClick(Sender: TObject);
    PROCEDURE ChkNCEnabledClick(Sender: TObject);
    PROCEDURE BtnReloadStylesClick(Sender: TObject);
    PROCEDURE BtnDiagnoseStylesClick(Sender: TObject);

    // Options
    PROCEDURE ChkShowHintsClick(Sender: TObject);
    PROCEDURE ChkShowStatusBarClick(Sender: TObject);
    PROCEDURE ChkAlwaysOnTopClick(Sender: TObject);
    PROCEDURE BtnResetPositionClick(Sender: TObject);
    PROCEDURE BtnResetSizeClick(Sender: TObject);
    PROCEDURE BtnResetAllClick(Sender: TObject);

    // Presets
    PROCEDURE BtnApplyPresetClick(Sender: TObject);
    PROCEDURE BtnSavePresetClick(Sender: TObject);
    PROCEDURE BtnDeletePresetClick(Sender: TObject);
    PROCEDURE BtnOpenPresetNotepadClick(Sender: TObject);
    PROCEDURE BtnOpenPresetDefaultClick(Sender: TObject);
    PROCEDURE BtnReloadPresetsClick(Sender: TObject);
    PROCEDURE BtnPresetInfoClick(Sender: TObject);
    PROCEDURE TimerPresetWatchTimer(Sender: TObject);

    // Système
    PROCEDURE BtnOpenAppDataClick(Sender: TObject);

    // Validation
    PROCEDURE BtnOKClick(Sender: TObject);
    PROCEDURE BtnCancelClick(Sender: TObject);

  PRIVATE
    FTempSettings:    TApplicationSettings;
    FLastPresetStamp: TDateTime;

    PROCEDURE LoadSettingsToUI;
    PROCEDURE UpdateFontLabel;
    PROCEDURE UpdatePresetSummary; // V3
    PROCEDURE RefreshPresets;
    PROCEDURE LoadSystemInfo;
    PROCEDURE OpenInNotepad(CONST AFileName: STRING);
  END;

VAR FrmSettings: TFrmSettings;

IMPLEMENTATION

{$R *.dfm}
{ ============================================================================== }
{ INITIALISATION }
{ ============================================================================== }

PROCEDURE TFrmSettings.FormCreate(Sender: TObject);
BEGIN
  TSimpleLogger.Instance.Log('TFrmSettings', 'FormCreate');

  // Charger styles dans ComboBox
  TStyleMgr.GetInstance.PopulateComboBox(CbxStyles);
  LblStylesLoaded.Caption := Format('Styles chargés: %d', [Length(TStyleManager.StyleNames)]);

  PageControl1.ActivePageIndex := 0;
END;

PROCEDURE TFrmSettings.FormShow(Sender: TObject);
BEGIN
  TSimpleLogger.Instance.Log('TFrmSettings', 'FormShow');

  // Copier paramètres actuels vers temporaires
  FTempSettings := TSettingsManager.GetInstance.Settings;

  LoadSettingsToUI;
  LoadSystemInfo;
  RefreshPresets;

  // V1: Démarrer surveillance presets
  FLastPresetStamp := TPresetManager.GetInstance.GetFileTimestamp;
  TimerPresetWatch.Enabled := True;
END;

PROCEDURE TFrmSettings.FormClose(Sender: TObject; VAR Action: TCloseAction);
BEGIN
  TimerPresetWatch.Enabled := False;
END;

PROCEDURE TFrmSettings.LoadSettingsToUI;
BEGIN
  // Style
  CbxStyles.ItemIndex := CbxStyles.Items.IndexOf(FTempSettings.Appearance.StyleName);
  IF CbxStyles.ItemIndex = -1 THEN CbxStyles.ItemIndex := 0;

  // Police
  UpdateFontLabel;

  // EdgeColor
  Shape2.Brush.Color := FTempSettings.Appearance.EdgeColor;
  ChkNCEnabled.Checked := FTempSettings.Appearance.EdgeColorEnabled;

  // Options
  ChkShowHints.Checked := FTempSettings.Options.ShowHints;
  ChkShowStatusBar.Checked := FTempSettings.Options.ShowStatusBar;
  ChkAlwaysOnTop.Checked := FTempSettings.Window.AlwaysOnTop;

  // Trigger preview
  CbxStylesChange(NIL);
END;

{ ============================================================================== }
{ APPARENCE }
{ ============================================================================== }

PROCEDURE TFrmSettings.CbxStylesChange(Sender: TObject);
BEGIN
  FTempSettings.Appearance.StyleName := CbxStyles.Text;

  // V3: Render Preview
  TStyleMgr.GetInstance.RenderPreview(FTempSettings.Appearance.StyleName, ImgPreview.Canvas, ImgPreview.ClientRect);
  ImgPreview.Invalidate;

  UpdatePresetSummary;
END;

PROCEDURE TFrmSettings.BtnChangeFontClick(Sender: TObject);
BEGIN
  // Préparer dialogue
  FontDialog1.Font.Name := FTempSettings.Appearance.FontName;
  FontDialog1.Font.Size := FTempSettings.Appearance.FontSize;
  FontDialog1.Font.Style := [];

  IF FTempSettings.Appearance.Bold THEN FontDialog1.Font.Style := FontDialog1.Font.Style + [fsBold];
  IF FTempSettings.Appearance.Italic THEN FontDialog1.Font.Style := FontDialog1.Font.Style + [fsItalic];
  IF FTempSettings.Appearance.Underline THEN FontDialog1.Font.Style := FontDialog1.Font.Style + [fsUnderline];

  IF FontDialog1.Execute THEN BEGIN
    FTempSettings.Appearance.FontName := FontDialog1.Font.Name;
    FTempSettings.Appearance.FontSize := FontDialog1.Font.Size;
    FTempSettings.Appearance.Bold := fsBold IN FontDialog1.Font.Style;
    FTempSettings.Appearance.Italic := fsItalic IN FontDialog1.Font.Style;
    FTempSettings.Appearance.Underline := fsUnderline IN FontDialog1.Font.Style;

    UpdateFontLabel;
    UpdatePresetSummary;
  END;
END;

PROCEDURE TFrmSettings.BtnResetFontClick(Sender: TObject);
BEGIN
  FTempSettings.Appearance.FontName := DEFAULT_FONT_NAME;
  FTempSettings.Appearance.FontSize := DEFAULT_FONT_SIZE;
  FTempSettings.Appearance.Bold := False;
  FTempSettings.Appearance.Italic := False;
  FTempSettings.Appearance.Underline := False;

  UpdateFontLabel;
  UpdatePresetSummary;
END;

PROCEDURE TFrmSettings.UpdateFontLabel;
VAR StyleStr: STRING;
BEGIN
  StyleStr := 'Normal';
  IF FTempSettings.Appearance.Bold OR FTempSettings.Appearance.Italic OR FTempSettings.Appearance.Underline THEN BEGIN
    StyleStr := '';
    IF FTempSettings.Appearance.Bold THEN StyleStr := StyleStr + 'Gras ';
    IF FTempSettings.Appearance.Italic THEN StyleStr := StyleStr + 'Italique ';
    IF FTempSettings.Appearance.Underline THEN StyleStr := StyleStr + 'Souligné ';
    StyleStr := Trim(StyleStr);
  END;

  LblFontPreview.Caption := Format('%s — %d pt — %s', [FTempSettings.Appearance.FontName,
    FTempSettings.Appearance.FontSize, StyleStr]);
END;

PROCEDURE TFrmSettings.BtnChooseColorClick(Sender: TObject);
BEGIN
  ColorDialog1.Color := FTempSettings.Appearance.EdgeColor;

  IF ColorDialog1.Execute THEN BEGIN
    FTempSettings.Appearance.EdgeColor := ColorDialog1.Color;
    FTempSettings.Appearance.EdgeColorEnabled := True;
    Shape2.Brush.Color := ColorDialog1.Color;
    ChkNCEnabled.Checked := True;
    UpdatePresetSummary;
  END;
END;

PROCEDURE TFrmSettings.ChkNCEnabledClick(Sender: TObject);
BEGIN
  FTempSettings.Appearance.EdgeColorEnabled := ChkNCEnabled.Checked;

  IF NOT ChkNCEnabled.Checked THEN Shape2.Brush.Color := clBtnFace
  ELSE Shape2.Brush.Color := FTempSettings.Appearance.EdgeColor;

  UpdatePresetSummary;
END;

PROCEDURE TFrmSettings.BtnReloadStylesClick(Sender: TObject);
BEGIN
  TStyleMgr.GetInstance.LoadStyleFiles;
  TStyleMgr.GetInstance.PopulateComboBox(CbxStyles);
  LblStylesLoaded.Caption := Format('Styles chargés: %d', [Length(TStyleManager.StyleNames)]);
END;

PROCEDURE TFrmSettings.BtnDiagnoseStylesClick(Sender: TObject);
BEGIN
  TStyleMgr.GetInstance.DiagnoseStyles;
  OpenInNotepad(TPath.Combine(GetAppPath, 'StylesDiagnostic.txt'));
END;

{ ============================================================================== }
{ OPTIONS }
{ ============================================================================== }

PROCEDURE TFrmSettings.ChkShowHintsClick(Sender: TObject);
BEGIN
  FTempSettings.Options.ShowHints := ChkShowHints.Checked;
  UpdatePresetSummary;
END;

PROCEDURE TFrmSettings.ChkShowStatusBarClick(Sender: TObject);
BEGIN
  FTempSettings.Options.ShowStatusBar := ChkShowStatusBar.Checked;
  UpdatePresetSummary;
END;

PROCEDURE TFrmSettings.ChkAlwaysOnTopClick(Sender: TObject);
BEGIN
  FTempSettings.Window.AlwaysOnTop := ChkAlwaysOnTop.Checked;
  UpdatePresetSummary;
END;

PROCEDURE TFrmSettings.BtnResetPositionClick(Sender: TObject);
BEGIN
  FTempSettings.Window.Left := DEFAULT_WINDOW_LEFT;
  FTempSettings.Window.Top := DEFAULT_WINDOW_TOP;
  ShowMessage('Position réinitialisée (appliqué au prochain démarrage)');
END;

PROCEDURE TFrmSettings.BtnResetSizeClick(Sender: TObject);
BEGIN
  FTempSettings.Window.Width := DEFAULT_WINDOW_WIDTH;
  FTempSettings.Window.Height := DEFAULT_WINDOW_HEIGHT;
  ShowMessage('Taille réinitialisée (appliqué au prochain démarrage)');
END;

PROCEDURE TFrmSettings.BtnResetAllClick(Sender: TObject);
BEGIN
  IF MessageDlg('Réinitialiser TOUS les paramètres ?', mtConfirmation, [mbYes, mbNo], 0) = mrYes THEN BEGIN
    FTempSettings.ResetToDefaults;
    LoadSettingsToUI;
    ShowMessage('Paramètres réinitialisés');
  END;
END;

{ ============================================================================== }
{ PRESETS (V1 Surveillance + V3 Summary) }
{ ============================================================================== }

PROCEDURE TFrmSettings.RefreshPresets;
BEGIN
  CbxPresets.Items.Clear;
  CbxPresets.Items.AddStrings(TPresetManager.GetInstance.GetPresetNames);
END;

PROCEDURE TFrmSettings.BtnApplyPresetClick(Sender: TObject);
VAR LPreset: TPreset;
BEGIN
  IF CbxPresets.ItemIndex = -1 THEN Exit;

  IF TPresetManager.GetInstance.GetPreset(CbxPresets.Text, LPreset) THEN BEGIN
    FTempSettings.Appearance.StyleName := LPreset.StyleName;
    FTempSettings.Appearance.FontName := LPreset.FontName;
    FTempSettings.Appearance.FontSize := LPreset.FontSize;
    FTempSettings.Appearance.Bold := LPreset.Bold;
    FTempSettings.Appearance.Italic := LPreset.Italic;
    FTempSettings.Appearance.Underline := LPreset.Underline;
    FTempSettings.Appearance.EdgeColor := LPreset.EdgeColor;
    FTempSettings.Appearance.EdgeColorEnabled := LPreset.EdgeColorEnabled;

    LoadSettingsToUI;
    TSimpleLogger.Instance.Log('TFrmSettings', 'Preset appliqué: ' + CbxPresets.Text);
  END;
END;

PROCEDURE TFrmSettings.BtnSavePresetClick(Sender: TObject);
VAR LName: STRING; LPreset: TPreset;
BEGIN
  LName := InputBox('Nouveau Preset', 'Nom du preset:', '');
  IF Trim(LName) = '' THEN Exit;

  LPreset.StyleName := FTempSettings.Appearance.StyleName;
  LPreset.FontName := FTempSettings.Appearance.FontName;
  LPreset.FontSize := FTempSettings.Appearance.FontSize;
  LPreset.Bold := FTempSettings.Appearance.Bold;
  LPreset.Italic := FTempSettings.Appearance.Italic;
  LPreset.Underline := FTempSettings.Appearance.Underline;
  LPreset.EdgeColor := FTempSettings.Appearance.EdgeColor;
  LPreset.EdgeColorEnabled := FTempSettings.Appearance.EdgeColorEnabled;

  TPresetManager.GetInstance.AddPreset(LName, LPreset);
  RefreshPresets;

  ShowMessage('Preset enregistré: ' + LName);
END;

PROCEDURE TFrmSettings.BtnDeletePresetClick(Sender: TObject);
BEGIN
  IF CbxPresets.ItemIndex = -1 THEN Exit;

  IF MessageDlg('Supprimer le preset "' + CbxPresets.Text + '" ?', mtConfirmation, [mbYes, mbNo], 0) = mrYes THEN BEGIN
    TPresetManager.GetInstance.RemovePreset(CbxPresets.Text);
    RefreshPresets;
  END;
END;

PROCEDURE TFrmSettings.BtnOpenPresetNotepadClick(Sender: TObject);
BEGIN
  OpenInNotepad(GetPresetFileName);
END;

PROCEDURE TFrmSettings.BtnOpenPresetDefaultClick(Sender: TObject);
BEGIN
  ShellExecute(0, 'open', PChar(GetPresetFileName), NIL, NIL, SW_SHOWNORMAL);
END;

PROCEDURE TFrmSettings.BtnReloadPresetsClick(Sender: TObject);
BEGIN
  TPresetManager.GetInstance.LoadFromFile;
  RefreshPresets;
END;

PROCEDURE TFrmSettings.BtnPresetInfoClick(Sender: TObject);
VAR Stamp: TDateTime;
BEGIN
  Stamp := TPresetManager.GetInstance.GetFileTimestamp;
  ShowMessage('Dernière modification: ' + DateTimeToStr(Stamp));
END;

PROCEDURE TFrmSettings.TimerPresetWatchTimer(Sender: TObject);
BEGIN
  IF TPresetManager.GetInstance.HasFileChanged THEN BEGIN
    TSimpleLogger.Instance.Log('TFrmSettings', 'Fichier presets modifié - rechargement');
    TPresetManager.GetInstance.LoadFromFile;
    TPresetManager.GetInstance.UpdateTimestamp;
    RefreshPresets;
  END;
END;

{ ============================================================================== }
{ V3: SUMMARY PREVIEW }
{ ============================================================================== }

PROCEDURE TFrmSettings.UpdatePresetSummary;
VAR StyleStr: STRING;
BEGIN
  StyleStr := 'Normal';
  IF FTempSettings.Appearance.Bold OR FTempSettings.Appearance.Italic OR FTempSettings.Appearance.Underline THEN BEGIN
    StyleStr := '';
    IF FTempSettings.Appearance.Bold THEN StyleStr := StyleStr + '[Gras] ';
    IF FTempSettings.Appearance.Italic THEN StyleStr := StyleStr + '[Italique] ';
    IF FTempSettings.Appearance.Underline THEN StyleStr := StyleStr + '[Souligné] ';
  END;

  MemoSummary.Clear;
  MemoSummary.Lines.Add('***** CONFIGURATION À ENREGISTRER *****');
  MemoSummary.Lines.Add(Format('  THÈME   : %s', [FTempSettings.Appearance.StyleName]));
  MemoSummary.Lines.Add(Format('  POLICE  : %s', [FTempSettings.Appearance.FontName]));
  MemoSummary.Lines.Add(Format('  TAILLE  : %d pt', [FTempSettings.Appearance.FontSize]));
  MemoSummary.Lines.Add(Format('  STYLES  : %s', [StyleStr]));

  IF ChkNCEnabled.Checked THEN
      MemoSummary.Lines.Add(Format('  BORDURE : %s (Activée)', [ColorToString(FTempSettings.Appearance.EdgeColor)]))
  ELSE MemoSummary.Lines.Add('  BORDURE : Standard Windows');

  MemoSummary.Lines.Add('***************************************');
END;

{ ============================================================================== }
{ SYSTÈME }
{ ============================================================================== }

PROCEDURE TFrmSettings.LoadSystemInfo;
VAR CompName: ARRAY [0 .. MAX_COMPUTERNAME_LENGTH] OF Char; Size: Cardinal;
BEGIN
  Size := MAX_COMPUTERNAME_LENGTH + 1;
  GetComputerName(CompName, Size);

  MemoPaths.Clear;
  MemoPaths.Lines.Add('=== INFORMATIONS SYSTÈME ===');
  MemoPaths.Lines.Add('Ordinateur: ' + StrPas(CompName));
  MemoPaths.Lines.Add('Application: ' + APP_NAME + ' v' + APP_VERSION);
  MemoPaths.Lines.Add('');
  MemoPaths.Lines.Add('=== DOSSIERS ===');
  MemoPaths.Lines.Add('EXE:      ' + GetAppPath);
  MemoPaths.Lines.Add('CONFIG:   ' + GetConfigDirectory);
  MemoPaths.Lines.Add('STYLES:   ' + GetStylesDirectory);
  MemoPaths.Lines.Add('PRESETS:  ' + GetPresetsDirectory);
  MemoPaths.Lines.Add('LOGS:     ' + GetLogsDirectory);
  MemoPaths.Lines.Add('');
  MemoPaths.Lines.Add('=== FICHIERS ===');
  MemoPaths.Lines.Add('Config:   ' + ExtractFileName(GetConfigFilePath));
  MemoPaths.Lines.Add('Presets:  ' + FILE_PRESETS);
  MemoPaths.Lines.Add('Log:      ' + FILE_LOG);
END;

PROCEDURE TFrmSettings.BtnOpenAppDataClick(Sender: TObject);
BEGIN
  ShellExecute(0, 'open', PChar(GetConfigDirectory), NIL, NIL, SW_SHOWNORMAL);
END;

PROCEDURE TFrmSettings.OpenInNotepad(CONST AFileName: STRING);
BEGIN
  IF FileExists(AFileName) THEN ShellExecute(0, 'open', 'notepad.exe', PChar(AFileName), NIL, SW_SHOWNORMAL)
  ELSE ShowMessage('Fichier introuvable: ' + AFileName);
END;

{ ============================================================================== }
{ VALIDATION }
{ ============================================================================== }

PROCEDURE TFrmSettings.BtnOKClick(Sender: TObject);
VAR LMain: TForm;
BEGIN
  TSimpleLogger.Instance.Log('TFrmSettings', 'Validation et sauvegarde');

  LMain := Application.MainForm;

  // Capturer position actuelle fenêtre principale
  IF Assigned(LMain) THEN BEGIN
    FTempSettings.Window.Maximized := (LMain.WindowState = wsMaximized);
    IF NOT FTempSettings.Window.Maximized THEN BEGIN
      FTempSettings.Window.Left := LMain.Left;
      FTempSettings.Window.Top := LMain.Top;
      FTempSettings.Window.Width := LMain.Width;
      FTempSettings.Window.Height := LMain.Height;
    END;
    FTempSettings.Window.WindowState := LMain.WindowState;
  END;

  // Appliquer
  TSettingsManager.Settings := FTempSettings;
  TSettingsManager.GetInstance.SaveSettings;
  TSettingsManager.GetInstance.ApplyAll(LMain);

  ModalResult := mrOk;
END;

PROCEDURE TFrmSettings.BtnCancelClick(Sender: TObject);
BEGIN
  TSimpleLogger.Instance.Log('TFrmSettings', 'Annulation');
  ModalResult := mrCancel;
END;

END.
