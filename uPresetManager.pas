UNIT uPresetManager;

{ ****************************************************************************** }
{ * GESTIONNAIRE DE PRESETS - VERSION MASTER                                  * }
{ * Fusion V1 (Surveillance Fichier) + V3 (JSON Moderne)                      * }
{ * - Sauvegarde/Chargement JSON (System.JSON)                                 * }
{ * - Conversion Couleurs Hexadécimales (#RRGGBB)                              * }
{ * - Thread-Safe avec TCriticalSection                                        * }
{ * - Support Timestamp pour surveillance externe (V1)                         * }
{ ****************************************************************************** }

INTERFACE

USES System.SysUtils, System.Classes, System.JSON, System.Generics.Collections, System.IOUtils, System.SyncObjs,
  Winapi.Windows, Vcl.Graphics, uConstants, uSimpleLogger;

TYPE
  { ** Structure Preset - Compatible V1/V2/V3 ** }
  TPreset = RECORD
    // Apparence Core
    StyleName: STRING; // V1/V2/V3
    FontName: STRING;
    FontSize: Integer;
    Bold, Italic, Underline: Boolean;
    EdgeColor: TColor; // V1/V2 (NCColor V3)
    EdgeColorEnabled: Boolean; // V1/V2 (NCEnabled V3)

    // Options personnalisées (V1)
    Option1: Boolean;
    Option2: Integer;

    PROCEDURE ResetToDefaults;
    FUNCTION ToDisplayString: STRING;
  END;

  { ** Manager Singleton Thread-Safe ** }
  TPresetManager = CLASS
  PRIVATE
    CLASS VAR FInstance: TPresetManager;

  CLASS VAR
    FLock: TCriticalSection;

    FPresets:       TDictionary<STRING, TPreset>;
    FPresetsFile:   STRING;
    FLastFileStamp: TDateTime;

    CONSTRUCTOR Create;

    // Conversion Couleurs (V1/V2/V3 Logic)
    FUNCTION ColorToHex(C: TColor): STRING;
    FUNCTION HexToColor(CONST H: STRING): TColor;

    // Conversion JSON (V3 Modern)
    FUNCTION PresetToJSON(CONST P: TPreset): TJSONObject;
    FUNCTION JSONToPreset(Obj: TJSONObject): TPreset;

  PUBLIC
    CLASS FUNCTION GetInstance: TPresetManager;
    DESTRUCTOR Destroy; OVERRIDE;

    // Fichier I/O
    PROCEDURE LoadFromFile;
    PROCEDURE SaveToFile;

    // Gestion Presets
    PROCEDURE AddPreset(CONST Name: STRING; CONST Preset: TPreset);
    PROCEDURE RemovePreset(CONST Name: STRING);
    FUNCTION GetPreset(CONST Name: STRING; OUT Preset: TPreset): Boolean;
    FUNCTION GetPresetNames: TArray<STRING>;

    // V1 Feature: Surveillance Fichier
    FUNCTION GetFileTimestamp: TDateTime;
    FUNCTION HasFileChanged: Boolean;
    PROCEDURE UpdateTimestamp;

    CLASS CONSTRUCTOR CreateClass;
    CLASS DESTRUCTOR DestroyClass;
  END;

IMPLEMENTATION

{ TPreset }

PROCEDURE TPreset.ResetToDefaults;
BEGIN
  StyleName := DEFAULT_STYLE_NAME;
  FontName := DEFAULT_FONT_NAME;
  FontSize := DEFAULT_FONT_SIZE;
  Bold := False;
  Italic := False;
  Underline := False;
  EdgeColor := DEFAULT_NC_COLOR;
  EdgeColorEnabled := False;
  Option1 := False;
  Option2 := 0;
END;

FUNCTION TPreset.ToDisplayString: STRING;
VAR Styles: STRING;
BEGIN
  Styles := 'Normal';
  IF Bold OR Italic OR Underline THEN BEGIN
    Styles := '';
    IF Bold THEN Styles := Styles + 'Gras ';
    IF Italic THEN Styles := Styles + 'Italique ';
    IF Underline THEN Styles := Styles + 'Souligné ';
    Styles := Trim(Styles);
  END;

  Result := Format('Style: %s | Police: %s (%d pt) %s | Bordure: %s', [StyleName, FontName, FontSize, Styles,
    BoolToStr(EdgeColorEnabled, True)]);
END;

{ TPresetManager }

CLASS CONSTRUCTOR TPresetManager.CreateClass;
BEGIN
  FLock := TCriticalSection.Create;
END;

CLASS DESTRUCTOR TPresetManager.DestroyClass;
BEGIN
  FLock.Free;
END;

CLASS FUNCTION TPresetManager.GetInstance: TPresetManager;
BEGIN
  FLock.Enter;
  TRY
    IF FInstance = NIL THEN FInstance := TPresetManager.Create;
    Result := FInstance;
  FINALLY FLock.Leave;
  END;
END;

CONSTRUCTOR TPresetManager.Create;
BEGIN
  INHERITED Create;
  FPresets := TDictionary<STRING, TPreset>.Create;
  FPresetsFile := GetPresetFileName;
  FLastFileStamp := 0;

  TSimpleLogger.Instance.Log('TPresetManager', 'Instance créée');
  LoadFromFile;
END;

DESTRUCTOR TPresetManager.Destroy;
BEGIN
  TSimpleLogger.Instance.Log('TPresetManager', 'Instance détruite');
  FPresets.Free;
  INHERITED Destroy;
END;

{ ============================================================================== }
{ CONVERSION COULEURS (V1/V2/V3 Compatible) }
{ ============================================================================== }

FUNCTION TPresetManager.ColorToHex(C: TColor): STRING;
VAR RGB: Integer;
BEGIN
  RGB := ColorToRGB(C);
  Result := Format('#%.2X%.2X%.2X', [GetRValue(RGB), GetGValue(RGB), GetBValue(RGB)]);
END;

FUNCTION TPresetManager.HexToColor(CONST H: STRING): TColor;
VAR R, G, B: Integer;
BEGIN
  Result := DEFAULT_NC_COLOR;
  IF (Length(H) <> 7) OR (H[1] <> '#') THEN Exit;

  TRY
    R := StrToInt('$' + Copy(H, 2, 2));
    G := StrToInt('$' + Copy(H, 4, 2));
    B := StrToInt('$' + Copy(H, 6, 2));
    Result := TColor(RGB(R, G, B));
  EXCEPT
    ON E: Exception DO TSimpleLogger.Instance.LogEx(llWarning, 'TPresetManager', 'Conversion hex invalide: ' + H);
  END;
END;

{ ============================================================================== }
{ CONVERSION JSON (V3 Modern Logic) }
{ ============================================================================== }

FUNCTION TPresetManager.PresetToJSON(CONST P: TPreset): TJSONObject;
BEGIN
  Result := TJSONObject.Create;
  Result.AddPair('StyleName', P.StyleName);
  Result.AddPair('FontName', P.FontName);
  Result.AddPair('FontSize', TJSONNumber.Create(P.FontSize));
  Result.AddPair('Bold', TJSONBool.Create(P.Bold));
  Result.AddPair('Italic', TJSONBool.Create(P.Italic));
  Result.AddPair('Underline', TJSONBool.Create(P.Underline));
  Result.AddPair('EdgeColor', ColorToHex(P.EdgeColor));
  Result.AddPair('EdgeColorEnabled', TJSONBool.Create(P.EdgeColorEnabled));
  Result.AddPair('Option1', TJSONBool.Create(P.Option1));
  Result.AddPair('Option2', TJSONNumber.Create(P.Option2));
END;

FUNCTION TPresetManager.JSONToPreset(Obj: TJSONObject): TPreset;
VAR HexColor: STRING;
BEGIN
  Result.ResetToDefaults;
  IF NOT Assigned(Obj) THEN Exit;

  Obj.TryGetValue('StyleName', Result.StyleName);
  Obj.TryGetValue('FontName', Result.FontName);
  Obj.TryGetValue('FontSize', Result.FontSize);
  Obj.TryGetValue('Bold', Result.Bold);
  Obj.TryGetValue('Italic', Result.Italic);
  Obj.TryGetValue('Underline', Result.Underline);

  IF Obj.TryGetValue('EdgeColor', HexColor) THEN Result.EdgeColor := HexToColor(HexColor);

  Obj.TryGetValue('EdgeColorEnabled', Result.EdgeColorEnabled);
  Obj.TryGetValue('Option1', Result.Option1);
  Obj.TryGetValue('Option2', Result.Option2);
END;

{ ============================================================================== }
{ FICHIER I/O (V3 JSON Structure) }
{ ============================================================================== }

PROCEDURE TPresetManager.LoadFromFile;
VAR LContent: STRING; LRoot, LItem: TJSONObject; LArray: TJSONArray; LName: STRING; I: Integer;
BEGIN
  IF NOT FileExists(FPresetsFile) THEN BEGIN
    TSimpleLogger.Instance.Log('TPresetManager', 'Aucun fichier preset trouvé');
    Exit;
  END;

  FLock.Enter;
  TRY
    FPresets.Clear;

    LContent := TFile.ReadAllText(FPresetsFile, TEncoding.UTF8);
    LRoot := TJSONObject.ParseJSONValue(LContent) AS TJSONObject;

    IF Assigned(LRoot) THEN
      TRY
        IF LRoot.TryGetValue('Presets', LArray) THEN BEGIN
          FOR I := 0 TO LArray.Count - 1 DO BEGIN
            LItem := LArray.Items[I] AS TJSONObject;
            IF LItem.TryGetValue('Name', LName) THEN FPresets.Add(LName, JSONToPreset(LItem));
          END;
        END;

        TSimpleLogger.Instance.Log('TPresetManager', Format('%d presets chargés', [FPresets.Count]));
      FINALLY LRoot.Free;
      END;

    UpdateTimestamp;
  FINALLY FLock.Leave;
  END;
END;

PROCEDURE TPresetManager.SaveToFile;
VAR LRoot: TJSONObject; LArray: TJSONArray; LPair: TPair<STRING, TPreset>; LItem: TJSONObject;
BEGIN
  FLock.Enter;
  TRY
    LRoot := TJSONObject.Create;
    LArray := TJSONArray.Create;

    TRY
      FOR LPair IN FPresets DO BEGIN
        LItem := PresetToJSON(LPair.Value);
        LItem.AddPair('Name', LPair.Key);
        LArray.AddElement(LItem);
      END;

      LRoot.AddPair('Presets', LArray);

      ForceDirectories(ExtractFilePath(FPresetsFile));
      TFile.WriteAllText(FPresetsFile, LRoot.Format(2), TEncoding.UTF8);

      TSimpleLogger.Instance.Log('TPresetManager', Format('%d presets sauvegardés', [FPresets.Count]));
    FINALLY LRoot.Free;
    END;

    UpdateTimestamp;
  FINALLY FLock.Leave;
  END;
END;

{ ============================================================================== }
{ GESTION PRESETS }
{ ============================================================================== }

PROCEDURE TPresetManager.AddPreset(CONST Name: STRING; CONST Preset: TPreset);
BEGIN
  IF Trim(NAME) = '' THEN Exit;

  FPresets.AddOrSetValue(NAME, Preset);
  SaveToFile;

  TSimpleLogger.Instance.Log('TPresetManager', Format('Preset ajouté: %s', [NAME]));
END;

PROCEDURE TPresetManager.RemovePreset(CONST Name: STRING);
BEGIN
  IF FPresets.ContainsKey(NAME) THEN BEGIN
    FPresets.Remove(NAME);
    SaveToFile;
    TSimpleLogger.Instance.Log('TPresetManager', Format('Preset supprimé: %s', [NAME]));
  END;
END;

FUNCTION TPresetManager.GetPreset(CONST Name: STRING; OUT Preset: TPreset): Boolean;
BEGIN
  Result := FPresets.TryGetValue(NAME, Preset);
END;

FUNCTION TPresetManager.GetPresetNames: TArray<STRING>;
BEGIN
  Result := FPresets.Keys.ToArray;
END;

{ ============================================================================== }
{ SURVEILLANCE FICHIER (V1 Feature) }
{ ============================================================================== }

FUNCTION TPresetManager.GetFileTimestamp: TDateTime;
VAR SearchRec: TSearchRec;
BEGIN
  Result := 0;
  IF FindFirst(FPresetsFile, faAnyFile, SearchRec) = 0 THEN BEGIN
    Result := FileDateToDateTime(SearchRec.Time);
    System.SysUtils.FindClose(SearchRec);
  END;
END;

FUNCTION TPresetManager.HasFileChanged: Boolean;
VAR CurrentStamp: TDateTime;
BEGIN
  CurrentStamp := GetFileTimestamp;
  Result := (CurrentStamp <> 0) AND (CurrentStamp <> FLastFileStamp);
END;

PROCEDURE TPresetManager.UpdateTimestamp;
BEGIN
  FLastFileStamp := GetFileTimestamp;
END;

END.
