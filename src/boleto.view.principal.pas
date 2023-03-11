unit boleto.view.principal;

{$MODE DELPHI}{$H+}

interface

uses
  Classes,
  SysUtils,
  Forms,
  Controls,
  Graphics,
  Dialogs,
  ComCtrls,
  ExtCtrls,
  StdCtrls,
  rxspin,
  rxctrls,
  Horse,
  //Horse.Jhonson,
  //Horse.HandleException,
  //Horse.OctetStream,
  Horse.Logger,
  Horse.Logger.Provider.LogFile,
  //DataSet.Serialize,
  //DataSet.Serialize.Config,
  boleto.util.biblioteca;

type

  { TPrincipalView }

  TPrincipalView = class(TForm)
    btnIniciar: TButton;
    pnlTitulo: TPanel;
    pnlCentral: TPanel;
    lblPorta: TRxLabel;
    edtPorta: TRxSpinEdit;
    stbPrincipal: TStatusBar;
    procedure btnIniciarClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  LLogFileConfig: THorseLoggerLogFileConfig;
  PrincipalView: TPrincipalView;

implementation

{$R *.lfm}

procedure TPrincipalView.FormCreate(Sender: TObject);
begin
  Self.Caption := 'Boleto';

  pnlTitulo.Caption := captionApp;

  edtPorta.Value := 8883;


  LLogFileConfig := THorseLoggerLogFileConfig.New
    .SetDir(ExtractFilePath(ParamStr(0)) + 'Log\');

  THorseLoggerManager.RegisterProvider(THorseLoggerProviderLogFile.New());

  THorse
    //.Use(Jhonson())
    //.Use(HandleException)
    //.Use(OctetStream)
    .Use(THorseLoggerManager.HorseCallback);

  //SSW.Boleto.Controllers.Boleto.Registry;

end;

procedure TPrincipalView.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if THorse.IsRunning then
    THorse.StopListen;
end;

procedure TPrincipalView.btnIniciarClick(Sender: TObject);
begin
  if edtPorta.Value <= 0 then
    raise Exception.Create('Informe uma Porta Válida!');

  if Trim(btnIniciar.Caption).Equals('Iniciar') then
  begin
    THorse.Port := edtPorta.AsInteger;
    THorse.Listen;
    btnIniciar.Caption := 'Parar';
    Self.Caption := Concat(CAPTIONAPP, ' [Serviço rodando na porta: ', THorse.Port.ToString, ']');
  end
  else
  begin
    THorse.StopListen;
    btnIniciar.Caption := 'Iniciar';
    Self.Caption := Concat(CAPTIONAPP, ' [Servidor Parado]');
  end;
end;

end.

