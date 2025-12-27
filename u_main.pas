UNIT u_Main;

{ ****************************************************************************** }
{ * FORMULAIRE PRINCIPAL - VERSION MASTER                                     * }
{ * Fusion V1/V2/V3 - Gestion complète du cycle de vie                        * }
{ ****************************************************************************** }

INTERFACE

USES Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.Themes, Vcl.Styles, Vcl.Styles.FormStyleHooks,
  Vcl.Styles.Utils.SystemMenu, uConstants, uSettingsManager, uStyleManager, uFontManager, uPresetManager, uSimpleLogger,
  Frm_Settings, dnSplitter;

TYPE
  TMainForm = CLASS(TForm)
    StatusBar: TStatusBar;
    Label1: TLabel;
    Edit1: TEdit;
    Panel1: TPanel;
    dnSplitter1: TdnSplitter;
    Button1: TButton;
    BtnSettings: TButton;
    PROCEDURE FormCreate(Sender: TObject);
    PROCEDURE FormShow(Sender: TObject);
    PROCEDURE FormCloseQuery(Sender: TObject; VAR CanClose: Boolean);
    PROCEDURE FormClose(Sender: TObject; VAR Action: TCloseAction);
    PROCEDURE BtnSettingsClick(Sender: TObject);
    PROCEDURE Button1Click(Sender: TObject);
  PRIVATE
    { Déclarations privées }
    FInitialized: Boolean;
    PROCEDURE InitializeManagers;
    PROCEDURE LoadApplicationSettings;
    PROCEDURE SaveApplicationSettings;
  PUBLIC
    { Déclarations publiques }
  PROTECTED
    PROCEDURE WMApplySettings(VAR Msg: TMessage); MESSAGE WM_APPLY_SETTINGS;
  END;

VAR MainForm: TMainForm;

IMPLEMENTATION

{$R *.dfm}

PROCEDURE TMainForm.BtnSettingsClick(Sender: TObject);

VAR Frm: TFrmSettings;
BEGIN
  TSimpleLogger.Instance.Log('TFrm_Main', 'Ouverture dialogue paramètres');
  Frm := TFrmSettings.Create(Self);
  TRY
    IF Frm.ShowModal = mrOk THEN BEGIN
      // Rafraîchir tout
      TSettingsManager.GetInstance.ApplyAll(Self);
      TSimpleLogger.Instance.Log('TFrm_Main', 'Paramètres appliqués depuis dialogue');
    END;
  FINALLY Frm.Free;
  END;
END;

PROCEDURE TMainForm.Button1Click(Sender: TObject);
BEGIN
  IF TStyleMgr.GetInstance.ApplyStyle(TStyleManager.ActiveStyle.Name) THEN
      ShowMessage('style active ' + TStyleManager.ActiveStyle.Name)
  ELSE ShowMessage('err');

END;

PROCEDURE TMainForm.FormClose(Sender: TObject; VAR Action: TCloseAction);
BEGIN
  TSimpleLogger.Instance.Log('TFrm_Main', 'FormClose - Sauvegarde paramètres');
  SaveApplicationSettings;
END;

PROCEDURE TMainForm.FormCloseQuery(Sender: TObject; VAR CanClose: Boolean);
BEGIN
  // Confirmation facultative
  // CanClose := MessageDlg('Quitter ' + APP_NAME + ' ?',
  // mtConfirmation, [mbYes, mbNo], 0) = mrYes;
  CanClose := True;
END;

PROCEDURE TMainForm.FormCreate(Sender: TObject);
VAR LVclStylesSystemMenu: TVclStylesSystemMenu;
BEGIN
  // Menu styles dans barre de titre
  LVclStylesSystemMenu := TVclStylesSystemMenu.Create(Self);
  LVclStylesSystemMenu.MenuCaption := 'Choisir un thème VCL';

  FInitialized := False;
  Caption := APP_NAME + ' v' + APP_VERSION;
  TSimpleLogger.Instance.Log('TMainForm', 'FormCreate - Début');
  InitializeManagers;
  TSimpleLogger.Instance.Log('TMainForm', 'FormCreate - Fin');

END;

PROCEDURE TMainForm.FormShow(Sender: TObject);
BEGIN
  BEGIN
    IF NOT FInitialized THEN BEGIN
      TSimpleLogger.Instance.Log('TFrm_Main', 'FormShow - Chargement paramètres');

      // ? CORRECTION CRITIQUE: Retarder l'application après FormShow
      Application.ProcessMessages; // Laisser FormShow se terminer

      TThread.CreateAnonymousThread(PROCEDURE
        BEGIN
          // Sleep(25); // Attendre 50ms que FormShow soit complètement terminé
          TThread.Synchronize(NIL, PROCEDURE
            BEGIN
              LoadApplicationSettings;
            END);
        END).Start;

      FInitialized := True;
    END;
  END;
END;

PROCEDURE TMainForm.LoadApplicationSettings;
VAR Mgr: TSettingsManager;
BEGIN
  Mgr := TSettingsManager.GetInstance;
  // 1. Charger depuis INI
  Mgr.LoadSettings(Self);
  // 2. Charger état contrôles (V1)
  Mgr.LoadControlState(StatusBar, INI_SECTION_CONTROLS);
  Mgr.LoadControlState(FrmSettings.ChkShowHints, INI_SECTION_CONTROLS);
  Mgr.LoadControlState(FrmSettings.ChkAlwaysOnTop, INI_SECTION_CONTROLS);
  Mgr.LoadControlState(dnSplitter1, INI_SECTION_CONTROLS);

  // 3. Appliquer tout (Style + Police + Options)
  Mgr.ApplyAll(Self);
  // 4. Restaurer position fenêtre
  WITH Mgr.Settings.Window DO BEGIN
    IF Maximized THEN Self.WindowState := wsMaximized
    ELSE BEGIN
      Self.Left := Left;
      Self.Top := Top;
      Self.Width := Width;
      Self.Height := Height;
    END;
  END;
  TSimpleLogger.Instance.Log('TMainForm', 'Paramètres chargés et appliqués');
END;

PROCEDURE TMainForm.SaveApplicationSettings;
VAR Mgr: TSettingsManager; CurrSettings: TApplicationSettings;
BEGIN
  Mgr := TSettingsManager.GetInstance;
  // 1. Capturer position actuelle
  CurrSettings := Mgr.Settings;
  CurrSettings.Window.Maximized := (Self.WindowState = wsMaximized);
  IF NOT CurrSettings.Window.Maximized THEN BEGIN
    CurrSettings.Window.Left := Self.Left;
    CurrSettings.Window.Top := Self.Top;
    CurrSettings.Window.Width := Self.Width;
    CurrSettings.Window.Height := Self.Height;
  END;
  CurrSettings.Window.WindowState := Self.WindowState;
  Mgr.Settings := CurrSettings;
  // 2. Sauvegarder contrôles (V1)
  Mgr.SaveControlState(StatusBar, INI_SECTION_CONTROLS);
  Mgr.SaveControlState(FrmSettings.ChkShowHints, INI_SECTION_CONTROLS);
  Mgr.SaveControlState(FrmSettings.ChkAlwaysOnTop, INI_SECTION_CONTROLS);
  Mgr.SaveControlState(dnSplitter1, INI_SECTION_CONTROLS);

  // 3. Sauvegarder dans INI
  Mgr.SaveSettings(Self);
  TSimpleLogger.Instance.Log('TFrm_Main', 'Paramètres sauvegardés');
END;

PROCEDURE TMainForm.InitializeManagers;
BEGIN
  // Les managers sont des singletons, s'auto-initialisent
  TSettingsManager.GetInstance;
  TPresetManager.GetInstance;
  TSimpleLogger.Instance.Log('TMainForm', 'Managers initialisés');
END;

PROCEDURE TMainForm.WMApplySettings(VAR Msg: TMessage);
BEGIN
  TSimpleLogger.Instance.Log('TFrm_Main', 'Réception WM_APPLY_SETTINGS');
  TSettingsManager.GetInstance.ApplyAll(Self);
END;

{ ============================================================================== }
{ INITIALISATION SECTION }
{ ============================================================================== }
INITIALIZATION

// Police par défaut application
Application.DefaultFont.Name := DEFAULT_FONT_NAME;
Application.DefaultFont.Size := DEFAULT_FONT_SIZE_APP;
// Enregistrer Hook Style pour NCColor
Vcl.Themes.TStyleManager.Engine.RegisterStyleHook(TMainForm, TFormStyleHookBackground);
// Configuration par défaut NCColor
TFormStyleHookBackground.NCSettings.Color := DEFAULT_NC_COLOR;
TFormStyleHookBackground.BackGroundSettings.Color := DEFAULT_BG_COLOR;
TFormStyleHookBackground.MergeImages := False;

FINALIZATION

END.
