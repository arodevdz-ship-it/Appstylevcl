UNIT uStyleManager;

{ ****************************************************************************** }
{ * GESTIONNAIRE DE STYLES VCL - VERSION MASTER                               * }
{ * Fusion V2 (Init Précoce + Thread-Safe) + V3 (Preview + DWM) + V1 (Diag)   * }
{ * - Initialisation AVANT Application.Initialize (V2 CRITIQUE)                * }
{ * - Thread-Safe avec TCriticalSection (V2)                                   * }
{ * - Preview Natif VCL (V3)                                                   * }
{ * - NCColor via DwmSetWindowAttribute Windows 11 (V3)                        * }
{ * - Diagnostic Avancé (V1/V2)                                                * }
{ ****************************************************************************** }

INTERFACE

USES System.SysUtils, System.Classes, System.IOUtils, System.Types, System.Generics.Collections, System.SyncObjs,
  System.IniFiles, Vcl.Themes, Vcl.Styles, Vcl.Graphics, Vcl.Forms, Vcl.StdCtrls, Vcl.Styles.FormStyleHooks,
  Vcl.GraphUtil, Winapi.Windows, Winapi.Messages, Winapi.DwmApi, uConstants, uSimpleLogger;

TYPE
  { ** Info Style Chargé (V2) ** }
  TStyleInfo = RECORD
    Name: STRING;
    FileName: STRING;
    IsValid: Boolean;
  END;

  { ** Manager Singleton ** }
  TStyleMgr = CLASS
  PRIVATE
    CLASS VAR FInstance: TStyleMgr;
    CLASS VAR FLock:     TCriticalSection;

  CLASS VAR
    FInitialized:  Boolean;
    FCurrentStyle: STRING;

    FLoadedStyles:    TDictionary<STRING, TStyleInfo>;
    FFailedStyles:    TStringList;
    FStylesDirectory: STRING;
    FConfigFilePath:  STRING;

    CONSTRUCTOR Create;

    // V2 Logic: Chargement Robuste
    FUNCTION LoadStyleFileRobuste(CONST FileName: STRING): Boolean;
    FUNCTION ReadStyleFromConfig: STRING;

  PUBLIC
    CLASS FUNCTION GetInstance: TStyleMgr;
    DESTRUCTOR Destroy; OVERRIDE;

    // *** V2 MÉTHODE CRITIQUE ***
    PROCEDURE InitializeBeforeApp;

    // Gestion Styles
    PROCEDURE LoadStyleFiles;
    FUNCTION ApplyStyle(CONST StyleName: STRING): Boolean;
    FUNCTION IsStyleLoaded(CONST StyleName: STRING): Boolean;
    PROCEDURE PopulateComboBox(AComboBox: TComboBox);
    // ? AJOUTER CETTE MÉTHODE
    PROCEDURE DebugStyleStatus(CONST StyleName: STRING);
    // V3: Preview Natif
    PROCEDURE RenderPreview(CONST StyleName: STRING; ACanvas: TCanvas; CONST ARect: TRect);

    // V3: NCColor Windows 11
    PROCEDURE SetNCColor(AForm: TForm; AColor: TColor; Enabled: Boolean);

    // V1/V2: Diagnostic
    PROCEDURE DiagnoseStyles;

    FUNCTION GetIsInitialized: Boolean;
    PROPERTY IsInitialized: Boolean READ GetIsInitialized;

    CLASS CONSTRUCTOR CreateClass;
    CLASS DESTRUCTOR DestroyClass;
  END;

IMPLEMENTATION

{ TStyleMgr }

FUNCTION TStyleMgr.GetIsInitialized: Boolean;
BEGIN
  Result := FInitialized;
END;

CLASS CONSTRUCTOR TStyleMgr.CreateClass;
BEGIN
  FLock := TCriticalSection.Create;
  FInitialized := False;
END;

CLASS DESTRUCTOR TStyleMgr.DestroyClass;
BEGIN
  FLock.Free;
END;

CLASS FUNCTION TStyleMgr.GetInstance: TStyleMgr;
BEGIN
  IF FInstance = NIL THEN BEGIN
    IF NOT Assigned(FLock) THEN FLock := TCriticalSection.Create;

    FLock.Enter;
    TRY
      IF FInstance = NIL THEN FInstance := TStyleMgr.Create;
    FINALLY FLock.Leave;
    END;
  END;
  Result := FInstance;
END;

CONSTRUCTOR TStyleMgr.Create;
BEGIN
  INHERITED Create;
  FLoadedStyles := TDictionary<STRING, TStyleInfo>.Create;
  FFailedStyles := TStringList.Create;
  FStylesDirectory := GetStylesDirectory;
  // FStylesDirectory :=IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName))+'VCLStyles';
  FConfigFilePath := GetConfigFilePath;

  TSimpleLogger.Instance.Log('TStyleMgr', 'Instance créée');
END;

DESTRUCTOR TStyleMgr.Destroy;
BEGIN
  TSimpleLogger.Instance.Log('TStyleMgr', 'Instance détruite');
  FLoadedStyles.Free;
  FFailedStyles.Free;
  INHERITED Destroy;
END;

{ ============================================================================== }
{ *** V2 MÉTHODE CRITIQUE: INITIALISATION AVANT Application.Initialize *** }
{ ============================================================================== }

PROCEDURE TStyleMgr.InitializeBeforeApp;
VAR StyleName: STRING; StartTime, EndTime: TDateTime;
BEGIN
  IF FInitialized THEN BEGIN
    TSimpleLogger.Instance.LogWarning('InitializeBeforeApp déjà appelé');
    Exit;
  END;

  StartTime := Now;
  TSimpleLogger.Instance.Log('TStyleMgr', '=== DÉBUT INITIALISATION STYLES ===');

  // ? AJOUTER : Log du répertoire
  TSimpleLogger.Instance.Log('TStyleMgr', 'Répertoire styles: ' + FStylesDirectory);
  TSimpleLogger.Instance.Log('TStyleMgr', 'Existe: ' + BoolToStr(DirectoryExists(FStylesDirectory), True));

  TRY
    // Étape 1: Charger tous les .vsf
    LoadStyleFiles;

    // ? AJOUTER : Log après chargement
    TSimpleLogger.Instance.Log('TStyleMgr', Format('%d styles chargés dans FLoadedStyles', [FLoadedStyles.Count]));

    // Afficher les styles chargés
    FOR VAR Key IN FLoadedStyles.Keys DO BEGIN
      TSimpleLogger.Instance.Log('TStyleMgr',
        Format('  • %s -> %s', [Key, ExtractFileName(FLoadedStyles[Key].FileName)]));
    END;

    // Étape 2: Lire le style sauvegardé
    StyleName := ReadStyleFromConfig;
    TSimpleLogger.Instance.Log('TStyleMgr', Format('Style depuis INI: "%s"', [StyleName]));

    // ? AJOUTER : Diagnostic avant application
    IF StyleName <> '' THEN BEGIN
      DebugStyleStatus(StyleName);
    END;

    // Étape 3: Appliquer le style
    IF StyleName <> '' THEN BEGIN
      TSimpleLogger.Instance.Log('TStyleMgr', Format('Application style "%s"...', [StyleName]));

      IF NOT ApplyStyle(StyleName) THEN BEGIN
        TSimpleLogger.Instance.LogWarning
          (Format('Impossible d''appliquer le style sauvegardé: %s - Utilisation de Windows', [StyleName]));
        // Remettre "Windows" dans le INI pour éviter l'erreur au prochain démarrage
        TRY
          VAR
          Ini := TIniFile.Create(FConfigFilePath);
          TRY Ini.WriteString(INI_SECTION_APPEARANCE, INI_KEY_STYLE, 'Windows');
          FINALLY Ini.Free;
          END;
        EXCEPT
          // Ignorer les erreurs d'écriture INI
        END;
      END;
    END
    ELSE TSimpleLogger.Instance.Log('TStyleMgr', 'Utilisation thème par défaut: Windows');

    FInitialized := True;
    EndTime := Now;

    TSimpleLogger.Instance.Log('TStyleMgr', Format('=== FIN INITIALISATION (%.3f ms) - %d chargés, %d échecs ===',
      [(EndTime - StartTime) * 24 * 60 * 60 * 1000, FLoadedStyles.Count, FFailedStyles.Count]));

  EXCEPT
    ON E: Exception DO BEGIN
      TSimpleLogger.Instance.LogError('ERREUR CRITIQUE InitializeBeforeApp: ' + E.Message);
      // ? CORRECTION: Marquer comme initialisé même en cas d'erreur
      FInitialized := True;
      // S'assurer que Windows est actif
      TRY TStyleManager.TrySetStyle('Windows', True);
      EXCEPT
        // Dernier recours
      END;
    END;
  END;
  // ? TEST CRITIQUE : Vérifier manuellement le chargement
  TSimpleLogger.Instance.Log('UltimateApp', '=== TEST MANUEL CHARGEMENT STYLE ===');
  // Essayer de charger un style spécifique
  VAR
  TestStyle := 'Luna'; // ou 'Carbon' ou autre
  VAR
  StylesDir := TStyleMgr.GetInstance.FStylesDirectory; // À rendre publique temporairement
  VAR
  TestFile := StylesDir + TestStyle + '.vsf';
  TSimpleLogger.Instance.Log('UltimateApp', 'Chemin test: ' + TestFile);
  TSimpleLogger.Instance.Log('UltimateApp', 'Fichier existe: ' + BoolToStr(FileExists(TestFile), True));
  IF FileExists(TestFile) THEN BEGIN
    TSimpleLogger.Instance.Log('UltimateApp', 'Essai chargement manuel...');
    TRY
      TStyleManager.LoadFromFile(TestFile);
      TSimpleLogger.Instance.Log('UltimateApp', '? Chargement manuel réussi');
      // Vérifier si disponible
      IF TStyleManager.IsValidStyle(TestStyle) THEN
          TSimpleLogger.Instance.Log('UltimateApp', '? Style disponible dans TStyleManager')
      ELSE TSimpleLogger.Instance.Log('UltimateApp', '? Style NON disponible dans TStyleManager');
    EXCEPT
      ON E: Exception DO TSimpleLogger.Instance.LogError('UltimateApp' + ' ' + 'Erreur chargement: ' + E.Message);
    END;
  END;
END;

{ ============================================================================== }
{ CHARGEMENT DES STYLES (V2 Robuste) }
{ ============================================================================== }
PROCEDURE TStyleMgr.LoadStyleFiles;
VAR Files: TStringDynArray; FileName, ShortName: STRING; LoadedCount, ErrorCount: Integer;
BEGIN
  LoadedCount := 0;
  ErrorCount := 0;
  TSimpleLogger.Instance.Log('TStyleMgr', 'Recherche .vsf dans: ' + FStylesDirectory);
  IF NOT TDirectory.Exists(FStylesDirectory) THEN BEGIN
    TSimpleLogger.Instance.LogWarning('Répertoire styles introuvable, création...');
    ForceDirectories(FStylesDirectory);
    Exit;
  END;
  // ==================== CORRECTION ====================
  // Récupérer seulement les noms de fichiers sans le chemin complet
  Files := TDirectory.GetFiles(FStylesDirectory, '*.vsf', TSearchOption.soTopDirectoryOnly);
  TSimpleLogger.Instance.Log('TStyleMgr', Format('Fichiers .vsf trouvés: %d', [Length(Files)]));
  FOR FileName IN Files DO BEGIN
    // Extraire juste le nom du fichier (sans chemin)
    ShortName := ExtractFileName(FileName);
    TSimpleLogger.Instance.LogDebug('TStyleMgr', Format('Traitement: %s', [ShortName]));
    IF LoadStyleFileRobuste(ShortName) THEN Inc(LoadedCount)
    ELSE Inc(ErrorCount);
  END;
  TSimpleLogger.Instance.Log('TStyleMgr', Format('Résultat: %d chargés, %d échecs', [LoadedCount, ErrorCount]));
END;
// PROCEDURE TStyleMgr.LoadStyleFiles;
// VAR Files: TStringDynArray; FileName: STRING; LoadedCount, ErrorCount: Integer;
// BEGIN
// LoadedCount := 0;
// ErrorCount := 0;
//
// TSimpleLogger.Instance.Log('TStyleMgr', 'Recherche .vsf dans: ' + FStylesDirectory);
//
// IF NOT TDirectory.Exists(FStylesDirectory) THEN BEGIN
// TSimpleLogger.Instance.LogWarning('Répertoire styles introuvable, création...');
// ForceDirectories(FStylesDirectory);
// Exit;
// END;
//
// Files := TDirectory.GetFiles(FStylesDirectory, '*.vsf');
//
// IF Length(Files) = 0 THEN BEGIN
// TSimpleLogger.Instance.LogWarning('Aucun fichier .vsf trouvé');
// Exit;
// END;
//
// TSimpleLogger.Instance.Log('TStyleMgr', Format('Fichiers .vsf trouvés: %d', [Length(Files)]));
//
// FOR FileName IN Files DO BEGIN
// IF LoadStyleFileRobuste(FileName) THEN Inc(LoadedCount)
// ELSE Inc(ErrorCount);
// END;
//
// TSimpleLogger.Instance.Log('TStyleMgr', Format('Résultat: %d chargés, %d échecs', [LoadedCount, ErrorCount]));
// END;

FUNCTION TStyleMgr.LoadStyleFileRobuste(CONST FileName: STRING): Boolean;
VAR StyleName: STRING; Info: TStyleInfo; FullPath: STRING;
BEGIN
  Result := False;
  StyleName := TPath.GetFileNameWithoutExtension(FileName);
  TRY
    // ==================== CORRECTION CRITIQUE ====================
    // 1. Construire le bon chemin
    FullPath := IncludeTrailingPathDelimiter(FStylesDirectory) + FileName;
    // 2. Si le chemin n'est pas complet, ajouter l'extension .vsf
    IF NOT TPath.HasExtension(FileName) THEN FullPath := FullPath + '.vsf';
    TSimpleLogger.Instance.LogDebug('TStyleMgr', Format('Chargement: %s -> %s', [FileName, FullPath]));
    // 3. Vérifier que le fichier existe
    IF NOT FileExists(FullPath) THEN BEGIN
      TSimpleLogger.Instance.LogEx(llWarning, 'TStyleMgr', Format('  × %s : Fichier introuvable -> %s',
        [StyleName, FullPath]));
      FFailedStyles.Add(StyleName + ' (fichier introuvable: ' + FullPath + ')');
      Exit;
    END;
    // 4. Vérifier le format
    IF NOT TStyleManager.IsValidStyle(FullPath) THEN BEGIN
      TSimpleLogger.Instance.LogEx(llWarning, 'TStyleMgr', Format('  × %s : Format invalide', [StyleName]));
      FFailedStyles.Add(StyleName + ' (format invalide)');
      Exit;
    END;
    // 5. Chargement
    TStyleManager.LoadFromFile(FullPath);
    // 6. Vérifier après chargement
    IF TStyleManager.IsValidStyle(StyleName) THEN BEGIN
      Info.Name := StyleName;
      Info.FileName := FullPath; // <-- Stocker le CHEMIN COMPLET
      Info.IsValid := True;
      FLoadedStyles.AddOrSetValue(StyleName, Info);
      TSimpleLogger.Instance.LogEx(llInfo, 'TStyleMgr',
        Format('  ? %s : OK (%s)', [StyleName, ExtractFileName(FullPath)]));
      Result := True;
    END ELSE BEGIN
      TSimpleLogger.Instance.LogEx(llWarning, 'TStyleMgr', Format('  × %s : Non disponible après chargement',
        [StyleName]));
      FFailedStyles.Add(StyleName + ' (non disponible après chargement)');
    END;
  EXCEPT
    ON E: EDuplicateStyleException DO BEGIN
      // Style déjà chargé
      IF TStyleManager.IsValidStyle(StyleName) THEN BEGIN
        Info.Name := StyleName;
        Info.FileName := FullPath;
        Info.IsValid := True;
        FLoadedStyles.AddOrSetValue(StyleName, Info);
        TSimpleLogger.Instance.LogEx(llInfo, 'TStyleMgr', Format('  ? %s : Déjà chargé', [StyleName]));
        Result := True;
      END;
    END;
    ON E: Exception DO BEGIN
      TSimpleLogger.Instance.LogEx(llWarning, 'TStyleMgr', Format('  × %s : %s', [StyleName, E.Message]));
      FFailedStyles.Add(StyleName + ' (' + E.Message + ')');
    END;
  END;
END;

// FUNCTION TStyleMgr.LoadStyleFileRobuste(CONST FileName: STRING): Boolean;
// VAR StyleName:
// STRING; Info: TStyleInfo;
// BEGIN
// Result := False;
// StyleName := TPath.GetFileNameWithoutExtension(FileName);
//
// TRY
// // ? CORRECTION CRITIQUE: Vérifier que le fichier existe
// IF NOT FileExists(FileName) THEN BEGIN
// TSimpleLogger.Instance.LogEx(llWarning, 'TStyleMgr', Format('  × %s : Fichier introuvable', [StyleName]));
// FFailedStyles.Add(StyleName + ' (fichier introuvable)');
// Exit;
// END;
//
// // ? CORRECTION: IsValidStyle doit recevoir le CHEMIN COMPLET pour les fichiers
// IF NOT TStyleManager.IsValidStyle(FileName) THEN BEGIN
// TSimpleLogger.Instance.LogEx(llWarning, 'TStyleMgr', Format('  × %s : Format invalide', [StyleName]));
// FFailedStyles.Add(StyleName + ' (format invalide)');
// Exit;
// END;
//
// // Chargement du fichier .vsf
// TStyleManager.LoadFromFile(FileName);
//
// // ? CORRECTION: Après chargement, vérifier avec le NOM (pas le chemin)
// IF TStyleManager.IsValidStyle(StyleName) THEN BEGIN
// Info.Name := StyleName;
// Info.FileName := FileName;
// Info.IsValid := True;
// FLoadedStyles.AddOrSetValue(StyleName, Info);
//
// TSimpleLogger.Instance.LogDebug('TStyleMgr', Format('  ? %s : OK', [StyleName]));
// Result := True;
// END ELSE BEGIN
// TSimpleLogger.Instance.LogEx(llWarning, 'TStyleMgr', Format('  × %s : Non disponible après chargement',
// [StyleName]));
// FFailedStyles.Add(StyleName + ' (non disponible après chargement)');
// END;
//
// EXCEPT
// ON E: EDuplicateStyleException DO BEGIN
// // Style déjà chargé (ex: "Windows" système)
// IF TStyleManager.IsValidStyle(StyleName) THEN BEGIN
// Info.Name := StyleName;
// Info.FileName := FileName;
// Info.IsValid := True;
// FLoadedStyles.AddOrSetValue(StyleName, Info);
//
// TSimpleLogger.Instance.LogDebug('TStyleMgr', Format('  ? %s : Déjà chargé', [StyleName]));
// Result := True;
// END ELSE BEGIN
// TSimpleLogger.Instance.LogEx(llWarning, 'TStyleMgr', Format('  × %s : Déjà chargé mais introuvable',
// [StyleName]));
// FFailedStyles.Add(StyleName + ' (déjà chargé, introuvable)');
// END;
// END;
// ON E: Exception DO BEGIN
// TSimpleLogger.Instance.LogEx(llWarning, 'TStyleMgr', Format('  × %s : %s', [StyleName, E.Message]));
// FFailedStyles.Add(StyleName + ' (' + E.Message + ')');
// END;
// END;
// END;

FUNCTION TStyleMgr.ReadStyleFromConfig: STRING;
VAR Ini: TIniFile;
BEGIN
  Result := '';

  IF NOT FileExists(FConfigFilePath) THEN BEGIN
    TSimpleLogger.Instance.LogDebug('TStyleMgr', 'Fichier config inexistant: ' + FConfigFilePath);
    Exit;
  END;

  TRY
    Ini := TIniFile.Create(FConfigFilePath);
    TRY
      Result := Ini.ReadString(INI_SECTION_APPEARANCE, INI_KEY_STYLE, '');
      IF Result <> '' THEN TSimpleLogger.Instance.Log('TStyleMgr', 'Style lu depuis INI: ' + Result)
      ELSE TSimpleLogger.Instance.LogDebug('TStyleMgr', 'Aucun style défini dans INI');
    FINALLY Ini.Free;
    END;
  EXCEPT
    ON E: Exception DO BEGIN
      TSimpleLogger.Instance.LogError('Erreur lecture INI: ' + E.Message);
      Result := '';
    END;
  END;
END;

{ ============================================================================== }
{ APPLICATION STYLES }
{ ============================================================================== }

FUNCTION TStyleMgr.ApplyStyle(CONST StyleName: STRING): Boolean;
VAR StyleInfo: TStyleInfo; LogMsg: STRING; StyleIndex: Integer; I: Integer;
BEGIN
  Result := False;
  // ==================== LOG CRITIQUE ====================
  TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', '>>> Application style: "' + StyleName + '"');
  // Afficher ce qu'on a dans FLoadedStyles
  TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('FLoadedStyles count: %d', [FLoadedStyles.Count]));
  IF FLoadedStyles.Count = 0 THEN BEGIN
    TSimpleLogger.Instance.LogWarning('TStyleMgr.ApplyStyle' + ' ' + 'FLoadedStyles est VIDE!');
    // Afficher les fichiers dans le répertoire
    IF DirectoryExists(FStylesDirectory) THEN BEGIN
      VAR
      Files := TDirectory.GetFiles(FStylesDirectory, '*.vsf');
      TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('Fichiers dans %s: %d',
        [FStylesDirectory, Length(Files)]));
      FOR I := 0 TO HIGH(Files) DO BEGIN
        TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('  [%d] %s', [I, ExtractFileName(Files[I])]));
      END;
    END;
  END ELSE BEGIN
    TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', 'Styles dans FLoadedStyles:');
    FOR VAR Key IN FLoadedStyles.Keys DO BEGIN
      TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle',
        Format('  • %s -> %s', [Key, ExtractFileName(FLoadedStyles[Key].FileName)]));
    END;
  END;
  // ==================== FIN LOG ====================

  // ==================== ÉTAPE 1: LOG D'ENTRÉE ====================
  TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('>>> DÉBUT Application style: "%s"', [StyleName]));
  // ==================== ÉTAPE 2: STYLE WINDOWS ====================
  IF SameText(StyleName, 'Windows') THEN BEGIN
    TRY
      TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', 'Style Windows demandé');
      // Vérifier si déjà actif
      IF Assigned(TStyleManager.ActiveStyle) AND SameText(TStyleManager.ActiveStyle.Name, 'Windows') THEN BEGIN
        TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', 'Windows déjà actif');
        Result := True;
        Exit;
      END;
      // Appliquer Windows
      IF TStyleManager.TrySetStyle('Windows', False) THEN BEGIN // False = pas de rafraîchissement immédiat
        FCurrentStyle := 'Windows';
        TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', '? Windows appliqué avec succès');
        Result := True;
      END ELSE BEGIN
        TSimpleLogger.Instance.LogError('TStyleMgr.ApplyStyle' + ' ' + '? Échec application Windows');
      END;
    EXCEPT
      ON E: Exception DO BEGIN
        TSimpleLogger.Instance.LogError('TStyleMgr.ApplyStyle' + ' ' + Format('Exception Windows: %s', [E.Message]));
      END;
    END;
    Exit;
  END;

  // ==================== ÉTAPE 3: VÉRIFIER SI DÉJÀ ACTIF ====================
  IF Assigned(TStyleManager.ActiveStyle) THEN BEGIN
    IF SameText(StyleName, TStyleManager.ActiveStyle.Name) THEN BEGIN
      TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('"%s" déjà actif - skipping', [StyleName]));
      Result := True;
      Exit;
    END;
  END;
  // ==================== ÉTAPE 4: VÉRIFIER DANS FLoadedStyles ====================
  IF NOT FLoadedStyles.TryGetValue(StyleName, StyleInfo) THEN BEGIN
    // Style pas dans notre liste
    TSimpleLogger.Instance.LogWarning('TStyleMgr.ApplyStyle' + ' ' + Format('"%s" non trouvé dans FLoadedStyles',
      [StyleName]));
    // Afficher ce qu'on a dans FLoadedStyles
    TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('Styles disponibles (%d):', [FLoadedStyles.Count]));
    FOR VAR Key IN FLoadedStyles.Keys DO BEGIN
      TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', '  • ' + Key);
    END;
    // Fallback à Windows
    TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', 'Fallback vers Windows');
    Result := ApplyStyle('Windows');
    Exit;
  END;
  // ==================== ÉTAPE 5: VÉRIFIER DANS TStyleManager ====================
  TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('Style trouvé dans FLoadedStyles: %s -> %s',
    [StyleName, StyleInfo.FileName]));
  // Vérifier si déjà chargé dans TStyleManager
  IF NOT TStyleManager.IsValidStyle(StyleName) THEN BEGIN
    TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('Style "%s" pas dans TStyleManager, chargement...',
      [StyleName]));
    TRY
      // ? CORRECTION CRITIQUE : Charger depuis le fichier
      TStyleManager.LoadFromFile(StyleInfo.FileName);
      TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('? Fichier chargé: %s',
        [ExtractFileName(StyleInfo.FileName)]));
      // Vérifier après chargement
      IF NOT TStyleManager.IsValidStyle(StyleName) THEN BEGIN
        TSimpleLogger.Instance.LogError('TStyleMgr.ApplyStyle' + ' ' + '? Style toujours pas valide après chargement!');
        // Afficher les styles disponibles dans TStyleManager
        TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', 'Styles dans TStyleManager:');
        FOR I := 0 TO HIGH(TStyleManager.StyleNames) DO BEGIN
          TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('  [%d] %s', [I, TStyleManager.StyleNames[I]]));
        END;
        Result := ApplyStyle('Windows');
        Exit;
      END;
    EXCEPT
      ON E: Exception DO BEGIN
        TSimpleLogger.Instance.LogError('TStyleMgr.ApplyStyle' + ' ' + Format('? Erreur chargement fichier: %s',
          [E.Message]));
        Result := ApplyStyle('Windows');
        Exit;
      END;
    END;
  END ELSE BEGIN
    TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('Style "%s" déjà dans TStyleManager', [StyleName]));
  END;
  // ==================== ÉTAPE 6: APPLIQUER LE STYLE ====================
  TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('Application style "%s"...', [StyleName]));
  TRY
    // ? CORRECTION IMPORTANTE : Désactiver le rafraîchissement automatique
    IF TStyleManager.TrySetStyle(StyleName, False) THEN BEGIN // False = pas de refresh
      FCurrentStyle := StyleName;
      TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('? "%s" appliqué avec succès', [StyleName]));
      Result := True;
      // ? FORCER LE REFRESH MANUEL (pour éviter le flickering)
      PostMessage(Application.MainForm.Handle, WM_UPDATEUISTATE, UIS_INITIALIZE, 0);
    END ELSE BEGIN
      TSimpleLogger.Instance.LogError('TStyleMgr.ApplyStyle' + ' ' + Format('? TrySetStyle échoué pour "%s"',
        [StyleName]));
      Result := ApplyStyle('Windows');
    END;
  EXCEPT
    ON E: Exception DO BEGIN
      TSimpleLogger.Instance.LogError('TStyleMgr.ApplyStyle' + ' ' + Format('? Exception application: %s',
        [E.Message]));
      Result := ApplyStyle('Windows');
    END;
  END;
  // ==================== ÉTAPE 7: LOG DE FIN ====================
  TSimpleLogger.Instance.Log('TStyleMgr.ApplyStyle', Format('<<< FIN Application style: "%s" (Result=%s)',
    [StyleName, BoolToStr(Result, True)]));
END;

FUNCTION TStyleMgr.IsStyleLoaded(CONST StyleName: STRING): Boolean;
BEGIN
  Result := SameText(StyleName, 'Windows') OR FLoadedStyles.ContainsKey(StyleName) OR
    TStyleManager.IsValidStyle(StyleName);
END;

PROCEDURE TStyleMgr.PopulateComboBox(AComboBox: TComboBox);
VAR StyleName: STRING; SL: TStringList;
BEGIN
  IF NOT Assigned(AComboBox) THEN Exit;

  SL := TStringList.Create;
  TRY
    SL.Sorted := True;
    SL.Duplicates := dupIgnore;

    // Ajouter "Windows" en premier
    SL.Add('Windows');

    // Ajouter tous les styles disponibles
    FOR StyleName IN TStyleManager.StyleNames DO
      IF NOT SameText(StyleName, 'Windows') THEN SL.Add(StyleName);

    AComboBox.Items.Assign(SL);

    TSimpleLogger.Instance.LogDebug('TStyleMgr', Format('ComboBox remplie avec %d styles', [AComboBox.Items.Count]));
  FINALLY SL.Free;
  END;
END;

{ ============================================================================== }
{ V3: PREVIEW NATIF VCL }
{ ============================================================================== }

PROCEDURE TStyleMgr.RenderPreview(CONST StyleName: STRING; ACanvas: TCanvas; CONST ARect: TRect);
VAR LStyle: TCustomStyleServices; Details: TThemedElementDetails; R: TRect;
BEGIN
  // Récupérer le style
  LStyle := TStyleManager.Style[StyleName];
  IF LStyle = NIL THEN LStyle := TStyleManager.Style['Windows'];

  // Dessiner fond bouton
  R := ARect;
  InflateRect(R, -10, -10);
  Details := LStyle.GetElementDetails(tbPushButtonNormal);
  LStyle.DrawElement(ACanvas.Handle, Details, R);

  // Dessiner texte
  ACanvas.Font.Color := LStyle.GetSystemColor(clWindowText);
  ACanvas.Brush.Style := bsClear;
  DrawText(ACanvas.Handle, PChar('Aperçu: ' + StyleName), -1, R, DT_CENTER OR DT_VCENTER OR DT_SINGLELINE);
END;

{ ============================================================================== }
{ V3: NCCOLOR WINDOWS 11 (DWM API) }
{ ============================================================================== }

PROCEDURE TStyleMgr.SetNCColor(AForm: TForm; AColor: TColor; Enabled: Boolean);
VAR LColor: TColor;
BEGIN
  IF NOT Assigned(AForm) THEN Exit;

  IF Enabled THEN LColor := ColorToRGB(AColor)
  ELSE LColor := clDefault;

  // V1/V2: TFormStyleHookBackground
  TFormStyleHookBackground.NCSettings.Enabled := Enabled;
  TFormStyleHookBackground.NCSettings.UseColor := Enabled;
  TFormStyleHookBackground.NCSettings.Color := AColor;

  IF AForm.HandleAllocated THEN BEGIN
    // V3: Windows 11 DWM API (Attribut 34 = DWMWA_BORDER_COLOR)
    DwmSetWindowAttribute(AForm.Handle, 34, @LColor, SizeOf(LColor));
    PostMessage(AForm.Handle, WM_NCPAINT, 1, 0);
  END;

  TSimpleLogger.Instance.LogDebug('TStyleMgr', Format('NCColor appliqué: %s (Enabled: %s)',
    [ColorToString(AColor), BoolToStr(Enabled, True)]));
END;

{ ============================================================================== }
{ V1/V2: DIAGNOSTIC AVANCÉ }
{ ============================================================================== }

PROCEDURE TStyleMgr.DiagnoseStyles;
VAR Report: TStringList; SearchRec: TSearchRec; FilePath, StyleName: STRING; I: Integer;
BEGIN
  Report := TStringList.Create;
  TRY
    Report.Add('========================================');
    Report.Add('DIAGNOSTIC DES STYLES VCL - VERSION MASTER');
    Report.Add('========================================');
    Report.Add('Date: ' + DateTimeToStr(Now));
    Report.Add('');

    Report.Add('--- CONFIGURATION ---');
    Report.Add('Répertoire: ' + FStylesDirectory);
    Report.Add('Initialisé: ' + BoolToStr(FInitialized, True));
    Report.Add('Style Actif: ' + TStyleManager.ActiveStyle.Name);
    Report.Add('');

    Report.Add('--- STYLES DISPONIBLES DANS DELPHI ---');
    Report.Add(Format('Total: %d', [Length(TStyleManager.StyleNames)]));
    FOR StyleName IN TStyleManager.StyleNames DO Report.Add('  • ' + StyleName);
    Report.Add('');

    Report.Add('--- STYLES CHARGÉS AVEC SUCCÈS ---');
    Report.Add(Format('Total: %d', [FLoadedStyles.Count]));
    FOR StyleName IN FLoadedStyles.Keys DO Report.Add('  ? ' + StyleName);
    Report.Add('');

    Report.Add('--- STYLES EN ÉCHEC ---');
    Report.Add(Format('Total: %d', [FFailedStyles.Count]));
    FOR I := 0 TO FFailedStyles.Count - 1 DO Report.Add('  × ' + FFailedStyles[I]);
    Report.Add('');

    Report.Add('--- FICHIERS .VSF SUR DISQUE ---');
    IF FindFirst(FStylesDirectory + '*.vsf', faAnyFile, SearchRec) = 0 THEN BEGIN
      REPEAT
        FilePath := FStylesDirectory + SearchRec.Name;
        StyleName := TPath.GetFileNameWithoutExtension(SearchRec.Name);

        Report.Add(Format('  Fichier: %s (%.2f Ko)', [SearchRec.Name, SearchRec.Size / 1024]));

        IF TStyleManager.IsValidStyle(FilePath) THEN Report.Add('    ? Format: VALIDE')
        ELSE Report.Add('    ? Format: INVALIDE');
        Report.Add('');
      UNTIL FindNext(SearchRec) <> 0;

      System.SysUtils.FindClose(SearchRec);
    END
    ELSE Report.Add('  Aucun fichier .vsf trouvé');

    Report.Add('========================================');

    // Sauvegarder
    Report.SaveToFile(TPath.Combine(GetAppPath, 'StylesDiagnostic.txt'));
    TSimpleLogger.Instance.Log('TStyleMgr', 'Rapport diagnostic généré');

  FINALLY Report.Free;
  END;
END;

PROCEDURE TStyleMgr.DebugStyleStatus(CONST StyleName: STRING);
VAR Info: TStyleInfo; I: Integer;
BEGIN
  TSimpleLogger.Instance.Log('TStyleMgr.Debug', '=== DIAGNOSTIC STYLE: "' + StyleName + '" ===');
  // 1. Dans FLoadedStyles?
  IF FLoadedStyles.TryGetValue(StyleName, Info) THEN BEGIN
    TSimpleLogger.Instance.Log('TStyleMgr.Debug', Format('? Dans FLoadedStyles: %s', [Info.FileName]));
  END ELSE BEGIN
    TSimpleLogger.Instance.Log('TStyleMgr.Debug', '? PAS dans FLoadedStyles');
  END;
  // 2. Dans TStyleManager?
  IF TStyleManager.IsValidStyle(StyleName) THEN BEGIN
    TSimpleLogger.Instance.Log('TStyleMgr.Debug', '? Dans TStyleManager');
    // Trouver l'index
    FOR I := 0 TO HIGH(TStyleManager.StyleNames) DO BEGIN
      IF SameText(TStyleManager.StyleNames[I], StyleName) THEN BEGIN
        TSimpleLogger.Instance.Log('TStyleMgr.Debug', Format('  Index: %d', [I]));
        Break;
      END;
    END;
  END ELSE BEGIN
    TSimpleLogger.Instance.Log('TStyleMgr.Debug', '? PAS dans TStyleManager');
  END;
  // 3. Style actif?
  IF Assigned(TStyleManager.ActiveStyle) THEN BEGIN
    TSimpleLogger.Instance.Log('TStyleMgr.Debug', Format('Style actuel: %s', [TStyleManager.ActiveStyle.Name]));
  END ELSE BEGIN
    TSimpleLogger.Instance.Log('TStyleMgr.Debug', 'Aucun style actif');
  END;
  TSimpleLogger.Instance.Log('TStyleMgr.Debug', '=== FIN DIAGNOSTIC ===');
END;

END.
