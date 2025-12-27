object FrmSettings: TFrmSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Param'#232'tres'
  ClientHeight = 521
  ClientWidth = 720
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 15
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 720
    Height = 471
    ActivePage = TabSystem
    Align = alClient
    TabOrder = 0
    ExplicitWidth = 716
    ExplicitHeight = 470
    object TabAppearance: TTabSheet
      Caption = 'Apparence'
      object GroupBox3: TGroupBox
        Left = 8
        Top = 8
        Width = 696
        Height = 180
        Caption = ' Style VCL '
        TabOrder = 0
        object LblStylesLoaded: TLabel
          Left = 16
          Top = 148
          Width = 86
          Height = 15
          Caption = 'Styles charg'#233's: 0'
        end
        object ImgPreview: TImage
          Left = 280
          Top = 24
          Width = 400
          Height = 110
          Center = True
        end
        object CbxStyles: TComboBox
          Left = 16
          Top = 24
          Width = 250
          Height = 23
          Style = csDropDownList
          TabOrder = 0
          OnChange = CbxStylesChange
        end
        object BtnReloadStyles: TButton
          Left = 280
          Top = 140
          Width = 150
          Height = 25
          Caption = 'Recharger Styles'
          TabOrder = 1
          OnClick = BtnReloadStylesClick
        end
        object BtnDiagnoseStyles: TButton
          Left = 440
          Top = 140
          Width = 150
          Height = 25
          Caption = 'Diagnostic Styles'
          TabOrder = 2
          OnClick = BtnDiagnoseStylesClick
        end
      end
      object GroupBox2: TGroupBox
        Left = 8
        Top = 194
        Width = 696
        Height = 120
        Caption = ' Police '
        TabOrder = 1
        object LblFontPreview: TLabel
          Left = 16
          Top = 24
          Width = 142
          Height = 15
          Caption = 'Segoe UI '#8212' 9 pt '#8212' Normal'
        end
        object BtnChangeFont: TButton
          Left = 16
          Top = 56
          Width = 150
          Height = 30
          Caption = 'Changer Police...'
          TabOrder = 0
          OnClick = BtnChangeFontClick
        end
        object BtnResetFont: TButton
          Left = 180
          Top = 56
          Width = 150
          Height = 30
          Caption = 'R'#233'initialiser Police'
          TabOrder = 1
          OnClick = BtnResetFontClick
        end
      end
      object GbxNCColor: TGroupBox
        Left = 8
        Top = 320
        Width = 696
        Height = 120
        Caption = ' Couleur Bordure Fen'#234'tre '
        TabOrder = 2
        object Shape2: TShape
          Left = 16
          Top = 56
          Width = 80
          Height = 40
          Brush.Color = clBtnFace
        end
        object ChkNCEnabled: TCheckBox
          Left = 16
          Top = 24
          Width = 200
          Height = 17
          Caption = 'Activer couleur personnalis'#233'e'
          TabOrder = 0
          OnClick = ChkNCEnabledClick
        end
        object BtnChooseColor: TButton
          Left = 112
          Top = 56
          Width = 150
          Height = 40
          Caption = 'Choisir Couleur...'
          TabOrder = 1
          OnClick = BtnChooseColorClick
        end
      end
    end
    object TabOptions: TTabSheet
      Caption = 'Options'
      ImageIndex = 1
      object ChkShowHints: TCheckBox
        Left = 24
        Top = 24
        Width = 250
        Height = 17
        Caption = 'Afficher les info-bulles'
        TabOrder = 0
        OnClick = ChkShowHintsClick
      end
      object ChkShowStatusBar: TCheckBox
        Left = 24
        Top = 56
        Width = 250
        Height = 17
        Caption = 'Afficher la barre d'#39#233'tat'
        TabOrder = 1
        OnClick = ChkShowStatusBarClick
      end
      object ChkAlwaysOnTop: TCheckBox
        Left = 24
        Top = 88
        Width = 250
        Height = 17
        Caption = 'Toujours au premier plan'
        TabOrder = 2
        OnClick = ChkAlwaysOnTopClick
      end
      object BtnResetPosition: TButton
        Left = 24
        Top = 140
        Width = 200
        Height = 30
        Caption = 'R'#233'initialiser Position'
        TabOrder = 3
        OnClick = BtnResetPositionClick
      end
      object BtnResetSize: TButton
        Left = 240
        Top = 140
        Width = 200
        Height = 30
        Caption = 'R'#233'initialiser Taille'
        TabOrder = 4
        OnClick = BtnResetSizeClick
      end
      object BtnResetAll: TButton
        Left = 24
        Top = 190
        Width = 416
        Height = 40
        Caption = 'R'#233'INITIALISER TOUS LES PARAM'#200'TRES'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 5
        OnClick = BtnResetAllClick
      end
    end
    object TabPresets: TTabSheet
      Caption = 'Presets'
      ImageIndex = 2
      object GroupBox1: TGroupBox
        Left = 8
        Top = 8
        Width = 696
        Height = 220
        Caption = ' Gestion des Presets '
        TabOrder = 0
        object CbxPresets: TComboBox
          Left = 16
          Top = 24
          Width = 400
          Height = 23
          TabOrder = 0
        end
        object BtnApplyPreset: TButton
          Left = 430
          Top = 24
          Width = 120
          Height = 25
          Caption = 'Appliquer'
          TabOrder = 1
          OnClick = BtnApplyPresetClick
        end
        object BtnEnregistrerPresets: TButton
          Left = 560
          Top = 24
          Width = 120
          Height = 25
          Caption = 'Enregistrer...'
          TabOrder = 2
          OnClick = BtnSavePresetClick
        end
        object BtnDeletePreset: TButton
          Left = 430
          Top = 56
          Width = 120
          Height = 25
          Caption = 'Supprimer'
          TabOrder = 3
          OnClick = BtnDeletePresetClick
        end
        object BtnOpenPresetNotepad: TButton
          Left = 16
          Top = 100
          Width = 200
          Height = 30
          Caption = 'Ouvrir dans Notepad'
          TabOrder = 4
          OnClick = BtnOpenPresetNotepadClick
        end
        object BtnOpenPresetDefault: TButton
          Left = 230
          Top = 100
          Width = 200
          Height = 30
          Caption = 'Ouvrir avec Application'
          TabOrder = 5
          OnClick = BtnOpenPresetDefaultClick
        end
        object BtnReloadPresets: TButton
          Left = 16
          Top = 140
          Width = 200
          Height = 30
          Caption = 'Recharger Presets'
          TabOrder = 6
          OnClick = BtnReloadPresetsClick
        end
        object BtnPresetInfo: TButton
          Left = 230
          Top = 140
          Width = 200
          Height = 30
          Caption = 'Infos Fichier'
          TabOrder = 7
          OnClick = BtnPresetInfoClick
        end
      end
      object MemoSummary: TMemo
        Left = 8
        Top = 234
        Width = 696
        Height = 191
        Color = clInfoBk
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 1
      end
    end
    object TabSystem: TTabSheet
      Caption = 'Syst'#232'me'
      ImageIndex = 3
      object MemoPaths: TMemo
        Left = 8
        Top = 8
        Width = 696
        Height = 377
        Color = clInfoBk
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
      object BtnOpenAppData: TButton
        Left = 8
        Top = 399
        Width = 200
        Height = 30
        Caption = 'Ouvrir Dossier Config'
        TabOrder = 1
        OnClick = BtnOpenAppDataClick
      end
    end
  end
  object Pna_Setting: TPanel
    Left = 0
    Top = 471
    Width = 720
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitTop = 470
    ExplicitWidth = 716
    object BtnOK: TButton
      Left = 460
      Top = 10
      Width = 120
      Height = 30
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
      OnClick = BtnOKClick
    end
    object BtnCancel: TButton
      Left = 590
      Top = 10
      Width = 120
      Height = 30
      Cancel = True
      Caption = 'Annuler'
      ModalResult = 2
      TabOrder = 1
      OnClick = BtnCancelClick
    end
  end
  object FontDialog1: TFontDialog
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    Left = 640
    Top = 40
  end
  object ColorDialog1: TColorDialog
    Left = 640
    Top = 80
  end
  object TimerPresetWatch: TTimer
    Enabled = False
    Interval = 2000
    OnTimer = TimerPresetWatchTimer
    Left = 640
    Top = 120
  end
end
