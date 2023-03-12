unit boleto.controller;

{$MODE DELPHI}{$H+}

interface

uses
  Horse,
  Classes,
  SysUtils,
  boleto.database,
  boleto.util.biblioteca,
  boleto.util.terceiro.j4dl;

type
  TBoletoController = class
  public
    class procedure Registry;
  end;

implementation

procedure DoStatus(Req: THorseRequest; Res: THorseResponse);
begin
  with TJson.Create do
  begin
    Put('sucesso' , True);
    Put('mensagem', Concat('Serviço em operação, em: ', DateTimeToStr(Now)));
    Res.Send(Stringify);
  end;
end;

procedure DoGerarBoleto(Req: THorseRequest; Res: THorseResponse);
begin
  with TDM.Create(nil) do
  try
    Res.Send(
      GerarBoleto(
        Req.Params['id_empresa'],
        Req.Params['id_receber'],
        Req.Params['parcela']
      )
    );
  finally
    Free;
  end;
end;

procedure DoEnviarEmail(Req: THorseRequest; Res: THorseResponse);
var
  LJson: TJson;
begin
  with TDM.Create(nil) do
  try
    LJson := TJson.Create;
    LJson.Parse(Req.Body);

    Res.Send(
      GetEnviarEmail(
        LJson.Get('id_empresa').AsString,
        LJson.Get('id_receber').AsString,
        LJson.Get('parcela').AsString,
        LJson.Get('destino').AsString
      )
    );
  finally
    Free;
  end;
end;

procedure DoGerarRemessa(Req: THorseRequest; Res: THorseResponse);
begin
  with TDM.Create(nil) do
  try
    Res.Send(GerarRemessa(Req.Params['id_empresa'], Req.Params['id_remessa']));
  finally
    Free;
  end;
end;

{ TBoletoController }
class procedure TBoletoController.Registry;
begin
  THorse
    .Get(Concat(GPrefixo, 'status'), DoStatus)
    .Get(Concat(GPrefixo, 'gerar/:id_empresa/:id_receber/:parcela'), DoGerarBoleto)
    .Get(Concat(GPrefixo, 'remessa/:id_empresa/:id_remessa'), DoGerarRemessa)
    .Put(Concat(GPrefixo, 'enviar-email'), DoEnviarEmail);
end;


end.

