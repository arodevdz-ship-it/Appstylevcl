object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'MainForm'
  ClientHeight = 437
  ClientWidth = 616
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 15
  object Label1: TLabel
    Left = 152
    Top = 240
    Width = 34
    Height = 15
    Caption = 'Label1'
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 418
    Width = 616
    Height = 19
    Panels = <>
    ExplicitWidth = 608
  end
  object Edit1: TEdit
    Left = 152
    Top = 280
    Width = 121
    Height = 23
    TabOrder = 1
    Text = 'Edit1'
  end
  object Panel1: TPanel
    Left = 431
    Top = 0
    Width = 185
    Height = 418
    Align = alRight
    Caption = 'Panel1'
    TabOrder = 2
    ExplicitLeft = 423
    object BtnSettings: TButton
      Left = 1
      Top = 1
      Width = 183
      Height = 57
      Align = alTop
      Caption = 'Panneau de configuration'
      TabOrder = 0
      OnClick = BtnSettingsClick
      ExplicitLeft = 6
      ExplicitTop = 0
      ExplicitWidth = 177
    end
  end
  object dnSplitter1: TdnSplitter
    Left = 423
    Top = 0
    AlignControl = Panel1
    ExplicitLeft = 415
  end
  object Button1: TButton
    Left = 200
    Top = 336
    Width = 75
    Height = 25
    Caption = 'Button1'
    TabOrder = 4
    OnClick = Button1Click
  end
end
