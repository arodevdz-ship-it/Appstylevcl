PROGRAM UltimateApp;

{ ****************************************************************************** }
{ * PROGRAMME PRINCIPAL - VERSION MASTER                                       * }
{ * Fusion V2 (Initialisation Précoce) + V3 (Structure Propre)                * }
{ * ========================================================================== * }
{ * ORDRE D'EXÉCUTION CRITIQUE:                                                * }
{ *   1. EnsureDirectoriesExist                                                * }
{ *   2. TStyleMgr.GetInstance.InitializeBeforeApp  <-- V2 CRUCIAL             * }
{ *   3. Application.Initialize                                                * }
{ *   4. Création Formulaires                                                  * }
{ *   5. Application.Run                                                       * }
{ ****************************************************************************** }

USES
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  System.SysUtils,
  Winapi.Windows,
  uConstants IN 'Uses\uConstants.pas',
  uFontManager IN 'Uses\uFontManager.pas',
  uSimpleLogger IN 'Uses\uSimpleLogger.pas',
  uPresetManager IN 'Uses\uPresetManager.pas',
  uStyleManager IN 'Uses\uStyleManager.pas',
  uSettingsManager IN 'Uses\uSettingsManager.pas' {/ Formulaires} ,
  u_main IN 'u_main.pas' {MainForm} ,
  Frm_Settings IN 'Frm_Settings.pas' {FrmSettings};

{$R *.res}

BEGIN
  // Application.Initialize;
  // Application.MainFormOnTaskbar := True;
  // Application.CreateForm(TMainForm, MainForm);
  // Application.Run;
  TRY
    // ========================================================================
    // ÉTAPE 1: CRÉER DOSSIERS (V3)
    // ========================================================================
    uConstants.EnsureDirectoriesExist;
    uConstants.DebugPaths;
    // ========================================================================
    // ÉTAPE 2: *** INITIALISER STYLES AVANT Application.Initialize (V2) ***
    // ========================================================================
    TStyleMgr.GetInstance.InitializeBeforeApp;

    // ========================================================================
    // ÉTAPE 3: INITIALISATION STANDARD VCL
    // ========================================================================
    Application.Initialize;
    Application.MainFormOnTaskbar := True;
    Application.Title             := APP_NAME;

    // ========================================================================
    // ÉTAPE 4: CRÉER FORMULAIRES
    // ========================================================================
    Application.CreateForm( TMainForm, MainForm );
    Application.CreateForm( TFrmSettings, FrmSettings );
    // ========================================================================
    // ÉTAPE 5: LANCER APPLICATION
    // ========================================================================
    Application.Run;

  EXCEPT
    ON E: Exception DO
      BEGIN
        TSimpleLogger.Instance.LogError( 'ERREUR FATALE: ' + E.Message );
        MessageBox( 0, PChar( 'Erreur critique au démarrage:'#13#10 + E.Message ),
          PChar( APP_NAME ), MB_ICONERROR );
      END;
  END;

END.
