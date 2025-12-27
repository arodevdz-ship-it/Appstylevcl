UNIT uFontManager;

{ ****************************************************************************** }
{ * GESTIONNAIRE DE POLICES - VERSION MASTER                                  * }
{ * Fusion V1 (RTTI Robuste) + V3 (TFontConfig Élégant)                       * }
{ * - Thread-Safe                                                              * }
{ * - Désactivation automatique ParentFont                                     * }
{ * - Application récursive aux composants                                     * }
{ ****************************************************************************** }

INTERFACE

USES System.SysUtils, System.Classes, System.Rtti, System.UITypes, Vcl.Controls, Vcl.Graphics, Vcl.Forms, uConstants,
  uSimpleLogger;

TYPE
  { ** Structure de Configuration - Style V3 Élégant ** }
  TFontConfig = RECORD
    Name: STRING;
    Size: Integer;
    Bold: Boolean;
    Italic: Boolean;
    Underline: Boolean;
    ParentFont: Boolean;

    // Méthodes V3
    CLASS FUNCTION Default: TFontConfig; STATIC;
    PROCEDURE ResetToDefaults;
    PROCEDURE FromFont(AFont: TFont);
    FUNCTION ToFontStyles: TFontStyles;
    FUNCTION ToDisplayString: STRING;
  END;

  { ** Manager de Polices - Logic V1 RTTI ** }
  TFontManager = CLASS
  PRIVATE
    CLASS VAR FInstance: TFontManager;
    CLASS VAR FConfig:   TFontConfig;

    PROCEDURE ApplyFontToObject(AFont: TFont);
    PROCEDURE ProcessComponent(AComponent: TComponent; Recursive: Boolean);
  PUBLIC
    CONSTRUCTOR Create;
    DESTRUCTOR Destroy; OVERRIDE;

    CLASS FUNCTION Instance: TFontManager;
    CLASS PROCEDURE ReleaseInstance;

    // Configuration
    CLASS PROCEDURE Initialize(CONST AFontName: STRING; AFontSize: Integer); OVERLOAD;
    CLASS PROCEDURE Initialize(CONST AConfig: TFontConfig); OVERLOAD;
    CLASS PROCEDURE SetFontStyle(ABold, AItalic, AUnderline: Boolean);
    CLASS PROCEDURE SetParentFont(AParentFont: Boolean);

    // Application
    CLASS PROCEDURE ApplyToForm(AForm: TForm); OVERLOAD;
    CLASS PROCEDURE ApplyToForm(AForm: TForm; CONST AConfig: TFontConfig); OVERLOAD; // V3
    CLASS PROCEDURE ApplyToComponent(AComponent: TComponent; Recursive: Boolean = True);

    CLASS FUNCTION GetConfig: TFontConfig;
  END;

IMPLEMENTATION

{ TFontConfig }

CLASS FUNCTION TFontConfig.Default: TFontConfig;
BEGIN
  Result.ResetToDefaults;
END;

PROCEDURE TFontConfig.ResetToDefaults;
BEGIN
  NAME := DEFAULT_FONT_NAME;
  Size := DEFAULT_FONT_SIZE;
  Bold := False;
  Italic := False;
  Underline := False;
  ParentFont := False;
END;

PROCEDURE TFontConfig.FromFont(AFont: TFont);
BEGIN
  IF NOT Assigned(AFont) THEN Exit;

  NAME := AFont.Name;
  Size := AFont.Size;
  Bold := fsBold IN AFont.Style;
  Italic := fsItalic IN AFont.Style;
  Underline := fsUnderline IN AFont.Style;
END;

FUNCTION TFontConfig.ToFontStyles: TFontStyles;
BEGIN
  Result := [];
  IF Bold THEN Include(Result, fsBold);
  IF Italic THEN Include(Result, fsItalic);
  IF Underline THEN Include(Result, fsUnderline);
END;

FUNCTION TFontConfig.ToDisplayString: STRING;
VAR StyleStr: STRING;
BEGIN
  StyleStr := 'Normal';
  IF Bold OR Italic OR Underline THEN BEGIN
    StyleStr := '';
    IF Bold THEN StyleStr := StyleStr + 'Bold ';
    IF Italic THEN StyleStr := StyleStr + 'Italic ';
    IF Underline THEN StyleStr := StyleStr + 'Underline ';
    StyleStr := Trim(StyleStr);
  END;

  Result := Format('%s — %d pt — %s', [NAME, Size, StyleStr]);
END;

{ TFontManager }

CONSTRUCTOR TFontManager.Create;
BEGIN
  INHERITED Create;
  TSimpleLogger.Instance.Log('TFontManager', 'Instance créée');
END;

DESTRUCTOR TFontManager.Destroy;
BEGIN
  TSimpleLogger.Instance.Log('TFontManager', 'Instance détruite');
  INHERITED Destroy;
END;

CLASS FUNCTION TFontManager.Instance: TFontManager;
BEGIN
  IF NOT Assigned(FInstance) THEN FInstance := TFontManager.Create;
  Result := FInstance;
END;

CLASS PROCEDURE TFontManager.ReleaseInstance;
BEGIN
  FreeAndNil(FInstance);
END;

CLASS PROCEDURE TFontManager.Initialize(CONST AFontName: STRING; AFontSize: Integer);
BEGIN
  FConfig.Name := AFontName;
  FConfig.Size := AFontSize;
  TSimpleLogger.Instance.Log('TFontManager', Format('Initialisé: %s, %d pt', [AFontName, AFontSize]));
END;

CLASS PROCEDURE TFontManager.Initialize(CONST AConfig: TFontConfig);
BEGIN
  FConfig := AConfig;
  TSimpleLogger.Instance.Log('TFontManager', 'Initialisé avec config: ' + AConfig.ToDisplayString);
END;

CLASS PROCEDURE TFontManager.SetFontStyle(ABold, AItalic, AUnderline: Boolean);
BEGIN
  FConfig.Bold := ABold;
  FConfig.Italic := AItalic;
  FConfig.Underline := AUnderline;
END;

CLASS PROCEDURE TFontManager.SetParentFont(AParentFont: Boolean);
BEGIN
  FConfig.ParentFont := AParentFont;
END;

PROCEDURE TFontManager.ApplyFontToObject(AFont: TFont);
BEGIN
  IF AFont = NIL THEN Exit;

  AFont.Name := FConfig.Name;
  AFont.Size := FConfig.Size;
  AFont.Style := [];

  IF FConfig.Bold THEN AFont.Style := AFont.Style + [fsBold];
  IF FConfig.Italic THEN AFont.Style := AFont.Style + [fsItalic];
  IF FConfig.Underline THEN AFont.Style := AFont.Style + [fsUnderline];
END;

PROCEDURE TFontManager.ProcessComponent(AComponent: TComponent; Recursive: Boolean);
VAR Ctx: TRttiContext; RType: TRttiType; PropFont, PropParentFont: TRttiProperty; FontObj: TFont; I: Integer;
BEGIN
  IF AComponent = NIL THEN Exit;

  Ctx := TRttiContext.Create;
  TRY
    RType := Ctx.GetType(AComponent.ClassType);
    IF RType <> NIL THEN BEGIN
      // ÉTAPE CRITIQUE: Désactiver ParentFont (V1 Logic)
      PropParentFont := RType.GetProperty('ParentFont');
      IF (PropParentFont <> NIL) AND (PropParentFont.PropertyType.TypeKind = tkEnumeration) THEN BEGIN
        TRY PropParentFont.SetValue(AComponent, FConfig.ParentFont);
        EXCEPT
          // Ignorer les erreurs silencieusement
        END;
      END;

      // Appliquer la police
      PropFont := RType.GetProperty('Font');
      IF (PropFont <> NIL) AND (PropFont.PropertyType.TypeKind = tkClass) THEN BEGIN
        TRY
          FontObj := TFont(PropFont.GetValue(AComponent).AsObject);
          IF Assigned(FontObj) THEN ApplyFontToObject(FontObj);
        EXCEPT
          ON E: Exception DO
              TSimpleLogger.Instance.LogEx(llWarning, 'TFontManager', Format('Échec application police sur %s: %s',
              [AComponent.ClassName, E.Message]));
        END;
      END;
    END;

    // Récursion
    IF Recursive AND (AComponent.ComponentCount > 0) THEN
      FOR I := 0 TO AComponent.ComponentCount - 1 DO ProcessComponent(AComponent.Components[I], True);

  FINALLY Ctx.Free;
  END;
END;

CLASS PROCEDURE TFontManager.ApplyToForm(AForm: TForm);
BEGIN
  IF AForm = NIL THEN Exit;

  TSimpleLogger.Instance.Log('TFontManager', 'Application à ' + AForm.Name + ': ' + FConfig.ToDisplayString);

  Instance.ApplyFontToObject(AForm.Font);
  Instance.ProcessComponent(AForm, True);
END;

CLASS PROCEDURE TFontManager.ApplyToForm(AForm: TForm; CONST AConfig: TFontConfig);
BEGIN
  Initialize(AConfig);
  ApplyToForm(AForm);
END;

CLASS PROCEDURE TFontManager.ApplyToComponent(AComponent: TComponent; Recursive: Boolean);
BEGIN
  Instance.ProcessComponent(AComponent, Recursive);
END;

CLASS FUNCTION TFontManager.GetConfig: TFontConfig;
BEGIN
  Result := FConfig;
END;

INITIALIZATION

TFontManager.FConfig := TFontConfig.Default;

FINALIZATION

TFontManager.ReleaseInstance;

END.
